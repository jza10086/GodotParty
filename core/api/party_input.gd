## Client-local system preferences and one scope's keyboard/mouse input view.
class_name PartyInput
extends RefCounted
const JsonConfig = preload("res://core/config/party_json_config.gd")
const Schema = preload("res://core/config/party_schema.gd")
const DISPLAY_DEFAULTS: Dictionary = {"mode": "borderless", "resolution": [1920, 1080], "vsync": true, "fps": 0}
const DISPLAY_MODES: Dictionary = {"windowed": "窗口化", "borderless": "无边框全屏", "fullscreen": "独占全屏"}
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const MICROPHONE_MODES: Dictionary = {"open": "自由麦", "push_to_talk": "长按开麦（V）"}
const DEFAULT_MICROPHONE_MODE: String = "open"
const FPS_LIMITS: Array[int] = [0, 60, 120, 144]
const Paths = preload("res://core/config/party_paths.gd")
var settings_path: String = Paths.application_root().path_join("core/config/settings.json")
var config: JsonConfig = JsonConfig.new()
var spectator: bool = false
var input_blocked: bool = true:
	set(value):
		if value != input_blocked:
			_rearm = true
		input_blocked = value
var _preferences: RefCounted
var _actions: Dictionary = {}
var _registered: Array[StringName] = []
var _rearm: bool = true

## Writable application data lives beside the project in-editor, or beside the exported executable.
## Resolving this absolute path does not create files or depend on the launcher's working directory.
static func installation_directory() -> String:
	return Paths.application_root()

## Separate local profiles use a complete portable tree, without changing installed content.
func storage_directory() -> String:
	if settings_path.ends_with("/core/config/settings.json"):
		return settings_path.trim_suffix("/core/config/settings.json")
	return settings_path.get_base_dir()

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--party-profile="):
			var slot: String = argument.trim_prefix("--party-profile=")
			if not slot.is_empty() and slot.is_valid_identifier():
				settings_path = installation_directory().path_join("tmp/test/profiles").path_join(slot).path_join("core/config/settings.json")

func create_context() -> PartyInput:
	var context: PartyInput = PartyInput.new()
	context.config = config
	context.settings_path = settings_path
	return context

func load_settings() -> Error:
	var error: Error = config.load(settings_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		return error
	return validate_system_settings()

## Validate persisted system values once at the load/save boundary; absence has authored defaults.
func validate_system_settings() -> Error:
	var values: Dictionary = display_values()
	var invalid: String = ""
	if config.get_value("localization", "locale", "zh_Hans") not in ["zh_Hans", "en"]:
		push_error("Invalid system setting: localization/locale")
		return ERR_INVALID_DATA
	if not values.mode is String or not DISPLAY_MODES.has(values.mode):
		invalid = "display/mode"
	elif not config.get_value("display", "resolution", DISPLAY_DEFAULTS.resolution) is Array or values.resolution not in RESOLUTIONS:
		invalid = "display/resolution"
	elif not values.fps is int or values.fps not in FPS_LIMITS:
		invalid = "display/fps"
	elif not values.vsync is bool:
		invalid = "display/vsync"
	var volume: Variant = config.get_value("ui", "volume", 1.0)
	if not (volume is float or volume is int) or not is_finite(float(volume)) or volume < 0.0 or volume > 1.0:
		invalid = "ui/volume"
	if not config.get_value("system", "microphone_allowed", false) is bool:
		invalid = "system/microphone_allowed"
	if config.get_value("system", "microphone_mode", DEFAULT_MICROPHONE_MODE) not in MICROPHONE_MODES:
		invalid = "system/microphone_mode"
	for key: String in ["input_device", "output_device"]:
		var name_value: Variant = config.get_value("system", key, "Default")
		if not name_value is String or name_value.is_empty():
			invalid = "system/" + key
	var lab_schema: Dictionary = network_lab_schema()
	for key: String in lab_schema.fields:
		var field: Dictionary = lab_schema.fields[key]
		if not Schema.normalize(field, config.get_value("network_lab", key, field.default)).ok:
			invalid = "network_lab/" + key
	if not invalid.is_empty():
		push_error("系统配置无效：" + settings_path + " · " + invalid)
		return ERR_INVALID_DATA
	return OK

func save_settings() -> Error:
	var error: Error = validate_system_settings()
	if error != OK:
		return error
	error = DirAccess.make_dir_recursive_absolute(settings_path.get_base_dir())
	if error != OK:
		return error
	error = config.save(settings_path + ".pending")
	if error != OK:
		return error
	if FileAccess.file_exists(settings_path):
		error = DirAccess.copy_absolute(settings_path, settings_path + ".bak")
		if error != OK:
			return error
	return DirAccess.rename_absolute(settings_path + ".pending", settings_path)

## Bindings come from one resolved configuration. Never from the suspended parent.
func bind_preferences(preferences: RefCounted, protocol_schema: Dictionary, game_schema: Dictionary, scope_prefix: String) -> void:
	deactivate()
	_preferences = preferences
	for pair: Array in [["common", protocol_schema], ["own", game_schema]]:
		for key: String in pair[1].fields:
			var field: Dictionary = pair[1].fields[key]
			if field.get("control") == "binding" and not field.get("readonly", false):
				var action: String = field.action
				_actions[action] = {"domain": pair[0], "key": key, "native": StringName(scope_prefix + "/" + pair[0] + "/" + action)}
	_preferences.effective_changed.connect(_updated)
	_rebuild()

func _updated(_common: PackedStringArray, _own: PackedStringArray) -> void:
	_rebuild()

func _rebuild() -> void:
	for action: StringName in _registered:
		InputMap.erase_action(action)
	_registered.clear()
	_rearm = true
	for action: String in _actions:
		var native: StringName = _actions[action].native
		InputMap.add_action(native)
		_registered.append(native)
		for binding: Dictionary in get_bindings(StringName(action)):
			if binding.is_empty():
				continue
			var event: InputEvent
			if binding.kind == "mouse":
				var mouse: InputEventMouseButton = InputEventMouseButton.new()
				mouse.button_index = int(binding.code)
				event = mouse
			else:
				var key: InputEventKey = InputEventKey.new()
				if binding.physical:
					key.physical_keycode = int(binding.code)
				else:
					key.keycode = int(binding.code)
				event = key
			for modifier: String in ["ctrl", "alt", "shift", "meta"]:
				event.set(modifier + "_pressed", binding.get(modifier, false) or (binding.kind == "key" and binding.code == {"ctrl": KEY_CTRL, "alt": KEY_ALT, "shift": KEY_SHIFT, "meta": KEY_META}[modifier]))
			InputMap.action_add_event(native, event)

func deactivate() -> void:
	for action: StringName in _registered:
		InputMap.erase_action(action)
	_registered.clear()
	if _preferences != null and _preferences.effective_changed.is_connected(_updated):
		_preferences.effective_changed.disconnect(_updated)
	_actions.clear()
	_preferences = null
	_rearm = true

func get_bindings(action: StringName) -> Array:
	if _preferences == null or not _actions.has(String(action)):
		return []
	var field: Dictionary = _actions[String(action)]
	return _preferences.get_common(field.key, []) if field.domain == "common" else _preferences.get_own(field.key, [])

func _raw_pressed(binding: Dictionary) -> bool:
	if binding.is_empty():
		return false
	for pair: Array in [["ctrl", KEY_CTRL], ["alt", KEY_ALT], ["shift", KEY_SHIFT], ["meta", KEY_META]]:
		if binding.kind == "key" and binding.code == pair[1]:
			continue
		if binding.get(pair[0], false) and not Input.is_key_pressed(pair[1]):
			return false
	if binding.kind == "mouse":
		return Input.is_mouse_button_pressed(int(binding.code))
	return Input.is_physical_key_pressed(int(binding.code)) if binding.physical else Input.is_key_pressed(int(binding.code))

func _allowed(allow_spectator: bool = false) -> bool:
	if input_blocked or (spectator and not allow_spectator):
		return false
	if _rearm:
		for action: String in _actions:
			for binding: Dictionary in get_bindings(StringName(action)):
				if _raw_pressed(binding):
					return false
		_rearm = false
	return true

func is_pressed(action: StringName) -> bool:
	return _pressed(action, false)

## Protocol voice controls remain usable by spectators, but still respect focus and rearming.
func is_communication_pressed(action: StringName) -> bool:
	return _pressed(action, true)

func _pressed(action: StringName, communication: bool) -> bool:
	if not _allowed(communication):
		return false
	for binding: Dictionary in get_bindings(action):
		if _raw_pressed(binding):
			return true
	return false

func get_vector(left: StringName, right: StringName, up: StringName, down: StringName) -> Vector2:
	return Vector2(float(is_pressed(right)) - float(is_pressed(left)), float(is_pressed(down)) - float(is_pressed(up))).normalized()

func event_matches(event: InputEvent, action: StringName) -> bool:
	return _allowed() and _actions.has(String(action)) and event.is_action_pressed(_actions[String(action)].native, false, false)

func binding_text(action: StringName) -> String:
	var labels: PackedStringArray = []
	for binding: Dictionary in get_bindings(action):
		if not binding.is_empty():
			var parts: PackedStringArray = []
			for modifier: String in ["ctrl", "alt", "shift", "meta"]:
				if binding.get(modifier, false):
					parts.append(modifier.capitalize())
			parts.append("鼠标 %d" % int(binding.code) if binding.kind == "mouse" else OS.get_keycode_string(int(binding.code)))
			labels.append(" + ".join(parts))
	return " / ".join(labels) if not labels.is_empty() else "未绑定"

## Validated desired values; reading never writes defaults or replaces saved choices.
func display_values() -> Dictionary:
	var values: Dictionary = DISPLAY_DEFAULTS.duplicate()
	for key: String in values:
		values[key] = config.get_value("display", key, values[key])
	var resolution: Variant = values.resolution
	if resolution is Array and resolution.size() == 2 and resolution[0] is int and resolution[1] is int:
		values.resolution = Vector2i(resolution[0], resolution[1])
	return values

## Applies to the supplied viewport's native window, never an unrelated main window.
## Fullscreen uses the desktop resolution. Oversized window requests fit the work area;
## the saved desired resolution remains unchanged for another screen or launch.
func apply_display(viewport: Viewport) -> void:
	var desired: Dictionary = display_values()
	Engine.max_fps = desired.fps
	if DisplayServer.get_name() == "headless":
		return
	var window: Window = viewport.get_window()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if desired.vsync else DisplayServer.VSYNC_DISABLED, window.get_window_id())
	if OS.has_feature("android") or _display_is_embedded(window):
		return
	if desired.mode == "borderless":
		window.mode = Window.MODE_FULLSCREEN
	elif desired.mode == "fullscreen":
		window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		window.borderless = false
		var usable: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
		var frame: Vector2i = Vector2i(16, 48)
		var available: Vector2i = (usable.size - frame).max(Vector2i(320, 240))
		window.size = desired.resolution.min(available)
		window.position = usable.position + (usable.size - window.size) / 2

func _display_is_embedded(window: Window) -> bool:
	return window.is_embedded() or (window == window.get_tree().root and Engine.has_method("is_embedded_in_editor") and bool(Engine.call("is_embedded_in_editor")))

## Read back after the host has allowed window-system events to settle.
## Reports restrictions without pretending a persisted preference is already effective.
func display_feedback(viewport: Viewport) -> String:
	var desired: Dictionary = display_values()
	var rate: String = "不限帧率" if Engine.max_fps == 0 else "%d FPS 上限" % Engine.max_fps
	if DisplayServer.get_name() == "headless":
		return "已保存；无图形窗口，显示设置将在正常启动时应用。"
	var window: Window = viewport.get_window()
	var actual_vsync: bool = DisplayServer.window_get_vsync_mode(window.get_window_id()) != DisplayServer.VSYNC_DISABLED
	var sync: String = "垂直同步已开启" if actual_vsync else "垂直同步已关闭"
	if actual_vsync != desired.vsync:
		sync += "（当前驱动未接受所选模式）"
	if OS.has_feature("android"):
		return "已保存；%s，%s。Android 使用设备全屏尺寸。" % [rate, sync]
	if _display_is_embedded(window):
		return "已保存；%s，%s。编辑器内嵌运行无法改变窗口模式和尺寸，请关闭“嵌入游戏”后运行。" % [rate, sync]
	var actual_mode: String = "fullscreen" if window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN else ("borderless" if window.mode == Window.MODE_FULLSCREEN else "windowed")
	var message: String = "已保存；当前%s %d × %d，%s，%s。" % [DISPLAY_MODES[actual_mode], window.size.x, window.size.y, rate, sync]
	if actual_mode != desired.mode:
		message += "窗口系统未接受所选模式。"
	elif actual_mode == "windowed" and window.size != desired.resolution:
		message += "窗口尺寸受当前屏幕工作区限制；保留所选分辨率。"
	return message


func microphone_mode() -> String:
	return config.get_value("system", "microphone_mode", DEFAULT_MICROPHONE_MODE)

## Text entry and unfocused windows do not activate push-to-talk.
static func push_to_talk_pressed(viewport: Viewport) -> bool:
	var focus: Control = viewport.gui_get_focus_owner()
	return viewport.get_window().has_focus() and not (focus is LineEdit or focus is TextEdit) and Input.is_key_pressed(KEY_V)

## Snapshot of local driver choices and saved preferences. Reading it never starts capture.
func voice_devices() -> Dictionary:
	var result: Dictionary = {"microphone_allowed": config.get_value("system", "microphone_allowed", false)}
	for direction: String in ["input", "output"]:
		var input: bool = direction == "input"
		var devices: PackedStringArray = AudioServer.get_input_device_list() if input else AudioServer.get_output_device_list()
		var selected: String = config.get_value("system", direction + "_device", "Default")
		result[direction] = {"devices": devices, "selected": selected, "available": selected in devices,
			"current": AudioServer.input_device if input else AudioServer.output_device}
	return result

## The system business service declares controls and hierarchy; the form only renders this data.
func settings_schema(draft: Dictionary = {}) -> Dictionary:
	var resolutions: Array = []
	var resolution_labels: Array = []
	for size: Vector2i in RESOLUTIONS:
		resolutions.append([size.x, size.y])
		resolution_labels.append("%d × %d" % [size.x, size.y])
	var fields: Dictionary = {

		"display.mode": {"type": "string", "control": "select", "title": "显示模式", "description": "选择窗口化、无边框全屏或独占全屏。窗口化时可展开调整分辨率；全屏使用显示器的尺寸。", "default": DISPLAY_DEFAULTS.mode, "values": DISPLAY_MODES.keys(), "labels": DISPLAY_MODES.values()},
		"display.resolution": {"type": "array", "control": "select", "title": "窗口分辨率", "description": "调整窗口画面的输出尺寸。较高的分辨率提供更清晰的画面，也会增加渲染开销。全屏模式沿用显示器尺寸。", "default": DISPLAY_DEFAULTS.resolution, "items": {"type": "int"}, "min_items": 2, "max_items": 2, "values": resolutions, "labels": resolution_labels},
		"display.vsync": {"type": "bool", "control": "toggle", "title": "垂直同步", "default": DISPLAY_DEFAULTS.vsync},
		"display.fps": {"type": "int", "control": "select", "title": "帧率上限", "default": DISPLAY_DEFAULTS.fps, "values": FPS_LIMITS, "labels": ["不限", "60 FPS", "120 FPS", "144 FPS"]},
		"ui.volume": {"type": "float", "control": "number", "title": "框架提示音量", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01, "display_scale": 100.0, "suffix": "%"},
		"system.microphone_mode": {"type": "string", "control": "select", "title": "麦克风开关模式", "description": "启用房间麦克风后，自由麦持续发送语音；长按开麦仅在按住 V 时发送，松开即停止。", "default": DEFAULT_MICROPHONE_MODE, "values": MICROPHONE_MODES.keys(), "labels": MICROPHONE_MODES.values()},
		"system.microphone_allowed": {"type": "bool", "control": "toggle", "title": "允许使用麦克风", "default": false},
		"navigation.back": {"type": "array", "control": "binding", "title": "返回 / 关闭（固定）", "default": [{"kind": "key", "code": KEY_ESCAPE, "physical": false}], "items": {"type": "object", "format": "binding"}, "max_items": 2, "readonly": true}
	}
	var devices: Dictionary = voice_devices()
	for direction: String in ["input", "output"]:
		var key: String = "system." + direction + "_device"
		var device: Dictionary = devices[direction]
		var selected: String = draft.get(key, device.selected)
		var names: Array = ["Default"]
		for device_name: String in device.devices:
			if device_name != "Default":
				names.append(device_name)
		if selected not in names:
			names.append(selected)
		var labels: Array[String] = []
		for device_name: String in names:
			var label_text: String = "跟随系统默认设备" if device_name == "Default" else device_name
			labels.append(label_text if device_name in device.devices else label_text + "（不可用）")
		var input: bool = direction == "input"
		fields[key] = {"type": "string", "control": "select", "title": "语音输入（麦克风）" if input else "音频输出（扬声器 / 耳机）",
			"description": "授权后，房间开麦和本地监听检测均使用此输入设备。" if input else "应用后，语音、提示音和游戏声音都使用此输出设备。",
			"default": "Default", "values": names, "labels": labels}
	for field: Dictionary in fields.values():
		field.merge({"audience": "local", "apply": "immediate"})
	return {"schema_format": 3, "settings_version": 1, "fields": fields, "layout": [
		{"id": "display", "title": "显示与界面", "expanded": true, "children": [
			{"field": "display.mode", "children": [
				{"field": "display.resolution", "enabled_when": {"field": "display.mode", "equals": "windowed"}, "disabled_reason": "全屏使用当前屏幕分辨率；窗口尺寸已保留。"}]},
			{"field": "display.vsync"}, {"field": "display.fps"}]},
		{"id": "audio", "title": "声音与设备", "expanded": true, "children": [
			{"id": "playback", "title": "播放", "children": [
				{"field": "system.output_device"}, {"field": "ui.volume"}]},
			{"id": "recording", "title": "录制", "children": [
				{"field": "system.input_device"}, {"field": "system.microphone_allowed"}, {"field": "system.microphone_mode"}]}]},
		{"id": "keys", "title": "固定操作", "expanded": false, "children": [{"field": "navigation.back"}]}
	]}

## Local role profiles; defaults stay in this declaration and are never materialized on read.
static func network_lab_schema() -> Dictionary:
	var fields: Dictionary = {}
	var layout: Array[Dictionary] = []
	for role: String in ["host", "client"]:
		var prefix: String = role + "."
		fields[prefix + "enabled"] = {"type": "bool", "title": "启用网络模拟", "default": false,
			"description": "仅影响本机下次以此身份建立的游戏连接；不会修改其他玩家的本地设置。"}
		fields[prefix + "delay_msec"] = {"type": "int", "control": "number", "title": "额外发送延迟", "default": 0,
			"min": 0, "max": 2000, "step": 1, "suffix": "ms",
			"description": "每个发出 UDP 包增加的单向等待时间。双方各增加 100 ms 时，往返时间约增加 200 ms。"}
		fields[prefix + "loss_percent"] = {"type": "float", "control": "number", "title": "随机发送丢包率", "default": 0.0,
			"min": 0.0, "max": 100.0, "step": 0.1, "suffix": "%",
			"description": "每个发出 UDP 包独立丢弃的概率，包含握手、确认和重传。100% 会阻止连接；Tab 中的可靠包估计不等于此概率。"}
		layout.append({"id": role, "title": "房主侧" if role == "host" else "客机侧", "expanded": true,
			"children": [{"field": prefix + "enabled"}, {"field": prefix + "delay_msec"}, {"field": prefix + "loss_percent"}]})
	for field: Dictionary in fields.values():
		field.merge({"audience": "local", "apply": "next_activation"})
	return {"schema_format": 3, "settings_version": 1, "fields": fields, "layout": layout}

func network_lab_values(role: String) -> Dictionary:
	var schema: Dictionary = network_lab_schema()
	var values: Dictionary = {}
	for key: String in ["enabled", "delay_msec", "loss_percent"]:
		values[key] = config.get_value("network_lab", role + "." + key, schema.fields[role + "." + key].default)
	return values
