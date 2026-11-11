## Playlist-owned room presentation, reusing the authored framework room scene.
## Voice exists only for this lobby activation; new activations always start with the microphone off.
extends Control
const RoomAPI = preload("res://core/api/party_room_api.gd")
var room: RoomAPI
var connection: Dictionary
var _voice_bus: String = ""
var _microphone: bool = false
var _receive: bool = true
var _stopped: bool = false
var _latency_refresh_in: float = 0.0

func room_setup(value: RoomAPI) -> void:
	room = value
	connection = room.get_state()

func _ready() -> void:
	_button("Back", room.leave)
	_button("Ready", room.ready_or_start)
	_button("Map", room.open_settings.bind("pool"))
	_button("Rounds", room.open_settings.bind("main"))
	_button("Advanced", room.open_settings.bind("protocol"))
	_button("Microphone", _toggle_microphone)
	_button("Receive", _toggle_receive)
	_button("CopyAddress", _copy_room_address)
	for index: int in range(8):
		var slot: Button = get_node("%Slot" + str(index))
		slot.pressed.connect(func() -> void: room.show_player(slot.get_meta("peer_id")))
	%VoiceStatus.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	%VoiceStatus.mouse_filter = Control.MOUSE_FILTER_PASS
	%VoiceStatus.mouse_entered.connect(func() -> void: %VoiceStatus.tooltip_text = %VoiceStatus.text)
	room_refresh()
	var error: Error = room.activity.on_close(room_stop)
	if error != OK:
		_voice_error(error)
		return
	_voice_bus = "party." + room.activity.scope_id + ".playlist_lobby"
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, _voice_bus)
	AudioServer.set_bus_send(AudioServer.get_bus_index(_voice_bus), "Master")
	error = room.activity.voice.register_playback_bus(_voice_bus)
	if error == OK and connection.host:
		error = room.activity.voice.set_policy({"mode": "global"})
	if error == OK:
		error = _apply_voice()
	if error != OK:
		_voice_error(error)

func _button(path: String, action: Callable) -> void:
	get_node("%" + path).pressed.connect(action)

func room_focus() -> void:
	if %Ready.disabled:
		%Map.grab_focus()
	else:
		%Ready.grab_focus()

func _toggle_microphone() -> void:
	if not _microphone:
		var devices: Dictionary = room.activity.voice.get_local_devices()
		if not devices.available:
			return
		if not devices.microphone_allowed or not devices.input.available:
			room.open_settings("system")
			room.show_notice("请在本地设置的“声音与设备”中授权并选择可用的麦克风，再开启大厅麦克风。")
			return
	_microphone = not _microphone
	var error: Error = _apply_voice()
	if error != OK:
		_voice_error(error)

func _toggle_receive() -> void:
	_receive = not _receive
	var error: Error = _apply_voice()
	if error != OK:
		_voice_error(error)

func _apply_voice() -> Error:
	var error: Error = room.activity.voice.configure_local_endpoint({"capture_requested": _microphone,
		"transmit_requested": _microphone, "receive_requested": _receive, "playback_bus": _voice_bus})
	if error == OK:
		%Microphone.text = "关闭麦克风" if _microphone else "开启麦克风"
		%Receive.text = "关闭收听" if _receive else "开启收听"
	return error

func _voice_error(error: Error) -> void:
	room_stop()
	room.show_notice("大厅语音初始化或设置失败：" + error_string(error))

func _process(delta: float) -> void:
	if _stopped:
		return
	_latency_refresh_in -= delta
	if _latency_refresh_in <= 0.0:
		_latency_refresh_in = 1.0
		_refresh_latencies()
	var status: Dictionary = room.activity.voice.get_status()
	var microphone_status: String = "关闭"
	if status.get("transmitting", false):
		microphone_status = "正在发送"
	elif _microphone and status.get("microphone_mode") == "push_to_talk" and str(status.get("reason", "")).is_empty():
		microphone_status = "按住 V 说话"
	var message: String = "麦克风：" + microphone_status
	message += " · 收听：" + ("开启" if _receive else "关闭")
	if _microphone and not str(status.get("reason", "")).is_empty():
		message += " · " + str(status.reason)
	%VoiceStatus.text = message

## The activity closes before its bus is removed; stop manual scene removal as well.
func room_stop() -> void:
	if _stopped:
		return
	_stopped = true
	set_process(false)
	%Microphone.disabled = true
	%Receive.disabled = true
	if room.activity.voice.get_status().available:
		var error: Error = room.activity.voice.configure_local_endpoint({"capture_requested": false,
			"transmit_requested": false, "receive_requested": false, "playback_bus": _voice_bus})
		if error != OK:
			push_error("停止大厅语音失败：" + error_string(error))
	if not _voice_bus.is_empty():
		var index: int = AudioServer.get_bus_index(_voice_bus)
		if index >= 0:
			AudioServer.remove_bus(index)

func _exit_tree() -> void:
	room_stop()

## Copy the selected endpoint; never advertise a different local interface.
func _copy_room_address() -> void:
	DisplayServer.clipboard_set(room.format_endpoint(connection.connection_address, connection.connection_port))
	room.show_notice("已复制房间地址")

func room_refresh() -> void:
	connection = room.get_state()
	%CopyAddress.disabled = not connection.online or connection.connection_address in ["", "*", "0.0.0.0", "::"]
	%CopyAddress.tooltip_text = room.format_endpoint(connection.connection_address, connection.connection_port)
	var main: String = connection.room.get("main", "")
	var game_name: String = room.get_game_name(main)
	%LobbyTitle.text = connection.room.get("title", "GodotParty")
	%LobbySubtitle.text = game_name
	var unready: bool = false
	for index: int in range(8):
		var player: Dictionary = connection.players[index] if index < connection.players.size() else {}
		var name_label: Label = get_node("%SlotName" + str(index))
		var slot: Button = get_node("%Slot" + str(index))
		slot.set_meta("peer_id", player.get("peer_id", 0))
		slot.disabled = player.is_empty()
		slot.modulate.a = 0.5 if player.is_empty() else 1.0
		name_label.text = player.get("name", "等待加入") + (" · 房主" if player.get("peer_id") == 1 else "")
		name_label.tooltip_text = name_label.text
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

		if player.get("connected", false) and not player.get("ready", false):
			unready = true
	_refresh_latencies()
	%PlayerCount.text = "%d / 8 人" % connection.players.size()
	%PlayerCount.tooltip_text = "允许开始：" + connection.allowed_counts
	var reason: String = connection.start_reason
	%ReadySummary.text = reason if connection.host and not unready else ""
	%Ready.disabled = connection.host and (unready or not reason.is_empty())
	if connection.host:
		%Ready.text = "有玩家未准备" if unready else "开始游戏"
		%Ready.theme_type_variation = &"CancelRed" if unready else &"StartOrange"
	else:
		%Ready.text = "取消准备" if connection.local_ready else "准备"
		%Ready.theme_type_variation = &"CancelRed" if connection.local_ready else &"ReadyGreen"
	%Ready.get_node("Caption").text = %Ready.text
	%Ready.tooltip_text = reason
	%CopyAddress.disabled = %CopyAddress.disabled or connection.connection_port <= 0
	var count: int = 0
	for pool: Array in connection.room.get("pools", {}).values():
		count += pool.size()
	%Map.text = "已选择 %d 项 · 查看 / 配置" % count
	%Rounds.text = "查看 / 配置"
	%Map.tooltip_text = "房主配置" if connection.host else "查看房主配置"
	%Rounds.tooltip_text = %Map.tooltip_text


## Read cached statistics once a second; never rebuild slots or request a probe here.
func _refresh_latencies() -> void:
	for index: int in range(8):
		var label: Label = get_node("%SlotStatus" + str(index))
		label.modulate = Color.WHITE
		label.tooltip_text = ""
		if index >= connection.players.size():
			label.text = "空位"
			continue
		var player: Dictionary = connection.players[index]
		var ready_text: String = "已准备" if player.ready else "未准备"
		var peer: int = 1 if not connection.host and player.peer_id == connection.local_peer else player.peer_id
		var sample: Dictionary = room.activity.net.get_peer_stats(peer)
		var state: String = "host" if player.connected and player.peer_id == 1 else sample.state
		label.tooltip_text = "玩家与房主之间的往返延迟 RTT；按住 Tab 查看全部玩家"
		match state:
			"host":
				label.text = "房主"
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
