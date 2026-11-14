## Playlist-owned room presentation, reusing the authored framework room scene.
extends Control
const RoomAPI = preload("res://core/api/party_room_api.gd")
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
	_button("CopyAddress", _copy_room_address)
	for index: int in range(8):
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

## Copy the selected endpoint; never advertise a different local interface.
func _copy_room_address() -> void:
	DisplayServer.clipboard_set(room.format_endpoint(connection.connection_address, connection.connection_port))
	room.show_notice("已复制房间地址")

func room_refresh() -> void:
	connection = room.get_state()
	%CopyAddress.disabled = not connection.online or connection.connection_address in ["", "*", "0.0.0.0", "::"]
	%CopyAddress.tooltip_text = room.format_endpoint(connection.connection_address, connection.connection_port)
	var unready: bool = false
	for index: int in range(8):
		var player: Dictionary = connection.players[index] if index < connection.players.size() else {}
		var slot: Button = get_node("%Slot" + str(index))
		var name_label: Label = slot.get_node("%PlayerName")
		slot.player_color = Color(player.appearance.color) if not player.is_empty() else Color(0.30, 0.35, 0.42)
		slot.set_meta("peer_id", player.get("peer_id", 0))
		slot.disabled = player.is_empty()
		slot.modulate.a = 0.5 if player.is_empty() else 1.0
		name_label.text = player.get("name", "空位")
		name_label.tooltip_text = name_label.text
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

		if player.get("connected", false) and not player.get("ready", false):
			unready = true
	_refresh_latencies()
	%PlayerCount.text = "%d / 8 人" % connection.players.size()
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
		%Ready.theme_type_variation = &"CancelRed" if no_selection or invalid_player_count or unready else &"StartOrange"
	else:
		%Ready.text = "取消准备" if connection.local_ready else "准备"
		%Ready.theme_type_variation = &"CancelRed" if connection.local_ready else &"ReadyGreen"
	%Ready.get_node("Caption").text = %Ready.text
	%Ready.tooltip_text = ""
	%CopyAddress.disabled = %CopyAddress.disabled or connection.connection_port <= 0
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
	for index: int in range(8):
		var label: Label = get_node("%Slot" + str(index)).get_node("%PlayerStatus")
		label.modulate = Color.WHITE
		label.tooltip_text = ""
		if index >= connection.players.size():
			label.text = ""
			continue
		var player: Dictionary = connection.players[index]
		var ready_text: String = "已准备" if player.ready else "未准备"
		var peer: int = 1 if not connection.host and player.peer_id == connection.local_peer else player.peer_id
		var sample: Dictionary = room.activity.net.get_peer_stats(peer)
		var state: String = "host" if player.connected and player.peer_id == 1 else sample.state
		label.tooltip_text = "玩家与房主之间的往返延迟 RTT；按住 Tab 查看全部玩家"
		match state:
			"host":
				label.text = "host"
			"offline":
				label.text = "已掉线"
				label.modulate = Color("#f28c8c")
			"measuring":
				label.text = ready_text + " · 测量中"
			"stalled":
				label.text = ready_text + " · 无响应"
				label.modulate = Color("#f28c8c")
			"connected", "degraded":
				label.text = ready_text + " · %d ms" % roundi(sample.rtt_msec)
				if state == "degraded":
					label.text += " · 波动"
					label.modulate = Color("#f3c779")
