## System fields use the same categorized layout and contextual help as game preferences.
extends Control
signal back_requested()
signal preferences_requested(game: String, protocol: String)
signal applied()
signal sound_preview_requested()
signal packages_requested()
signal restore_requested()
const Form = preload("res://core/ui/party_config_form.gd")
const Schema = preload("res://core/config/party_schema.gd")
@onready var page: Control = %Workspace
var form: Form
var settings: PartyInput
const VoiceBackend = preload("res://core/network/party_voice_backend.gd")
var voice: VoiceBackend
var status: Label
var declaration: Dictionary

func configure(local_settings: PartyInput, voice_backend: VoiceBackend) -> void:
	settings = local_settings
	voice = voice_backend
	set_process(false)
	declaration = settings.settings_schema()
	page.set_title("本地设置")
	page.back_requested.connect(func() -> void: back_requested.emit())
	form = preload("res://core/ui/party_config_form.tscn").instantiate()
	page.add_form(form)
	form.group_footers["playback"] = %PlaybackActions
	form.group_footers["recording"] = %MicCheck
	form.configure(_stored(), true, {"schema": declaration, "audience": "local"})
	%IdentityText.text = "唯一辨识 ID：" + str(settings.config.get_value("profile", "player_id", ""))
	%CopyIdentity.pressed.connect(func() -> void: DisplayServer.clipboard_set(str(settings.config.get_value("profile", "player_id", ""))))
	%MonitorToggle.pressed.connect(_toggle_monitor)
	voice.monitor_stopped.connect(_monitor_stopped)
	%MicCheck.visibility_changed.connect(_monitor_visibility_changed, CONNECT_DEFERRED)
	page.add_page("玩家身份", %Identity, "此 ID 用于识别本机玩家。昵称和形象由房间所使用的协议管理。")
	page.add_page("内容管理", %Packages, "安装和管理游戏内容，或恢复已有房间记录。")
	%Install.pressed.connect(func() -> void: packages_requested.emit())
	%Restore.pressed.connect(func() -> void: restore_requested.emit())
	%RefreshDevices.pressed.connect(_refresh_devices)
	%PreviewSound.pressed.connect(func() -> void: sound_preview_requested.emit())
	%Save.pressed.connect(apply)
	status = page.status
	status.text = "修改仅进入草稿，应用后保存到本机。"

func _toggle_monitor() -> void:
	if voice.monitoring:
		voice.stop_monitor()
		return
	var error: String = voice.start_monitor()
	if not error.is_empty():
		%MonitorStatus.text = error
		return
	%MonitorToggle.text = "停止监听"
	%MonitorStatus.text = "监听中 · 请对着麦克风说话"
	set_process(true)

func _process(_delta: float) -> void:
	%InputLevel.value = voice.monitor_peak_db()

func _monitor_stopped(message: String) -> void:
	set_process(false)
	%MonitorToggle.text = "开始监听"
	%MonitorStatus.text = message
	%InputLevel.value = %InputLevel.min_value

func _monitor_visibility_changed() -> void:
	if not %MicCheck.is_visible_in_tree():
		voice.stop_monitor()

func _exit_tree() -> void:
	if is_instance_valid(voice):
		voice.stop_monitor()

## Re-enumerate hardware without applying edits or dropping a disconnected draft selection.
func _refresh_devices() -> void:
	var restore_focus: bool = %RefreshDevices.has_focus()
	var draft: Dictionary = form.explicit_values()
	declaration = settings.settings_schema(draft)
	form.configure(draft, true, {"schema": declaration, "audience": "local"})
	if restore_focus:
		%RefreshDevices.grab_focus()
	status.text = "设备列表已刷新，当前草稿已保留。"

func _stored() -> Dictionary:
	var result: Dictionary = {}
	for key: String in declaration.fields:
		if declaration.fields[key].get("readonly", false):
			continue
		var section: String = key.get_slice(".", 0)
		var name_value: String = key.get_slice(".", 1)
		if settings.config.has_section_key(section, name_value):
			result[key] = settings.config.get_value(section, name_value)
	return result

func _defaults() -> void:
	form.configure({}, true, {"schema": declaration, "audience": "local"})
	status.text = "默认值已放入草稿，尚未应用。"

func apply() -> Error:
	var values: Dictionary = form.explicit_values()
	var checked: Dictionary = Schema.values(declaration, values, "local", false)
	if not checked.ok:
		status.text = checked.message
		return ERR_INVALID_DATA
	var previous: String = settings.config.encode_to_text()
	for key: String in checked.value:
		settings.config.set_value(key.get_slice(".", 0), key.get_slice(".", 1), checked.value[key])
	var error: Error = settings.save_settings()
	if error != OK:
		settings.config.parse(previous)
		status.text = "保存失败，草稿保留：" + error_string(error)
		return error
	voice.stop_monitor("设置已应用，请重新开始监听。")
	status.text = "已保存，正在应用显示和音频设置。"
	applied.emit()
	return OK

func refresh_display_controls() -> void:
	form._refresh_conditions()
