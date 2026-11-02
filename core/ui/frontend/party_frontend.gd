## Application navigation. Main-game room scenes own the lobby presentation and controls.
extends Control
const RoomAPI = preload("res://core/api/party_room_api.gd")
@export var app: Control
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
## Bind the authored pages once the application has loaded its catalog and session.
func initialize() -> void:
	# Source pages use fixed-height text boxes. Center single-line text within each row.
	for node: Node in find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF and not label.text.contains("\n"):
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var protocols: Array[String] = app.catalog.ids("protocols")
	if not protocols.is_empty():
		selected_protocol = protocols[0]
	_button("Home/Menu/Start", func() -> void: open_modal("Create"))
	_button("Home/Menu/Join", func() -> void: show_page("Rooms"))
	_button("Home/Menu/Settings", app._settings_dialog)
	_button("Home/Menu/ListenTest", app._connectivity_dialog.bind(false))
	_button("Home/Menu/ConnectTest", app._connectivity_dialog.bind(true))
	_button("Home/Menu/Exit", func() -> void: open_modal("Confirm"))
	_button("Home/Profile", func() -> void: open_modal("Profile"))
	_button("Rooms/Back", func() -> void: show_page("Home"))
	_button("Rooms/Direct", func() -> void: open_modal("Direct"))
	_button("Rooms/Join1", func() -> void: open_modal("Direct"))
	$Modal/Create/Game.item_selected.connect(func(index: int) -> void: select_game($Modal/Create/Game.get_item_metadata(index)))
	_button("Modal/Create/Cancel", _create_back)
	_button("Modal/Create/Confirm", submit_create)
	_button("Modal/Profile/Cancel", close_modal)
	_button("Modal/Profile/Confirm", submit_profile)
	_button("Modal/Direct/Cancel", close_modal)
	_button("Modal/Direct/Confirm", submit_direct)
	_button("Modal/Confirm/Cancel", close_modal)
	_button("Modal/Confirm/Quit", func() -> void: get_tree().quit())
	$Modal/Profile/Name.text_submitted.connect(func(_text: String) -> void: submit_profile())
	$Modal/Direct/Port.text_submitted.connect(func(_text: String) -> void: submit_direct())
	$Rooms/RoomsSubtitle.text = "通过 IP 直连加入房主 · 房间发现服务暂未开放"
	$Rooms/Name0.text = "房间发现暂未开放"
	$Rooms/Info0.text = "当前没有公共房间列表；请向房主获取地址和端口。"
	$Rooms/Join0.text = "暂不可用"
	$Rooms/Join0.disabled = true
	$Rooms/Name1.text = "上次使用的连接地址"
	$Rooms/Join1.text = "填写 / 连接"
	for key: String in ["Room2", "Name2", "Info2", "Join2"]:
		get_node("Rooms/" + key).hide()
	$Modal/Create/Note.text = "选择已安装的大游戏，确认后创建真实联机房间。"
	$Modal/Create/Port.text_submitted.connect(func(_text: String) -> void: submit_create())
	$Modal/Create/Visibility.clear()
	$Modal/Create/Visibility.add_item("IP 直连")
	$Modal/Create/Visibility.disabled = true
	$Modal/Direct/Title.text = "IP 直连"
	$Modal/Direct/Confirm.text = "连接房间"
	$Modal/Direct/Note.text = "IPv4 / IPv6 地址（可带方括号），端口单独填写"
	$Modal/Direct/Port.max_length = 0
	$Modal/Direct/Address.max_length = 64
	$Modal/Direct/Address.placeholder_text = "192.168.1.10 或 2001:db8::1"
	for path: String in ["Modal/Create/Error", "Modal/Direct/Error", "Rooms/Info1"]:
		var label: Label = get_node(path)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.mouse_entered.connect(func() -> void: label.tooltip_text = label.text)
	$Modal/Profile/Note.text = "昵称保存在本机；协议形象由所选协议提供。"
	$Modal/Profile/Name.max_length = 16
	$Modal/Profile/Name.placeholder_text = "1–16 字"
	$Modal/Profile/Avatar/Placeholder.text = "形象"
	$Modal/Profile/AvatarNote.text = "头像与形象请在加入房间后，点击大厅中的本人资料设置。"
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	get_parent().resized.connect(_fit)
	_fit()
	show_page("Home")
	refresh()

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
		var contract: Dictionary = app.catalog.get_package(selected_protocol).get("contract", {})
		if binding.get("id") == selected_protocol and binding.get("api_major") == contract.get("api_major") and int(binding.get("min_api_minor", 0)) <= int(contract.get("api_minor", 0)):
			_games.append(id)
	var options: Array[String] = app.catalog.ids("protocols") if _create_step == "protocol" else _games
	var picker: OptionButton = $Modal/Create/Game
	picker.clear()
	for id: String in options:
		picker.add_item(app.catalog.get_package(id).get("name", id))
		picker.set_item_metadata(picker.item_count - 1, id)
	$Modal/Create/Title.text = "创建房间 · 选择协议" if _create_step == "protocol" else "创建房间 · 选择大游戏"
	$Modal/Create/GameLabel.text = "协议" if _create_step == "protocol" else "大游戏"
	$Modal/Create/Confirm.text = "下一步" if _create_step == "protocol" else "创建房间"
	$Modal/Create/Cancel.text = "取消" if _create_step == "protocol" else "上一步"
	$Modal/Create/Note.text = "协议决定房间规则、形象与公共体验。" if _create_step == "protocol" else "仅显示兼容大游戏；具体配置在创建后的大厅设置。"
	for key: String in ["RoomNameLabel", "RoomName", "PortLabel", "Port", "VisibilityLabel", "Visibility"]:
		get_node("Modal/Create/" + key).visible = _create_step == "game"
	$Modal/Create/Game.disabled = options.is_empty()
	$Modal/Create/Confirm.disabled = options.is_empty()
	if options.is_empty():
		selected_game = ""
		$Modal/Create/Game.text = "没有已安装的协议" if _create_step == "protocol" else "没有兼容的大游戏"
	else:
		var current: String = selected_protocol if _create_step == "protocol" else selected_game
		select_game(current if current in options else options[0])

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
	var picker: OptionButton = $Modal/Create/Game
	for index: int in picker.item_count:
		if picker.get_item_metadata(index) == id:
			picker.select(index)
			break

func _create_back() -> void:
	if _create_step == "game":
		_create_step = "protocol"
		$Modal/Create/Error.text = ""
		_build_games()
	else:
		close_modal()

func navigation_scope() -> Control:
	if not modal_kind.is_empty():
		return get_node("Modal/" + modal_kind)
	return get_node(page)

func show_page(next: String) -> void:
	close_modal()
	for key: String in ["Home", "Rooms", "Lobby"]:
		get_node(key).visible = key == next
	page = next
	$Toast.hide()
	if page == "Lobby":
		_room_view.room_focus()
	else:
		get_node("Home/Menu/Start" if page == "Home" else "Rooms/Direct").grab_focus()

func open_modal(kind: String) -> void:
	close_modal()
	previous_focus = get_viewport().gui_get_focus_owner()
	modal_kind = kind
	$Modal.show()
	for key: String in ["Create", "Direct", "Profile", "Confirm"]:
		get_node("Modal/" + key).visible = kind == key
	_set_page_focus(false)
	match kind:
		"Create":
			_create_step = "protocol"
			_build_games()
			$Modal/Create/RoomName.text = "我的派对"
			$Modal/Create/Error.text = ""
			$Modal/Create/Port.text = str(app.settings.config.get_value("connection", "host_port", 7777))
			$Modal/Create/DropdownNote.text = "同时监听 IPv4 / IPv6 · 请允许所填 UDP 端口通过防火墙"
			$Modal/Create/Game.grab_focus()
		"Direct":
			$Modal/Direct/Address.text = str(app.settings.config.get_value("connection", "address", "127.0.0.1"))
			$Modal/Direct/Port.text = str(app.settings.config.get_value("connection", "port", 7777))
			$Modal/Direct/Error.text = ""
			$Modal/Direct/Confirm.disabled = false
			$Modal/Direct/Address.grab_focus()
		"Profile":
			$Modal/Profile/Name.text = app.local_display_name()
			$Modal/Profile/Error.text = ""
			$Modal/Profile/Name.grab_focus()
		_: $Modal/Confirm/Cancel.grab_focus()

func close_modal() -> void:
	if _joining and app.connection.room.is_empty():
		_joining = false
		app.connection.leave()
	$Modal.hide()
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
		$Modal/Create/Error.text = "请选择兼容的大游戏"
		return
	var title: String = $Modal/Create/RoomName.text.strip_edges()
	if not app.connection.valid_room_name(title):
		$Modal/Create/Error.text = "请输入 1–24 字的房间名称"
		return
	var port: int = app.connection.parse_port($Modal/Create/Port.text)
	if port == 0:
		$Modal/Create/Error.text = "端口请输入 1–65535 的整数"
		return
	var error: Error = app.host_from_ui(selected_game, title, port)
	if error != OK:
		$Modal/Create/Error.text = app.connection.status if not app.connection.status.is_empty() else error_string(error)

func submit_direct() -> void:
	if modal_kind != "Direct" or _joining:
		return
	var address: String = app.connection.normalize_address($Modal/Direct/Address.text)
	var port: int = app.connection.parse_port($Modal/Direct/Port.text)
	if address.is_empty():
		$Modal/Direct/Error.text = "请输入有效 IPv4 / IPv6，端口请填在下方"
		return
	if port == 0:
		$Modal/Direct/Error.text = "端口请输入 1–65535 的整数"
		return
	var error: Error = app.join_from_ui(address, port)
	if error != OK:
		$Modal/Direct/Error.text = app.connection.status if not app.connection.status.is_empty() else error_string(error)
		return
	_joining = true
	$Modal/Direct/Confirm.disabled = true
	$Modal/Direct/Error.text = "正在连接 " + app.connection.format_endpoint(address, port) + "…"

func submit_profile() -> void:
	if modal_kind != "Profile" or app.connection.online:
		return
	var name_value: String = $Modal/Profile/Name.text.strip_edges()
	var error: Error = app.save_local_name(name_value)
	if error != OK:
		$Modal/Profile/Error.text = "昵称需为 1–16 字，且不能包含控制字符" if error == ERR_INVALID_PARAMETER else "保存失败：" + error_string(error)
		return
	close_modal()
	refresh()

func refresh() -> void:
	_sync_room()
	if _joining and not app.connection.online:
		_joining = false
		$Modal/Direct/Confirm.disabled = false
		$Modal/Direct/Error.text = app.connection.status
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
			show_notice(_connection_notice)

## Reuse the source scene feedback panel for actual connection and validation errors.
func show_notice(message: String) -> void:
	$Toast/Text.text = message.replace("\n", " ")
	$Toast/Text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	$Toast/Text.tooltip_text = message
	$Toast.show()

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
	var packed: Resource = load(app.catalog.path(main, definition.room_scene))
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
		app._confirm_action("离开当前房间？", app.connection.leave)
	else:
		return false
	return true
