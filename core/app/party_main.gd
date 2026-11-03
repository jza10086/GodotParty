## Formal application shell. Development parameters enter this same UI and coordinator.
extends Control
const MenuAudio = preload("res://core/ui/ambient_reveal/audio/menu_audio.gd")
const JsonConfig = preload("res://core/config/party_json_config.gd")

const Catalog = preload("res://core/content/party_catalog.gd")
const Connection = preload("res://core/network/party_connection.gd")
const InputSettings = preload("res://core/api/party_input.gd")
const Presets = preload("res://core/runtime/party_presets.gd")
const Arguments = preload("res://core/dev/party_arguments.gd")
const Packages = preload("res://core/content/party_packages.gd")
const PreferencesPanel: PackedScene = preload("res://core/ui/party_preferences_panel.tscn")
const SystemSettings: PackedScene = preload("res://core/ui/party_system_settings.tscn")
const ProtocolPage: PackedScene = preload("res://core/ui/party_protocol_page.tscn")
const BindingButton = preload("res://core/ui/party_binding_button.gd")
@onready var _background: Control = %Background
@onready var _ui_audio: MenuAudio = %MenuAudio
var _system_preferences_revision: int = 0
var _settings_page: Control
var _settings_focus: Control
var _preferences_page: Control
var _preferences_return: Array[CanvasItem] = []
var _preferences_focus: Control
@onready var _frontend: Control = %PartyUI
var packages: RefCounted
var _content_error: String = ""
var _notice_text: String = ""
var catalog: RefCounted
@onready var connection: Node = %Connection
@onready var runner: Node = %Session
var settings: PartyInput
var presets: RefCounted
@onready var _screen: VBoxContainer = %GameScreen
var _page: String = ""
var _minimal_hud: bool = false
var _session_controls_open: bool = false
var _dialog: GPPartyDialog
var _profile_apply: Button
var _profile_name: LineEdit
var _profile_panel: Control
var _profile_error: Label
var _arguments: Dictionary
var _overview: GPPartyDialog
var _minigame_browser: Control

func _ready() -> void:
	# Child scenes are already present. Enable their input and processing after services initialize.
	process_mode = Node.PROCESS_MODE_DISABLED
	_frontend.hide()
	_arguments = Arguments.read()
	settings = InputSettings.new()
	var settings_error: Error = settings.load_settings()
	if settings_error != OK:
		push_error("无法加载系统配置：" + settings.settings_path + " · " + error_string(settings_error))
		return
	packages = Packages.new()
	var source_choices: JsonConfig = JsonConfig.new()
	var source_error: Error = source_choices.load(settings.settings_path.get_base_dir().path_join("party_sources.json"))
	if source_error != OK and source_error != ERR_FILE_NOT_FOUND:
		push_error("无法加载内容来源配置：" + error_string(source_error))
		return
	var choices: Dictionary = source_choices.get_value("sources", "choices", {})
	if _arguments.has("source"):
		var pair: PackedStringArray = str(_arguments["source"]).split(":", true, 1)
		if pair.size() == 2:
			choices[pair[0]] = pair[1]
	var mount_error: Error = packages.mount_directory(str(_arguments.get("pack-dir", InputSettings.installation_directory())), choices)
	if mount_error != OK:
		_content_error = packages.last_error
	catalog = Catalog.new()
	catalog.scan()
	var declaration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://core/i18n/localization.json"))
	if catalog.i18n.register_package("core", declaration, "res://core/i18n") != OK:
		push_error(catalog.i18n.last_error)
		return
	catalog.i18n.set_locale(settings.config.get_value("localization", "locale", "zh_Hans"))
	_apply_system_preferences()
	if connection.initialize(catalog, settings) != OK:
		return
	runner.configure(connection, catalog, settings)
	presets = Presets.new(runner.config_store)
	process_mode = Node.PROCESS_MODE_INHERIT
	_frontend.show()
	_frontend.initialize()
	%UINavigation.initialize()
	connection.changed.connect(_refresh)
	connection.profile_reply.connect(_profile_reply)
	runner.changed.connect(_refresh)
	runner.failed.connect(_notice)
	runner.finished.connect(func(value: Dictionary) -> void: _show_results(value))
	runner.presentation_requested.connect(_show_results)
	_refresh()
	if not catalog.errors.is_empty():
		_notice("\n".join(catalog.errors))
	_boot.call_deferred()

## Main-menu selection is explicit and local. Save successfully before refreshing presentation.
func select_language(language: String) -> Error:
	if language not in ["zh_Hans", "en"]:
		return ERR_INVALID_PARAMETER
	var previous: String = settings.config.encode_to_text()
	settings.config.set_value("localization", "locale", language)
	var error: Error = settings.save_settings()
	if error != OK:
		settings.config.clear()
		settings.config.parse(previous)
		return error
	return catalog.i18n.set_locale(language)

func _boot() -> void:
	if not _content_error.is_empty():
		_notice(_content_error)
		return
	var port: int = Connection.parse_port(str(_arguments.get("port", 7777)))
	if (_arguments.has("host") or _arguments.has("join")) and port == 0:
		_notice("端口请输入 1–65535 的整数")
		return
	if _arguments.has("host"):
		var error: Error = connection.open_host(port, "*", "GodotParty", str(_arguments.get("main", "")))
		_check(error)
		if error != OK:
			return
		var id: String = str(_arguments.get("main", connection.room.get("main", "")))
		var pools: Dictionary = {}
		if _arguments.has("mini"):
			for name_value: String in catalog.get_package(id).get("pools", []):
				pools[name_value] = [str(_arguments["mini"])]
		_check(connection.configure(id, catalog.defaults(id), {}, pools))
	elif _arguments.has("join"):
		_check(connection.join(str(_arguments["join"]), port))

func _refresh() -> void:
	if not is_inside_tree():
		return
	var next_page: String = "menu" if not connection.online or connection.room.is_empty() else ("lobby" if runner.phase == "idle" and connection.room.get("phase", "lobby") == "lobby" else "game")
	if next_page != _page:
		_close_settings()
		if is_instance_valid(_dialog):
			_dialog.hide()
		_page = next_page
		_show_page()
	_frontend.refresh()
	if _page == "game":
		%GameStatus.text = connection.status if not connection.status.is_empty() else _notice_text
		%RetrySave.disabled = not connection.host or runner._pending.is_empty()

func _show_page() -> void:
	var playing: bool = _page == "game"
	_background.visible = not playing
	_screen.visible = playing
	_frontend.visible = not playing and not is_instance_valid(_settings_page) and not is_instance_valid(_preferences_page)
	if playing:
		_frontend.close_modal()
		%LeaveSession.text = "返回大厅" if connection.host else "退出会话"

## UI adapters enter the same connection and catalog pipeline as development arguments.
func host_from_ui(main_id: String, title: String, port: int = 7777) -> Error:
	if not _content_error.is_empty():
		connection.status = _content_error
		return ERR_UNCONFIGURED
	if main_id not in catalog.ids("maingame"):
		return ERR_INVALID_PARAMETER
	var error: Error = connection.open_host(port, "*", title, main_id)
	if error != OK:
		return error
	error = connection.configure(main_id, catalog.defaults(main_id), {}, {})
	if error != OK:
		connection.leave("创建失败：" + connection.status)
		return error
	return _save_connection_settings({"host_port": port})

func join_from_ui(address: String, port: int) -> Error:
	if not _content_error.is_empty():
		connection.status = _content_error
		return ERR_UNCONFIGURED
	var error: Error = connection.join(address, port)
	if error != OK:
		return error
	return _save_connection_settings({"address": connection.connection_address, "port": port})

## Only explicit create/connect actions persist. A failed save closes the new socket
## and restores the in-memory preferences so the UI never advertises unsaved values.
func _save_connection_settings(values: Dictionary) -> Error:
	var previous: String = settings.config.encode_to_text()
	for key: String in values:
		settings.config.set_value("connection", key, values[key])
	var error: Error = settings.save_settings()
	if error != OK:
		settings.config.clear()
		settings.config.parse(previous)
		connection.leave("保存连接设置失败：" + error_string(error))
	return error

func save_local_name(value: String) -> Error:
	if connection.online or not connection.profiles.validate_name(value):
		return ERR_INVALID_PARAMETER
	var protocol_id: String = str(_frontend.selected_protocol) if is_instance_valid(_frontend) else ""
	if protocol_id.is_empty():
		return ERR_UNCONFIGURED
	var entry: Resource = catalog.load_entry(protocol_id)
	if not entry is Script:
		return ERR_INVALID_DATA
	var local_profile: Dictionary = connection.profiles.read(protocol_id, entry.new())
	if not local_profile.ok:
		_notice(local_profile.message)
		return ERR_INVALID_DATA
	return connection.profiles.save(value, protocol_id, local_profile.profile)

func local_display_name() -> String:
	var protocol_id: String = str(_frontend.selected_protocol) if is_instance_valid(_frontend) else ""
	if protocol_id.is_empty():
		return connection.profiles.identity().name
	var entry: Script = catalog.load_entry(protocol_id)
	var local_profile: Dictionary = connection.profiles.read(protocol_id, entry.new())
	if not local_profile.ok:
		_notice(local_profile.message)
		return "资料读取失败"
	return local_profile.name

func _open_standings() -> void:
	_show_results(runner.standings)

func _retry_save() -> void:
	_check(runner.retry_commit())

func _leave_session() -> void:
	if connection.host:
		connection.control("abort", {"reason": "返回大厅"})
	else:
		connection.leave()

func _modal(title: String, scene: PackedScene = preload("res://core/ui/party_dialog.tscn")) -> VBoxContainer:
	if is_instance_valid(_dialog):
		_dialog.hide()
		_dialog.queue_free()
	_dialog = scene.instantiate()
	_dialog.title = title
	%DialogHost.add_child(_dialog)
	_dialog.popup_centered(Vector2i(1100, 850))
	return _dialog.content

func _panel(package_id: String, value: Dictionary, editable: bool, profile: bool = false) -> Control:
	var definition: Dictionary = catalog.get_package(package_id)
	var scene: String = definition.get("player_config_panel" if profile else "config_panel", "")
	var panel: Control = load(catalog.path(package_id, scene)).instantiate() if not scene.is_empty() else preload("res://core/ui/party_config_form.tscn").instantiate()
	var context: Dictionary = {"schema": catalog.schema(package_id), "audience": "room", "fields": definition.get("player_fields", []) if profile else catalog.fields(package_id), "resources": catalog.packages.duplicate(true), "preview_asset": func(ref: Dictionary) -> Resource: return catalog.asset(ref, catalog.packages)}
	if profile and connection.host and connection.room.get("phase") == "lobby" and connection.recovery.is_empty():
		context["room_players"] = func() -> Array: return connection.players.duplicate(true)
		context["assign_room_profile"] = connection.assign_player_profile
	panel.configure(value.duplicate(true), editable, context)
	return panel

func _choose_offline_profile() -> void:
	var box: VBoxContainer = _modal("选择协议资料", preload("res://core/ui/dialogs/select_record.tscn"))
	var picker: OptionButton = box.get_node("Choices")
	for id: String in catalog.ids("protocols"):
		picker.add_item(catalog.get_package(id).get("name", id))
		picker.set_item_metadata(picker.item_count - 1, id)
	_dialog.get_ok_button().disabled = picker.item_count == 0
	_dialog.confirmed.connect(func() -> void: _profile_dialog(picker.get_item_metadata(picker.selected)))

func _profile_dialog(selected_protocol: String = "") -> void:
	var player: Dictionary = connection._player_peer(connection.local_peer())
	var protocol_id: String = selected_protocol
	var offline: bool = not connection.online
	var protocol: RefCounted
	if offline:
		var script: Script = catalog.load_entry(protocol_id)
		if script == null:
			return
		protocol = script.new()
		var local_profile: Dictionary = connection.profiles.read(protocol_id, protocol)
		if not local_profile.ok:
			_notice(local_profile.message)
			return
		player = connection.profiles.identity()
		player.name = local_profile.name
		player["profile"] = local_profile.profile
	else:
		if player.is_empty():
			return
		protocol_id = catalog.get_package(connection.room["main"])["protocol"]["id"]
	var box: VBoxContainer = _modal("个人资料 · " + protocol_id, preload("res://core/ui/dialogs/profile.tscn"))
	_profile_name = box.get_node("PlayerName")
	_profile_name.text = player["name"]
	_profile_panel = _panel(protocol_id, player["profile"], not connection.room.get("recovery", false), true)
	box.get_node("ProfileSlot").add_child(_profile_panel)
	_profile_error = box.get_node("Error")
	_profile_error.text = connection.profiles.last_error if offline else ""
	_profile_apply = _dialog.get_ok_button()
	_profile_apply.text = "应用"
	_dialog.dialog_hide_on_ok = false
	_dialog.confirmed.connect(func() -> void:
		if offline:
			if not connection.profiles.validate_name(_profile_name.text):
				_profile_error.text = "昵称需为 1–16 个字符，不能包含控制字符或首尾空格"
				return
			var value: Dictionary = _profile_panel.get_value()
			var report: Dictionary = protocol.validate_player_config(value)
			if not report.get("ok", false):
				_profile_error.text = report.get("message", "协议资料无效")
				return
			var save_error: Error = connection.profiles.save(_profile_name.text, protocol_id, value)
			_profile_error.text = "已保存" if save_error == OK else "本机保存失败：" + error_string(save_error)
			if save_error == OK:
				_dialog.hide()
				_frontend.refresh()
			return
		var error: Error = connection.submit_profile(_profile_name.text, _profile_panel.get_value())
		if error != OK:
			_profile_error.text = error_string(error)
		else:
			_profile_apply.disabled = not connection._pending_profile.is_empty())

func _profile_reply(_id: String, accepted: bool, message: String) -> void:
	if not is_instance_valid(_profile_error):
		return
	_profile_apply.disabled = false
	_profile_error.text = message if not message.is_empty() else ("已应用" if accepted else "未应用")

func _player_detail(peer: int) -> void:
	var player: Dictionary = connection._player_peer(peer)
	if player.is_empty():
		return
	var box: VBoxContainer = _modal(player["name"] + " · 只读资料")
	var protocol_id: String = catalog.get_package(connection.room["main"])["protocol"]["id"]
	box.add_child(_panel(protocol_id, player["profile"], false, true))
	_dialog.get_ok_button().text = "关闭"

## Pool browsing has its own draft; main-game rules use a separate lobby entry.
func _configuration_dialog() -> void:
	if connection.room.is_empty():
		return
	if is_instance_valid(_dialog):
		_dialog.hide()
		_dialog.queue_free()
	var main_id: String = connection.room.main
	var revision: int = int(connection.room.get("rules_revision", 0))
	var editable: bool = connection.host and connection.recovery.is_empty() and runner.phase == "idle"
	_dialog = preload("res://core/ui/party_dialog.tscn").instantiate()
	_dialog.title = "小游戏池"
	_dialog.ok_button_text = "应用小游戏池"
	_dialog.scroll_content = false
	_dialog.dialog_hide_on_ok = false
	%DialogHost.add_child(_dialog)
	_minigame_browser = preload("res://core/ui/minigame_browser/minigame_browser.tscn").instantiate()
	_minigame_browser.configure(self, connection.room, editable)
	_dialog.content.add_child(_minigame_browser)
	_dialog.get_ok_button().disabled = not editable
	_dialog.confirmed.connect(func() -> void:
		if connection.room.get("main", "") != main_id or int(connection.room.get("rules_revision", 0)) != revision:
			_minigame_browser.error_label.text = "房间配置已经变化，请关闭后重新打开。"
			return
		var draft: Dictionary = _minigame_browser.draft
		var common_overrides: Dictionary = draft.common_overrides.duplicate(true)
		for game: String in common_overrides.keys():
			if game != main_id and not draft.pools.values().any(func(pool: Array) -> bool: return game in pool):
				common_overrides.erase(game)
		var error: Error = connection.configure(main_id, connection.room.settings, draft.children, draft.pools, draft.common, common_overrides)
		_minigame_browser.error_label.text = connection.status if error != OK else ""
		if error == OK:
			_dialog.hide())
	_dialog.popup_centered(Vector2i(1700, 960))

func _main_configuration_dialog() -> void:
	if connection.room.is_empty():
		return
	var id: String = connection.room.main
	var revision: int = int(connection.room.get("rules_revision", 0))
	var editable: bool = connection.host and connection.recovery.is_empty() and runner.phase == "idle"
	var box: VBoxContainer = _modal("大游戏配置 · " + str(catalog.get_package(id).get("name", id)), preload("res://core/ui/dialogs/main_rules.tscn"))
	var panel: Control = _panel(id, connection.room.settings, editable)
	var protocol: String = catalog.get_package(id).protocol.id
	var preset_draft: Dictionary = connection.room.duplicate(true)
	var bar: Control = box.get_node("Presets")
	bar.configure(runner.config_store, id, protocol, func() -> Dictionary: return presets.snapshot(id, protocol, panel.get_value(), preset_draft.common_overrides.get(id, {}), preset_draft), editable)
	bar.loaded.connect(func(value: Dictionary) -> void:
		panel.configure(catalog.validate_settings(id, value.room_own).value, editable, {"schema": catalog.schema(id), "audience": "room", "fields": catalog.fields(id), "resources": catalog.packages.duplicate(true), "preview_asset": func(ref: Dictionary) -> Resource: return catalog.asset(ref, catalog.packages)})
		for key: String in ["common", "children", "pools", "common_overrides"]:
			preset_draft[key] = value.room[key].duplicate(true)
		preset_draft.common_overrides[id] = value.room_common.duplicate(true))
	box.get_node("FormSlot").add_child(panel)
	var error_label: Label = box.get_node("Error")
	_dialog.dialog_hide_on_ok = false
	_dialog.get_ok_button().text = "应用大游戏规则"
	_dialog.get_ok_button().disabled = not editable
	_dialog.confirmed.connect(func() -> void:
		if connection.room.get("main", "") != id or int(connection.room.get("rules_revision", 0)) != revision:
			error_label.text = "房间配置已经变化，请重新打开。"
			return
		var error: Error = connection.configure(id, panel.get_value(), preset_draft.children, preset_draft.pools, preset_draft.common, preset_draft.common_overrides)
		error_label.text = connection.status if error != OK else ""
		if error == OK:
			_dialog.hide())

func _select_main(id: String) -> void:
	_check(connection.configure(id, catalog.defaults(id), {}, {}))

func _restore_dialog() -> void:
	if not _content_error.is_empty():
		_notice(_content_error)
		return
	var box: VBoxContainer = _modal("恢复已提交的大游戏", preload("res://core/ui/dialogs/select_record.tscn"))
	var picker: OptionButton = box.get_node("Choices")
	_dialog.get_ok_button().disabled = true
	var saved: Dictionary = runner.store.list_records()
	if not saved.ok:
		_notice(saved.message)
		return
	for record: Dictionary in saved.records:
		if record.get("status") != "active":
			continue
		picker.add_item(record["room"]["main"] + " · 提交 " + str(record["revision"]))
		picker.set_item_metadata(picker.item_count - 1, record)
	_dialog.get_ok_button().disabled = picker.item_count == 0
	_dialog.dialog_hide_on_ok = false
	_dialog.confirmed.connect(func() -> void:
		var record: Dictionary = picker.get_item_metadata(picker.selected)
		var error: Error = connection.open_host(Connection.parse_port(str(_arguments.get("port", settings.config.get_value("connection", "host_port", 7777)))))
		if error == OK:
			error = connection.prepare_restore(record)
			if error != OK:
				connection.leave(connection.status)
		_check(error)
		if error == OK:
			_dialog.hide())

func _show_results(value: Dictionary) -> void:
	if is_instance_valid(_overview):
		_overview.hide()
		_overview.queue_free()
	_overview = preload("res://core/ui/dialogs/standings.tscn").instantiate()
	_overview.title = value.get("title", "当前排名")
	%DialogHost.add_child(_overview)
	var lines: PackedStringArray = []
	var rows: Array = value.get("rows", []).duplicate(true)
	for index: int in rows.size():
		rows[index]["_order"] = index
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left: int = a.get("rank", 0)
		var right: int = b.get("rank", 0)
		if left == right:
			return a["_order"] < b["_order"]
		return right == 0 or (left > 0 and left < right))
	for row: Dictionary in rows:
		var names: Array[String] = []
		for id: String in row.get("members", [row.get("player_id", "")]):
			for player: Dictionary in connection.players:
				if player["player_id"] == id:
					names.append(player["name"])
		var text: String = str(row.get("rank", 0)) + "  " + row.get("name", " / ".join(names)) + "  " + row.get("status", "")
		for column: Dictionary in value.get("columns", []):
			text += " · " + column.get("title", column["key"]) + ": " + _metric(row.get("metrics", {}).get(column["key"], ""), column.get("format", "text"))
		lines.append(text)
	_overview.content.get_node("Rows").text = "暂无排名" if lines.is_empty() else "\n".join(lines)
	_overview.popup_centered(Vector2i(950, 500))

func _metric(value: Variant, format: String) -> String:
	if not value is int and not value is float:
		return str(value)
	match format:
		"integer": return str(int(value))
		"decimal": return "%.2f" % float(value)
		"time": return "%02d:%05.2f" % [int(value) / 60000, float(value) / 1000.0 - floor(float(value) / 60000.0) * 60.0]
	return str(value)

func _protocol_dialog() -> void:
	if not connection.online or connection.room.is_empty():
		return
	if is_instance_valid(_settings_page):
		return
	if is_instance_valid(_dialog):
		_dialog.hide()
	_settings_focus = get_viewport().gui_get_focus_owner()
	_settings_page = ProtocolPage.instantiate()
	_settings_page.name = "ProtocolPage"
	%Pages.add_child(_settings_page)
	_settings_page.configure(runner.config_store, catalog, catalog.get_package(connection.room["main"])["protocol"]["id"], true)
	_settings_page.back_requested.connect(_close_settings)
	_settings_page.profile_requested.connect(_profile_dialog)
	_settings_page.get_node("%System").pressed.connect(func() -> void:
		_close_settings()
		_settings_dialog())
	_settings_page.get_node("%Game").pressed.connect(func() -> void:
		_preferences_dialog(connection.room.main, catalog.get_package(connection.room.main).protocol.id))
	_settings_page.protocol_selected.connect(func(id: String) -> void:
		_frontend.selected_protocol = id)
	_frontend.hide()
	_screen.hide()
	%UINavigation.focus_settings_on_open(_settings_page.page)

## Diagnostics are independent of the lobby transport and stop when dismissed.
func _connectivity_dialog(as_client: bool) -> void:
	if connection.online:
		return
	var box: VBoxContainer = _modal("连接测试" if as_client else "监听测试")
	var panel: Control = preload("res://core/ui/connectivity/client_panel.tscn").instantiate() if as_client else preload("res://core/ui/connectivity/listener_panel.tscn").instantiate()
	box.add_child(panel)
	var dialog: Variant = _dialog
	dialog.get_ok_button().text = "关闭"
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			panel.stop())
	connection.changed.connect(panel.stop_when_online.bind(connection))

func _settings_dialog() -> void:
	if is_instance_valid(_settings_page):
		return
	if is_instance_valid(_dialog):
		_dialog.hide()
	_settings_focus = get_viewport().gui_get_focus_owner()
	_settings_page = SystemSettings.instantiate()
	_settings_page.name = "SystemSettings"
	%Pages.add_child(_settings_page)
	_settings_page.configure(settings, runner.voice_backend)
	_settings_page.back_requested.connect(_close_settings)
	_settings_page.preferences_requested.connect(_preferences_dialog)
	_settings_page.applied.connect(_apply_system_preferences)
	_settings_page.sound_preview_requested.connect(_preview_ui_sound)
	_settings_page.packages_requested.connect(_package_dialog)
	_settings_page.restore_requested.connect(func() -> void:
		_close_settings()
		_restore_dialog())
	_settings_page.refresh_display_controls()
	_frontend.hide()
	_screen.hide()
	%UINavigation.focus_settings_on_open(_settings_page.page)

func _close_settings() -> void:
	_close_preferences()
	if not is_instance_valid(_settings_page):
		return
	%Pages.remove_child(_settings_page)
	_settings_page.queue_free()
	_settings_page = null
	_frontend.visible = _page != "game"
	_screen.visible = _page == "game"
	if is_instance_valid(_settings_focus) and _settings_focus.is_visible_in_tree():
		_settings_focus.grab_focus()

func _preferences_dialog(game: String, protocol: String) -> void:
	if is_instance_valid(_preferences_page):
		return
	_preferences_focus = get_viewport().gui_get_focus_owner()
	_preferences_return.clear()
	for surface: CanvasItem in [_settings_page, _frontend, _screen, _dialog]:
		if is_instance_valid(surface) and surface.visible:
			_preferences_return.append(surface)
			surface.hide()
	_preferences_page = PreferencesPanel.instantiate()
	%Pages.add_child(_preferences_page)
	_preferences_page.configure(runner.config_store, game, protocol)
	_preferences_page.present_fullscreen()
	%UINavigation.focus_settings_on_open(_preferences_page.page)
	_preferences_page.back_requested.connect(_close_preferences)

func _close_preferences() -> void:
	if not is_instance_valid(_preferences_page):
		return
	%Pages.remove_child(_preferences_page)
	_preferences_page.queue_free()
	_preferences_page = null
	for surface: CanvasItem in _preferences_return:
		if is_instance_valid(surface):
			if surface is GPPartyDialog:
				surface.popup_centered(Vector2i(surface._requested_size))
			else:
				surface.show()
	_preferences_return.clear()
	if is_instance_valid(_preferences_focus) and _preferences_focus.is_visible_in_tree():
		_preferences_focus.grab_focus()
	_preferences_focus = null

func _package_dialog() -> void:
	var box: VBoxContainer = _modal("内容包 · 安装或更改后重新启动", preload("res://core/ui/dialogs/packages.tscn"))
	var path: LineEdit = box.get_node("Path")
	var info: Label = box.get_node("Status")
	box.get_node("Install").pressed.connect(func() -> void:
		var source: String = path.text.strip_edges()
		if not source.ends_with(".pck") or not FileAccess.file_exists(source + ".json"):
			info.text = "缺少 PCK 或同名描述文件"
			return
		var error: Error = packages.install(source, InputSettings.installation_directory())
		info.text = "已安装，请重新启动" if error == OK else packages.last_error + " " + error_string(error))

	var choices_file: JsonConfig = JsonConfig.new()
	var choices_path: String = settings.settings_path.get_base_dir().path_join("party_sources.json")
	choices_file.load(choices_path)
	var choices: Dictionary = choices_file.get_value("sources", "choices", {})
	var picker: OptionButton = box.get_node("Sources/Package")
	var source: OptionButton = box.get_node("Sources/Source")
	source.add_item("源码")
	source.add_item("PCK")
	for id: String in catalog.ids():
		picker.add_item(id)
	var show_source: Callable = func(index: int) -> void:
		source.select(1 if choices.get(picker.get_item_text(index)) == "pck" else 0)
	picker.item_selected.connect(show_source)
	source.disabled = picker.item_count == 0
	if not source.disabled:
		show_source.call(0)
	source.item_selected.connect(func(index: int) -> void: choices[picker.get_item_text(picker.selected)] = "pck" if index == 1 else "source")
	_dialog.confirmed.connect(func() -> void:
		choices_file.set_value("sources", "choices", choices)
		_check(preload("res://core/config/party_config_store.gd").write_configs({choices_path: choices_file.encode_to_text()})))

func _confirm_action(text: String, action: Callable) -> void:
	var dialog: GPPartyDialog = preload("res://core/ui/party_dialog.tscn").instantiate()
	dialog.dialog_text = text
	%DialogHost.add_child(dialog)
	dialog.confirmed.connect(action)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _notice(message: String) -> void:
	_notice_text = message
	%GameStatus.text = message
	if is_instance_valid(_frontend):
		_frontend.show_notice(message)
	if is_instance_valid(_settings_page):
		_settings_page.status.text = message

func _check(error: Error) -> void:
	if error != OK:
		_notice(error_string(error) + " " + connection.status)

## Input always belongs to the foreground framework surface. Activities own their gameplay input.
func navigation_scope() -> Control:
	var modals: Array[Node] = get_tree().get_nodes_in_group(&"framework_modal")
	modals.reverse()
	for modal: Control in modals:
		if modal.is_visible_in_tree():
			return modal
	if is_instance_valid(_preferences_page):
		return _preferences_page
	if is_instance_valid(_settings_page):
		return _settings_page
	if _frontend.is_visible_in_tree():
		return _frontend.navigation_scope()
	return null

func navigation_back() -> void:
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is BindingButton and focus.capturing:
		focus.cancel()
		return
	var scope: Control = navigation_scope()
	if scope is GPPartyDialog:
		scope._cancel_pressed()
	elif is_instance_valid(_preferences_page):
		_close_preferences()
	elif is_instance_valid(_settings_page):
		_close_settings()
	elif _frontend.is_visible_in_tree():
		_frontend.navigation_back()
	elif _page == "game" and _minimal_hud:
		_session_controls_open = not _session_controls_open

func _process(_delta: float) -> void:
	# Content opts in through the public view group; scope removal restores the shell.
	var minimal: bool = false
	for scope: Dictionary in runner._scopes.values():
		if scope.phase != "suspended" and scope.root.is_in_group(&"party_minimal_hud"):
			minimal = true
	if minimal != _minimal_hud:
		_minimal_hud = minimal
		_session_controls_open = false
	_screen.visible = _page == "game" and not is_instance_valid(_settings_page) and not is_instance_valid(_preferences_page) and (not _minimal_hud or _session_controls_open)
	_background.visible = _page != "game" or (_minimal_hud and _session_controls_open)
	var focus: Control = get_viewport().gui_get_focus_owner()
	var framework_modal: bool = get_tree().get_nodes_in_group("framework_modal").any(func(node: Node) -> bool: return node is Control and node.is_visible_in_tree())
	var modal: bool = framework_modal or not _frontend.modal_kind.is_empty() or is_instance_valid(_settings_page) or is_instance_valid(_preferences_page) or focus is LineEdit or focus is TextEdit or (is_instance_valid(_dialog) and _dialog.visible) or (is_instance_valid(_overview) and _overview.visible)
	if runner._lobby_api != null:
		runner._lobby_api.input.input_blocked = modal
	for scope: Dictionary in runner._scopes.values():
		scope["api"].input.input_blocked = modal or (_minimal_hud and _session_controls_open) or scope["phase"] != "playing"

func _unhandled_key_input(event: InputEvent) -> void:
	if _page == "game" and _minimal_hud and event.is_action_pressed("ui_cancel"):
		navigation_back()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_preferences_page):
		if event.is_action_pressed("ui_cancel"):
			_close_preferences()
			get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_settings_page):
		if event.is_action_pressed("ui_cancel") and not (is_instance_valid(_dialog) and _dialog.visible):
			_close_settings()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB and _page == "game":
		_show_results(runner.standings)
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if not _page.is_empty():
		runner.changed.disconnect(_refresh)
		runner._close_lobby_settings()
		runner.cleanup("application_exit")




func _room_rules_dialog() -> void:
	if connection.room.is_empty():
		return
	var draft: Dictionary = connection.room if runner.phase == "idle" else runner.record.room
	var revision: int = int(draft.get("rules_revision", 0))
	var box: VBoxContainer = _modal("房间规则 · 当前轮次保持不变", preload("res://core/ui/dialogs/room_rules.tscn"))
	var panel: Control = box.get_node("Rules")
	panel.configure(draft, catalog, connection.host, runner.phase != "idle", runner.config_store)
	var status: Label = box.get_node("Status")
	status.text = "开局配置已锁定；标记为下一轮的规则在下次加载时生效。" if runner.phase != "idle" else "房间修改不会自动覆盖你的命名预设。"
	_dialog.dialog_hide_on_ok = false
	_dialog.get_ok_button().disabled = not connection.host
	_dialog.confirmed.connect(func() -> void:
		var error: Error = runner.edit_room_rules(revision, panel.edits())
		status.text = "已接受；运行中的修改须保存成功后生效" if error == OK else error_string(error)
		if error == OK:
			_dialog.get_ok_button().disabled = true)



func _apply_system_preferences() -> void:
	settings.apply_display(get_viewport())
	var index: int = AudioServer.get_bus_index("CoreUI")
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, "CoreUI")
		AudioServer.set_bus_send(index, "Master")
	var gain: float = clampf(float(settings.config.get_value("ui", "volume", 1.0)), 0.0, 1.0)
	AudioServer.set_bus_mute(index, gain <= 0.0)
	AudioServer.set_bus_volume_linear(index, gain)

	_system_preferences_revision += 1
	var devices: Dictionary = settings.voice_devices()
	var device_notice: String = ""
	if devices.output.available:
		AudioServer.output_device = devices.output.selected
	else:
		device_notice = "所选输出设备不可用，保留设置并继续使用当前设备。"
	if not devices.input.available:
		device_notice += "所选麦克风不可用，已保留选择，语音采集暂停。"
	if is_instance_valid(_settings_page) and _settings_page.scene_file_path == SystemSettings.resource_path:
		_report_system_preferences(_settings_page, _system_preferences_revision, device_notice)

## Window-system mode changes can settle after the save signal has returned.
func _report_system_preferences(target: Control, revision: int, device_notice: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if revision != _system_preferences_revision or not is_instance_valid(target) or target != _settings_page:
		return
	target.status.text = settings.display_feedback(get_viewport()) + device_notice

func _preview_ui_sound() -> void:
	_ui_audio.page()

## Read-only snapshots and explicit actions exposed to a main-game-owned room scene.
func room_query(key: String, argument: Dictionary) -> Variant:
	if key == "game_name":
		return catalog.get_package(argument.id)["name"]
	if key == "normalize_address":
		return Connection.normalize_address(argument.value)
	if key == "format_endpoint":
		return Connection.format_endpoint(argument.address, argument.port)
	if key != "state":
		push_error("Unknown room query: " + key)
		return null
	var own: Dictionary = connection._player_peer(connection.local_peer())
	return {"host": connection.host, "online": connection.online,
		"room": connection.room.duplicate(true), "players": connection.players.duplicate(true),
		"local_peer": connection.local_peer(), "local_ready": own.get("ready", false),
		"connection_port": connection.connection_port, "connection_address": connection.connection_address,
		"recovering": not connection.recovery.is_empty(),
		"allowed_counts": Connection.PlayerCounts.describe(connection.allowed_player_counts()),
		"start_reason": connection.start_reason() if connection.host else connection.player_count_reason(),
		"microphone_allowed": settings.config.get_value("system", "microphone_allowed", false)}

func room_action(operation: String, argument: Dictionary) -> void:
	match operation:
		"notice":
			_notice(argument.message)
		"leave":
			connection.leave()
		"ready":
			if connection.host:
				_check(runner.begin())
			else:
				var own: Dictionary = connection._player_peer(connection.local_peer())
				connection.set_ready(not own.ready)
		"player":
			if argument.peer == connection.local_peer():
				_profile_dialog()
			else:
				_player_detail(argument.peer)
		"settings":
			match argument.panel:
				"pool": _configuration_dialog()
				"main": _main_configuration_dialog()
				"protocol": _protocol_dialog()
				"rules": _room_rules_dialog()
				"system": _settings_dialog()
				_: push_error("Unknown room settings panel: " + str(argument.panel))
		_:
			push_error("Unknown room action: " + operation)
