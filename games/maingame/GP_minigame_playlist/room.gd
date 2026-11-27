## Playlist-owned room presentation, reusing the authored framework room scene.
extends Control
const RoomAPI = preload("res://core/api/party_room_api.gd")
const PLAYER_CAPACITY: int = 12
var room: RoomAPI
var connection: Dictionary
var _latency_refresh_in: float = 0.0

func room_setup(value: RoomAPI) -> void:
	room = value
	connection = room.get_state()

func _ready() -> void:
	_button("Back", room.leave)
	_button("Ready", room.ready_or_start)
	_button("Map", room.open_settings.bind("pool"))
	%Rotation.item_selected.connect(_rotation_selected)
	_button("Advanced", room.open_settings.bind("main"))
	_button("CopyAddress", _share_room)
	for index: int in range(PLAYER_CAPACITY):
		var slot: Button = get_node("%Slot" + str(index))
		slot.pressed.connect(func() -> void: room.show_player(slot.get_meta("peer_id")))
	room_refresh()

func _button(path: String, action: Callable) -> void:
	get_node("%" + path).pressed.connect(action)

func _rotation_selected(index: int) -> void:
	room.update_main_settings({"rotation": ["顺序", "随机"][index]})
	room_refresh()

func room_focus() -> void:
	if %Ready.disabled:
		%Map.grab_focus()
	else:
		%Ready.grab_focus()

func _process(delta: float) -> void:
	_latency_refresh_in -= delta
	if _latency_refresh_in <= 0.0:
		_latency_refresh_in = 1.0
		_refresh_latencies()

func room_stop() -> void:
	set_process(false)

## Share the active room through its transport.
func _share_room() -> void:
	if connection.steam_lobby:
		room.invite_friends()
		return
	DisplayServer.clipboard_set(room.format_endpoint(connection.connection_address, connection.connection_port))
	room.show_notice("已复制房间地址")

func room_refresh() -> void:
	connection = room.get_state()
	var caption: String = "邀请 Steam 好友" if connection.steam_lobby else "复制房间地址"
	%CopyAddress.text = caption
	%CopyAddress.semantic_color = "blue"
	%CopyAddress.enabled_state = false
	%CopyAddress.disabled = not connection.online or (not connection.steam_lobby and (connection.connection_port <= 0 or connection.connection_address in ["", "*", "0.0.0.0", "::"]))
	%CopyAddress.tooltip_text = caption if connection.steam_lobby else room.format_endpoint(connection.connection_address, connection.connection_port)
	var unready: bool = false
	for index: int in range(PLAYER_CAPACITY):
		var player: Dictionary = connection.players[index] if index < connection.players.size() else {}
		var slot: Button = get_node("%Slot" + str(index))
		var name_label: Label = slot.get_node("%PlayerName")
		var occupied: bool = not player.is_empty()
		slot.player_color = Color(player.appearance.color) if occupied else Color(0.58, 0.78, 0.94, 0.28)
		slot.set_meta("peer_id", player.get("peer_id", 0))
		slot.call("set_occupied", occupied)
		name_label.text = player.get("name", "空位")
		name_label.tooltip_text = name_label.text
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

		if player.get("connected", false) and not player.get("ready", false):
			unready = true
	_refresh_latencies()
	%PlayerCount.text = "%d / %d 人" % [connection.players.size(), PLAYER_CAPACITY]
	%AllowedPlayerCounts.text = _allowed_count_text(connection.allowed_counts) + "]"
	var invalid_player_count: bool = connection.players.size() not in connection.allowed_counts
	var count: int = 0
	for pool: Array in connection.room.get("pools", {}).values():
		count += pool.size()
	var no_selection: bool = count == 0
	var reason: String = connection.start_reason
	%ReadySummary.text = reason if connection.host and not unready and not no_selection and not invalid_player_count else ""
	%Ready.disabled = connection.host and (no_selection or invalid_player_count or unready or not reason.is_empty())
	if connection.host:
		if no_selection:
			%Ready.text = "未选择小游戏"
		elif invalid_player_count:
			%Ready.text = "非法玩家数"
		else:
			%Ready.text = "玩家未准备" if unready else "开始游戏"
		%Ready.semantic_color = "red" if no_selection or invalid_player_count or unready else "orange"
		%Ready.enabled_state = false
	else:
		%Ready.text = "取消准备" if connection.local_ready else "准备"
		%Ready.semantic_color = "red" if connection.local_ready else "green"
		%Ready.enabled_state = bool(connection.local_ready)
	%Ready.tooltip_text = ""
	%Map.text = "小游戏池"
	%Rotation.select(["顺序", "随机"].find(connection.room.settings.rotation))
	%Rotation.disabled = not connection.host or connection.recovering
	%Map.tooltip_text = "已选择 %d 项 · %s" % [count, "房主配置" if connection.host else "查看房主配置"]
	%Rotation.tooltip_text = "轮换模式" if connection.host else "轮换模式由房主设置"
	%Advanced.tooltip_text = "轮换局数、避免游戏重复与局间间隔"


## Format the actual allowed set, using a range only when every intermediate count is allowed.
func _allowed_count_text(values: Array) -> String:
	if values.is_empty():
		return "无"
	var counts: Array = values.duplicate()
	counts.sort()
	if counts.size() > 1 and counts.back() - counts.front() + 1 == counts.size():
		return "%d-%d 人" % [counts.front(), counts.back()]
	var parts: PackedStringArray = []
	for count: int in counts:
		parts.append(str(count))
	return "/".join(parts) + " 人"

## Read cached statistics once a second; never rebuild slots or request a probe here.
func _refresh_latencies() -> void:
	for index: int in range(PLAYER_CAPACITY):
		var slot: Button = get_node("%Slot" + str(index))
		slot.tooltip_text = ""
		if index >= connection.players.size():
			slot.call("set_badges", "", "wait", "")
			continue
		var player: Dictionary = connection.players[index]
		var ready_text: String = "已准备" if player.ready else "未准备"
		var ready_kind: String = "ready" if player.ready else "wait"
		var peer: int = 1 if not connection.host and player.peer_id == connection.local_peer else player.peer_id
		var sample: Dictionary = room.activity.net.get_peer_stats(peer)
		var state: String = "host" if player.connected and player.peer_id == 1 else sample.state
		slot.tooltip_text = "玩家与房主之间的往返延迟 RTT；按住 Tab 查看全部玩家"
		match state:
			"host":
				slot.call("set_badges", "房主", "host", "")
			"offline":
				slot.call("set_badges", "已掉线", "danger", "")
			"measuring":
				slot.call("set_badges", ready_text, ready_kind, "测量中", Color(0.72, 0.78, 0.86, 1.0))
			"stalled":
				slot.call("set_badges", "无响应", "danger", "")
			"connected":
				var rtt_ms: int = roundi(sample.rtt_msec)
				var rtt_color: Color = Color(0.55, 0.88, 0.66, 1.0) if rtt_ms < 80 else (Color(0.95, 0.78, 0.47, 1.0) if rtt_ms < 160 else Color(0.95, 0.55, 0.55, 1.0))
				slot.call("set_badges", ready_text, ready_kind, "%d ms" % rtt_ms, rtt_color)
			"degraded":
				slot.call("set_badges", ready_text, ready_kind, "%d ms 波动" % roundi(sample.rtt_msec), Color(0.95, 0.78, 0.47, 1.0))
			_:
				slot.call("set_badges", ready_text, ready_kind, "")
