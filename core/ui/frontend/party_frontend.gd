## Application navigation. Main-game room scenes own the lobby presentation and controls.
extends Control
const RoomAPI = preload("res://core/api/party_room_api.gd")
@export var app: Control
@export var modal_layer: Control
@onready var _create: Control = modal_layer.get_node("Create")
@onready var _direct: Control = modal_layer.get_node("Direct")
@onready var _profile: Control = modal_layer.get_node("Profile")
@onready var _confirm: Control = modal_layer.get_node("Confirm")
var _room_view: Control
var _room_activity: PartyAPI
var page: String = "Home"
var modal_kind: String = ""
var previous_focus: Control
var selected_game: String = ""
var selected_protocol: String = ""
var _joining: bool = false
var _connection_notice: String = ""
var _games: Array[String] = []
var _create_step: String = "protocol"
var _focus_modes: Dictionary = {}
const MENU_TEXT: Dictionary = {
	"Home/Menu/Start:text": "创建房间",
	"Home/Menu/Join:text": "加入房间",
	"Home/Menu/Settings:text": "设置",
	"Home/Menu/Content:text": "内容包",
	"Home/Menu/Exit:text": "退出",
	"Home/Menu/ListenTest:text": "监听测试",
	"Home/Menu/ConnectTest:text": "连接测试",
	"Home/Menu/NetworkLab:text": "网络实验",
	"Home/Profile:tooltip_text": "编辑玩家资料",
	"Home/Profile/Hint:text": "编辑玩家资料",
	"Home/Profile/Avatar/Placeholder:text": "头像",
	"Rooms/RoomsTitle:text": "加入房间",
	"Rooms/Back:text": "←  返回主菜单",
	"Rooms/Direct:text": "地址直连",
	"@Profile/Title:text": "玩家资料",
	"@Profile/NameLabel:text": "玩家名称",
	"@Profile/Cancel:text": "取消",
	"@Profile/Confirm:text": "保存",
	"@Confirm/Title:text": "要离开派对吗？",
	"@Confirm/Body:text": "关闭当前原型窗口。",
	"@Confirm/Cancel:text": "继续留下",
	"@Confirm/Quit:text": "确认退出",
	"@Direct/Cancel:text": "取消",
	"@Direct/AddressLabel:text": "连接地址",
	"@Create/RoomNameLabel:text": "房间名称",
	"@Create/RoomName:placeholder_text": "1–24 字",
	"@Create/PortLabel:text": "监听端口 (UDP)",
	"@Create/Port:placeholder_text": "1–65535 · 默认 7777",
	"@Create/BindAddressLabel:text": "监听网卡 / IP",
	"@Create/RefreshAddresses:text": "刷新",
	"@Create/DropdownNote:text": "选择本机监听 IP；隧道转发目标需与此匹配。请允许 UDP 端口通过防火墙。",
	"Rooms/RoomsSubtitle:text": "通过 IP 或域名加入房主 · 房间发现服务暂未开放",
	"Rooms/Name0:text": "房间发现暂未开放",
	"Rooms/Info0:text": "当前没有公共房间列表；请向房主获取地址和端口。",
	"Rooms/Join0:text": "暂不可用",
	"Rooms/Name1:text": "上次使用的连接地址",
	"Rooms/Join1:text": "填写 / 连接",
	"@Create/Note:text": "选择已安装的大游戏，确认后创建真实联机房间。",
	"@Direct/Title:text": "地址直连",
	"@Direct/Confirm:text": "连接房间",
	"@Direct/Note:text": "支持 IP / 域名；省略端口使用 7777，IPv6 带端口需加 []",
	"@Direct/Address:placeholder_text": "example.com:7777",
	"@Profile/Note:text": "昵称保存在本机；协议形象由所选协议提供。",
	"@Profile/Name:placeholder_text": "1–16 字",
	"@Profile/Avatar/Placeholder:text": "形象",
	"@Profile/AvatarNote:text": "头像与形象请在加入房间后，点击大厅中的本人资料设置。"
}
## Bind the authored pages once the application has loaded its catalog and session.
func initialize() -> void:
	visibility_changed.connect(func() -> void: modal_layer.visible = is_visible_in_tree() and not modal_kind.is_empty())
	# Source pages use fixed-height text boxes. Center single-line text within each row.
	for node: Node in find_children("*", "Label", true, false) + modal_layer.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF and not label.text.contains("\n"):
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var protocols: Array[String] = app.catalog.ids("protocols")
	if not protocols.is_empty():
		selected_protocol = protocols[0]
	_button("Home/Menu/Start", func() -> void: open_modal("Create"))
	_button("Home/Menu/Join", func() -> void: show_page("Rooms"))
	_button("Home/Menu/Settings", app._settings_dialog)
	_button("Home/Menu/Content", app._content_browser_dialog)
	_button("Home/Menu/ListenTest", app._connectivity_dialog.bind(false))
	_button("Home/Menu/ConnectTest", app._connectivity_dialog.bind(true))
	_button("Home/Menu/NetworkLab", app._network_lab_dialog)
	_button("Home/Menu/Exit", func() -> void: open_modal("Confirm"))
	_button("Home/Profile", app._local_profile_settings)
	_button("Rooms/Back", func() -> void: show_page("Home"))
	_button("Rooms/Direct", func() -> void: open_modal("Direct"))
	_button("Rooms/Join1", func() -> void: open_modal("Direct"))
	_create.get_node("Game").item_selected.connect(func(index: int) -> void: select_game(_create.get_node("Game").get_item_metadata(index)))
	_create.get_node("Cancel").pressed.connect(_create_back)
	_create.get_node("Confirm").pressed.connect(submit_create)
	_profile.get_node("Cancel").pressed.connect(close_modal)
	_profile.get_node("Confirm").pressed.connect(submit_profile)
	_direct.get_node("Cancel").pressed.connect(close_modal)
	_direct.get_node("Confirm").pressed.connect(submit_direct)
	_confirm.get_node("Cancel").pressed.connect(close_modal)
	_confirm.get_node("Quit").pressed.connect(func() -> void: get_tree().quit())
	_profile.get_node("Name").text_submitted.connect(func(_text: String) -> void: submit_profile())
	_direct.get_node("Address").text_submitted.connect(func(_text: String) -> void: submit_direct())
	$Rooms/Join0.disabled = true
	for key: String in ["Room2", "Name2", "Info2", "Join2"]:
		get_node("Rooms/" + key).hide()
	_create.get_node("Port").text_submitted.connect(func(_text: String) -> void: submit_create())
	_create.get_node("RefreshAddresses").pressed.connect(func() -> void:
		_refresh_host_addresses(str(_create.get_node("BindAddress").get_selected_metadata())))
	_create.get_node("BindAddress").item_selected.connect(func(_index: int) -> void:
		_create.get_node("BindAddress").tooltip_text = _create.get_node("BindAddress").get_item_text(_index))
	_direct.get_node("Address").max_length = 260
	for label: Label in [_create.get_node("Error"), _direct.get_node("Error"), $Rooms/Info1]:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.mouse_entered.connect(func() -> void: label.tooltip_text = label.text)
	_profile.get_node("Name").max_length = 16
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	get_parent().resized.connect(_fit)
	_fit()
	show_page("Home")
	app.catalog.i18n.changed.connect(_apply_language)
	$Home/Language.item_selected.connect(_select_language)
	_apply_language()

func _button(path: String, action: Callable) -> void:
	get_node(path).pressed.connect(action)

func _fit() -> void:
	var available: Vector2 = get_parent().size
	var ratio: float = minf(available.x / 1920.0, available.y / 1080.0)
	scale = Vector2.ONE * ratio
	size = Vector2(1920, 1080)
	position = (available - size * ratio) / 2.0

## 创建前选择协议，再筛选兼容大游戏；两步都不打开网络连接。
func _build_games() -> void:
	_games.clear()
	for id: String in app.catalog.ids("maingame"):
		var binding: Dictionary = app.catalog.get_package(id).get("protocol", {})
		if binding.get("id") == selected_protocol and app.catalog.protocol_matches(binding):
			_games.append(id)
	var options: Array[String] = app.catalog.ids("protocols") if _create_step == "protocol" else _games
	var picker: OptionButton = _create.get_node("Game")
	picker.clear()
	for id: String in options:
		picker.add_item(app.catalog.get_package(id).get("name", id))
		picker.set_item_metadata(picker.item_count - 1, id)
	_create.get_node("Title").text = _t("创建房间 · 选择协议") if _create_step == "protocol" else _t("创建房间 · 选择大游戏")
	_create.get_node("GameLabel").text = _t("协议") if _create_step == "protocol" else _t("大游戏")
	_create.get_node("Confirm").text = _t("下一步") if _create_step == "protocol" else _t("创建房间")
	_create.get_node("Cancel").text = _t("取消") if _create_step == "protocol" else _t("上一步")
	_create.get_node("Note").text = _t("协议决定房间规则、形象与公共体验。") if _create_step == "protocol" else _t("仅显示兼容大游戏；具体配置在创建后的大厅设置。")
	for key: String in ["RoomNameLabel", "RoomName", "PortLabel", "Port", "BindAddressLabel", "BindAddress", "RefreshAddresses"]:
		_create.get_node(key).visible = _create_step == "game"
	_create.get_node("Game").disabled = options.is_empty()
	_create.get_node("Confirm").disabled = options.is_empty()
	if options.is_empty():
		selected_game = ""
		_create.get_node("Game").text = _t("没有已安装的协议") if _create_step == "protocol" else _t("没有兼容的大游戏")
	else:
		var current: String = selected_protocol if _create_step == "protocol" else selected_game
		select_game(current if current in options else options[0])

## Enumerate local bind IPs. Keep a disappeared selection visible as invalid instead of
## silently broadening a previously restricted listener to every interface.
func _refresh_host_addresses(selected_address: String) -> void:
	var picker: OptionButton = _create.get_node("BindAddress")
	picker.clear()
	picker.add_item(_t("请选择监听网卡 / IP"))
	picker.set_item_metadata(0, "")
	picker.set_item_disabled(0, true)
	var addresses: Array[String] = [""]
	for interface: Dictionary in IP.get_local_interfaces():
		for address: String in interface.addresses:
			if not address.is_valid_ip_address() or address in addresses:
				continue
			# Link-local IPv6 needs an interface scope, which this address field does not carry.
			var lower: String = address.to_lower()
			if lower.begins_with("fe") and lower.substr(2, 1) in ["8", "9", "a", "b"]:
				continue
			var label: String = "%s · %s · %s" % ["IPv6" if address.contains(":") else "IPv4", interface.get("friendly", interface.name), address]
			picker.add_item(label)
			var index: int = picker.item_count - 1
			picker.set_item_metadata(index, address)
			picker.get_popup().set_item_tooltip(index, label)
			addresses.append(address)
	var chosen: int = 0 if selected_address in ["", "*", "0.0.0.0", "::"] else addresses.find(selected_address)
	if chosen == -1:
		picker.add_item(_t("不可用：{address}（请重新选择）", {"address": selected_address}))
		chosen = picker.item_count - 1
		picker.set_item_metadata(chosen, selected_address)
		picker.set_item_disabled(chosen, true)
	picker.select(chosen)
	picker.tooltip_text = picker.get_item_text(chosen)

func select_game(id: String) -> void:
	if _create_step == "protocol":
		if id not in app.catalog.ids("protocols"):
			return
		selected_protocol = id
		selected_game = ""
	else:
		if id not in _games:
			return
		selected_game = id
	var picker: OptionButton = _create.get_node("Game")
	for index: int in picker.item_count:
		if picker.get_item_metadata(index) == id:
			picker.select(index)
			break

func _create_back() -> void:
	if _create_step == "game":
		_create_step = "protocol"
		_create.get_node("Error").text = ""
		_build_games()
	else:
		close_modal()

func navigation_scope() -> Control:
	if not modal_kind.is_empty():
		return modal_layer.get_node(modal_kind)
	return get_node(page)

func show_page(next: String) -> void:
	close_modal()
	for key: String in ["Home", "Rooms", "Lobby"]:
		get_node(key).visible = key == next
	page = next
	if page == "Lobby":
		_room_view.room_focus()
	else:
		get_node("Home/Menu/Start" if page == "Home" else "Rooms/Direct").grab_focus()

func open_modal(kind: String) -> void:
	close_modal()
	previous_focus = get_viewport().gui_get_focus_owner()
	modal_kind = kind
	modal_layer.show()
	for key: String in ["Create", "Direct", "Profile", "Confirm"]:
		modal_layer.get_node(key).visible = kind == key
	_set_page_focus(false)
	match kind:
		"Create":
			_create_step = "protocol"
			_build_games()
			_create.get_node("RoomName").text = _t("我的派对")
			_create.get_node("Error").text = ""
			_create.get_node("Port").text = str(app.settings.config.get_value("connection", "host_port", 7777))
			_refresh_host_addresses(str(app.settings.config.get_value("connection", "host_bind_address", "")))
			_create.get_node("Game").grab_focus()
		"Direct":
			_direct.get_node("Address").text = app.connection.format_endpoint(str(app.settings.config.get_value("connection", "address", "127.0.0.1")), int(app.settings.config.get_value("connection", "port", 7777)))
			_direct.get_node("Error").text = ""
			_direct.get_node("Confirm").disabled = false
			_direct.get_node("Address").grab_focus()
		"Profile":
			_profile.get_node("Name").text = app.local_display_name()
			_profile.get_node("Error").text = ""
			_profile.get_node("Name").grab_focus()
		_: _confirm.get_node("Cancel").grab_focus()

func close_modal() -> void:
	if _joining and app.connection.room.is_empty():
		_joining = false
		app.connection.leave()
	modal_layer.hide()
	modal_kind = ""
	_set_page_focus(true)
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()

func _set_page_focus(enabled: bool) -> void:
	for path: String in ["Home", "Rooms", "Lobby"]:
		for child: Node in get_node(path).find_children("*", "Control", true, false):
			if not child is BaseButton:
				continue
			if not enabled:
				_focus_modes[child] = child.focus_mode
				child.focus_mode = Control.FOCUS_NONE
			elif _focus_modes.has(child):
				child.focus_mode = _focus_modes[child]
	if enabled:
		_focus_modes.clear()

func submit_create() -> void:
	if modal_kind != "Create" or app.connection.online:
		return
	if _create_step == "protocol":
		if selected_protocol not in app.catalog.ids("protocols"):
			return
		_create_step = "game"
		_build_games()
		return
	if selected_game not in _games or app.catalog.get_package(selected_game).get("protocol", {}).get("id") != selected_protocol:
		_create.get_node("Error").text = _t("请选择兼容的大游戏")
		return
	var title: String = _create.get_node("RoomName").text.strip_edges()
	if not app.connection.valid_room_name(title):
		_create.get_node("Error").text = _t("请输入 1–24 字的房间名称")
		return
	var port: int = app.connection.parse_port(_create.get_node("Port").text)
	if port == 0:
		_create.get_node("Error").text = _t("端口请输入 1–65535 的整数")
		return
	var picker: OptionButton = _create.get_node("BindAddress")
	if picker.is_item_disabled(picker.selected):
		_create.get_node("Error").text = _t("请选择监听网卡 / IP") if picker.selected == 0 else _t("所选监听 IP 已不可用，请刷新并重新选择")
		return
	var error: Error = app.host_from_ui(selected_game, title, port, str(picker.get_selected_metadata()))
	if error != OK:
		_create.get_node("Error").text = app.connection.status if not app.connection.status.is_empty() else error_string(error)

func submit_direct() -> void:
	if modal_kind != "Direct" or _joining:
		return
	var endpoint: Dictionary = app.connection.parse_endpoint(_direct.get_node("Address").text)
	if endpoint.is_empty():
		_direct.get_node("Error").text = _t("格式：IP:端口 / 域名:端口 / [IPv6]:端口；端口 1–65535")
		return
	var address: String = endpoint.address
	var port: int = endpoint.port
	var error: Error = app.join_from_ui(address, port)
	if error != OK:
		_direct.get_node("Error").text = app.connection.status if not app.connection.status.is_empty() else error_string(error)
		return
	_joining = true
	_direct.get_node("Confirm").disabled = true
	_direct.get_node("Error").text = _t("正在连接 {endpoint}…", {"endpoint": app.connection.format_endpoint(address, port)})

func submit_profile() -> void:
	if modal_kind != "Profile" or app.connection.online:
		return
	var name_value: String = _profile.get_node("Name").text.strip_edges()
	var error: Error = app.save_local_name(name_value)
	if error != OK:
		_profile.get_node("Error").text = _t("昵称需为 1–16 字，且不能包含控制字符") if error == ERR_INVALID_PARAMETER else _t("保存失败：{error}", {"error": error_string(error)})
		return
	close_modal()
	refresh()

func refresh() -> void:
	_sync_room()
	if _joining and app.connection.online:
		var stage: String = {"resolving": "正在解析地址…", "connecting": "正在连接…", "handshaking": "正在检查房间所需内容…", "connected": "已连接"}.get(app.connection.connection_state, "")
		_direct.get_node("Error").text = stage
	if _joining and not app.connection.online:
		_joining = false
		_direct.get_node("Confirm").disabled = false
		_direct.get_node("Error").text = app.connection.status
	if app._page == "lobby" and _room_view != null and page != "Lobby":
		_joining = false
		show_page("Lobby")
	elif app._page == "menu" and page == "Lobby":
		show_page("Home")
	$Home/Profile/Name.text = app.local_display_name()
	$Rooms/Info1.text = app.connection.format_endpoint(str(app.settings.config.get_value("connection", "address", "127.0.0.1")), int(app.settings.config.get_value("connection", "port", 7777)))
	$Rooms/Info1.tooltip_text = $Rooms/Info1.text
	if app._page == "lobby" and _room_view != null:
		_room_view.room_refresh()
	if app.connection.status != _connection_notice:
		_connection_notice = app.connection.status
		if not _connection_notice.is_empty():
			app.show_notice(_connection_notice)
			if _connection_notice.contains("\n"):
				app.show_connection_issue(_connection_notice)

## Replace the room scene when its lobby activation changes, including rule edits and recovery.
func _sync_room() -> void:
	var activity: PartyAPI = app.runner.prepare_room() if app._page == "lobby" else null
	if activity == _room_activity:
		return
	if _room_view != null:
		_room_view.room_stop()
		$Lobby.remove_child(_room_view)
		_room_view.queue_free()
		_room_view = null
	_room_activity = activity
	if activity == null:
		return
	var main: String = app.connection.room.main
	var definition: Dictionary = app.catalog.get_package(main)
	var packed: Resource = app.catalog.resource(main, definition.room_scene)
	if not packed is PackedScene:
		app.connection.leave.call_deferred("主游戏房间入口不是有效场景：" + main)
		return
	var view: Node = packed.instantiate()
	var valid: bool = view is Control
	for hook: String in ["room_setup", "room_refresh", "room_focus", "room_stop"]:
		valid = valid and view.has_method(hook)
	if not valid:
		view.free()
		app.connection.leave.call_deferred("主游戏房间场景缺少 Control 根节点或房间接口：" + main)
		return
	_room_view = view
	_room_view.room_setup(RoomAPI.new(activity, app.room_query, app.room_action))
	$Lobby.add_child(_room_view)

func _unhandled_key_input(event: InputEvent) -> void:
	# Framework dialogs own Escape while open, including the connectivity listener.
	for modal: Node in get_tree().get_nodes_in_group("framework_modal"):
		if modal is Control and modal.is_visible_in_tree():
			return
	if not is_visible_in_tree() or not event.is_action_pressed("ui_cancel"):
		return
	if navigation_back():
		get_viewport().set_input_as_handled()

func navigation_back() -> bool:
	if modal_kind == "Create":
		_create_back()
	elif not modal_kind.is_empty():
		close_modal()
	elif page == "Rooms":
		show_page("Home")
	elif page == "Home":
		open_modal("Confirm")
	elif page == "Lobby":
		app._confirm_action(_t("离开当前房间？"), app.connection.leave)
	else:
		return false
	return true

## Menu-owned presentation refreshes without rebuilding controls or overwriting user input.
func _apply_language() -> void:
	for binding: String in MENU_TEXT:
		var parts: PackedStringArray = binding.split(":")
		var target: Node = modal_layer.get_node(parts[0].trim_prefix("@")) if parts[0].begins_with("@") else get_node(parts[0])
		target.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		target.set(parts[1], _t(MENU_TEXT[binding]))
	if modal_kind == "Create":
		_refresh_host_addresses(str(_create.get_node("BindAddress").get_selected_metadata()))
	$Home/Language.select(0 if app.catalog.i18n.locale == "zh_Hans" else 1)
	if modal_kind == "Create":
		_build_games()
	refresh()

func _t(key: StringName, parameters: Dictionary = {}) -> String:
	return app.catalog.i18n.text("core", key, parameters)

func _select_language(index: int) -> void:
	var error: Error = app.select_language("zh_Hans" if index == 0 else "en")
	if error != OK:
		$Home/Language.select(0 if app.catalog.i18n.locale == "zh_Hans" else 1)
		app.show_notice(_t("语言保存失败：{error}", {"error": error_string(error)}))
