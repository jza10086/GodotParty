## Single active voice owner; microphone PCM, host relay and bounded per-speaker playout.
extends Node
signal monitor_stopped(message: String)
const PCM = preload("res://core/network/party_pcm.gd")
var connection: Node
var settings: PartyInput
var scope: String = ""
var generation: int = 0
var epoch: String = ""
var started: bool = false
var route_evaluator: Callable
var _policy: Dictionary = {"mode": "off"}
var _entities: Dictionary = {}
var _endpoint: Dictionary = {}
var _buses: Array[String] = []
var _capture: AudioEffectCapture
var _microphone: AudioStreamPlayer
var _codec: RefCounted = PCM.new()
var _streams: Dictionary = {}
var _anchors: Dictionary = {}
var _segment: int = 0
var _sequence: int = 0
var _transmitting: bool = false
var monitoring: bool = false
var _monitor_device_check: float = 0.0
var _capture_device: String = ""
var _reason: String = ""
var _received: int = 0
var _sent: int = 0
var _limits: Dictionary = {}
var _segments: Dictionary = {}
var _playout_floor: Dictionary = {}
var _capture_bus: String = "PartyCapture"

func initialize(link: Node, local_settings: PartyInput) -> void:
	connection = link
	settings = local_settings
	connection.media_received.connect(_receive)
	connection.control_received.connect(_control)
	connection.disconnected.connect(func(_peer: int) -> void: _clear_streams())

func activate(id: String, token: String) -> void:
	deactivate()
	scope = id
	epoch = token
	generation += 1

func deactivate() -> void:
	started = false
	if monitoring:
		stop_monitor("语音场景已切换，监听已结束。")
	else:
		_stop_capture()
	_clear_streams()
	scope = ""
	_reason = ""
	epoch = ""
	_endpoint.clear()
	_buses.clear()
	_entities.clear()
	_anchors.clear()
	_policy = {"mode": "off"}
	route_evaluator = Callable()
	_limits.clear()
	_segments.clear()
	_playout_floor.clear()
	generation += 1

func register_bus(name_value: String) -> Error:
	if scope.is_empty() or not name_value.begins_with("party." + scope + ".") or AudioServer.get_bus_index(name_value) < 0:
		return ERR_INVALID_PARAMETER
	if name_value not in _buses:
		_buses.append(name_value)
	return OK

func configure_endpoint(options: Dictionary) -> Error:
	for key: String in ["capture_requested", "transmit_requested", "receive_requested"]:
		if not options.get(key) is bool:
			return ERR_INVALID_PARAMETER
	if options.transmit_requested and not options.capture_requested:
		return ERR_INVALID_PARAMETER
	if options.get("playback_bus", "") not in _buses or AudioServer.get_bus_index(options.get("playback_bus", "")) < 0:
		_endpoint.clear()
		_clear_streams()
		return ERR_UNCONFIGURED
	if _endpoint.get("playback_bus") != options.playback_bus:
		_clear_streams()
	_endpoint = options.duplicate(true)
	return OK

func set_policy(value: Dictionary) -> Error:
	if not connection.host:
		return ERR_UNAUTHORIZED
	if value.get("mode") not in ["off", "global", "group", "proximity", "custom"]:
		return ERR_INVALID_PARAMETER
	if value.mode == "proximity" and (not (value.get("radius") is float or value.get("radius") is int) or not is_finite(float(value.radius)) or value.radius <= 0):
		return ERR_INVALID_PARAMETER
	if _policy != value:
		_policy = value.duplicate(true)
		_codec.clear()
		if _capture != null:
			_capture.clear_buffer()
		_segments.clear()
		_playout_floor.clear()
		epoch = str(Time.get_ticks_usec()) + ":" + scope
		connection.control("voice_policy", {"scope": scope, "epoch": epoch}, 0)
		_clear_streams()
	return OK

func update_entities(value: Dictionary) -> Error:
	if not connection.host:
		return ERR_UNAUTHORIZED
	for id: Variant in value:
		if not id is String or not value[id] is Dictionary:
			return ERR_INVALID_PARAMETER
		if value[id].has("position") and not value[id].position is Vector3:
			return ERR_INVALID_PARAMETER
	_entities = value.duplicate(true)
	return OK

func bind_anchor(id: String, anchor: Node) -> Error:
	if not anchor is Node2D and not anchor is Node3D:
		return ERR_INVALID_PARAMETER
	_anchors[id] = weakref(anchor)
	if _streams.has(id):
		_remove_stream(id)
	return OK

func status() -> Dictionary:
	return {"available": not scope.is_empty(), "reason": _reason, "capture": not monitoring and is_instance_valid(_microphone), "microphone_mode": settings.microphone_mode(), "transmitting": _transmitting, "receiving": _endpoint.get("receive_requested", false), "received_frames": _received, "sent_frames": _sent, "codec": "pcm16/16000/mono", "noise_suppression": false, "echo_cancellation": false}

func _control(sender: int, kind: String, payload: Dictionary) -> void:
	if payload.get("scope") != scope:
		return
	if kind == "voice_sync" and connection.host:
		connection.control("voice_policy", {"scope": scope, "epoch": epoch}, sender)
	elif sender == 1 and kind == "voice_policy" and payload.get("epoch") is String:
		if epoch != payload.epoch:
			epoch = payload.epoch
			_clear_streams()
			_segments.clear()
			_playout_floor.clear()
			_codec.clear()
			if _capture != null:
				_capture.clear_buffer()
	elif kind == "voice_segment" and payload.get("epoch") == epoch and payload.get("segment") is int and payload.get("sending") is bool:
		if connection.host:
			var identity: Dictionary = connection._player_peer(sender)
			if identity.is_empty():
				return
			var current: Dictionary = _segments.get(identity.player_id, {})
			if payload.segment < current.get("segment", -1):
				return
			_segments[identity.player_id] = {"segment": payload.segment, "sending": payload.sending}
			for player: Dictionary in connection.players:
				if player.connected and player.peer_id != 1:
					var notice: Dictionary = payload.duplicate(true)
					notice["speaker"] = identity.player_id
					connection.control("voice_notice", notice, player.peer_id)
			if not payload.sending:
				_remove_stream(identity.player_id)
	elif sender == 1 and kind == "voice_notice" and payload.get("epoch") == epoch and payload.get("speaker") is String and payload.get("segment") is int:
		var current: Dictionary = _segments.get(payload.speaker, {})
		if payload.segment >= current.get("segment", -1):
			_segments[payload.speaker] = {"segment": payload.segment, "sending": payload.get("sending", false)}
			if not payload.get("sending", false):
				_remove_stream(payload.speaker)

func sync_epoch() -> void:
	if connection.host:
		connection.control("voice_policy", {"scope": scope, "epoch": epoch})
	else:
		connection.control("voice_sync", {"scope": scope}, 1)

## Local sidetone uses the saved devices and exclusively owns the microphone until stopped.
func start_monitor() -> String:
	var devices: Dictionary = settings.voice_devices()
	if not devices.microphone_allowed:
		return "请先在“声音与设备”中允许使用麦克风，并应用保存。"
	if not devices.input.available:
		return "所选麦克风不可用：" + devices.input.selected
	if not devices.output.available:
		return "所选输出设备不可用：" + devices.output.selected
	_stop_capture()
	AudioServer.output_device = devices.output.selected
	monitoring = true
	_monitor_device_check = 0.0
	_start_capture(devices.input.selected)
	return ""

func stop_monitor(message: String = "监听已结束。") -> void:
	if monitoring:
		_stop_capture()
		monitoring = false
		monitor_stopped.emit(message)

## Input peak before the master bus, in decibels. Only read during local monitoring.
func monitor_peak_db() -> float:
	var index: int = AudioServer.get_bus_index(_capture_bus)
	return maxf(AudioServer.get_bus_peak_volume_left_db(index, 0), AudioServer.get_bus_peak_volume_right_db(index, 0))

func _process(delta: float) -> void:
	if monitoring:
		_monitor_device_check -= delta
		if _monitor_device_check <= 0.0:
			_monitor_device_check = 0.25
			var devices: Dictionary = settings.voice_devices()
			if not devices.microphone_allowed or not devices.input.available or not devices.output.available or devices.input.selected != _capture_device:
				stop_monitor("麦克风授权或音频设备已变更，监听已结束。")
		_playout()
		return
	if scope.is_empty() or not connection.online:
		return
	var input_device: String = settings.config.get_value("system", "input_device", "Default")
	var wants_capture: bool = started and _endpoint.get("capture_requested", false)
	_reason = ""
	if wants_capture:
		if not settings.config.get_value("system", "microphone_allowed", false):
			_reason = "本机未授权麦克风"
		elif input_device not in AudioServer.get_input_device_list():
			_reason = "所选麦克风不可用：" + input_device
	var capture_requested: bool = wants_capture and _reason.is_empty()
	if capture_requested and settings.microphone_mode() == "push_to_talk":
		capture_requested = PartyInput.push_to_talk_pressed(get_viewport())
	if is_instance_valid(_microphone) and (not capture_requested or input_device != _capture_device):
		_stop_capture()
	if capture_requested and not is_instance_valid(_microphone):
		_start_capture(input_device)
	var transmit: bool = capture_requested and _endpoint.get("transmit_requested", false) and is_instance_valid(_microphone)
	if transmit != _transmitting:
		_transmitting = transmit
		_segment += 1
		_sequence = 0
		_codec.clear()
		if _capture != null:
			_capture.clear_buffer()
		connection.control("voice_segment", {"scope": scope, "epoch": epoch, "segment": _segment, "sending": transmit}, 1)
	if _capture != null:
		var available: int = _capture.get_frames_available()
		if available > 0:
			var frames: PackedVector2Array = _capture.get_buffer(available)
			if transmit:
				var outgoing: Array[PackedByteArray] = _codec.capture(frames, AudioServer.get_mix_rate())
				# Keep only fresh media after a frame hitch; never flush an old recording in a burst.
				for index: int in range(maxi(0, outgoing.size() - 3), outgoing.size()):
					send_frame(outgoing[index])
	_playout()

## Also used by a transport smoke test; the same packet/relay path carries microphone frames.
func send_frame(bytes: PackedByteArray) -> Error:
	if not started or bytes.size() != PCM.BYTES:
		return ERR_UNAVAILABLE
	var packet: Dictionary = {"scope": scope, "epoch": epoch, "segment": _segment, "sequence": _sequence, "pcm": bytes}
	_sequence += 1
	_sent += 1
	if connection.host:
		_receive(1, packet)
		return OK
	return connection.send_media(1, packet)

func _start_capture(device: String) -> void:
	_capture_device = device
	AudioServer.input_device = device
	if AudioServer.get_bus_index(_capture_bus) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, _capture_bus)
	var index: int = AudioServer.get_bus_index(_capture_bus)
	AudioServer.set_bus_mute(index, not monitoring)
	if not monitoring:
		_capture = AudioEffectCapture.new()
		_capture.buffer_length = 0.2
		AudioServer.add_bus_effect(index, _capture)
	_microphone = AudioStreamPlayer.new()
	_microphone.stream = AudioStreamMicrophone.new()
	_microphone.bus = _capture_bus
	add_child(_microphone)
	_microphone.play()

func _stop_capture() -> void:
	if _transmitting and connection != null and connection.online and not scope.is_empty():
		_segment += 1
		connection.control("voice_segment", {"scope": scope, "epoch": epoch, "segment": _segment, "sending": false}, 1)
	if is_instance_valid(_microphone):
		_microphone.stop()
		_microphone.queue_free()
	_microphone = null
	_capture_device = ""
	_capture = null
	_codec.clear()
	_transmitting = false
	var index: int = AudioServer.get_bus_index(_capture_bus)
	if index >= 0:
		AudioServer.remove_bus(index)

func _allowed(sender: String, receiver: String) -> bool:
	if sender == receiver or _policy.mode == "off":
		return false
	if _policy.mode == "global":
		return true
	var source: Dictionary = _entities.get(sender, {})
	var target: Dictionary = _entities.get(receiver, {})
	if _policy.mode == "group":
		return source.has("group") and source.get("group") == target.get("group")
	if _policy.mode == "proximity":
		return source.get("position") is Vector3 and target.get("position") is Vector3 and source.get("space") == target.get("space") and source.position.distance_to(target.position) <= float(_policy.radius)
	return route_evaluator.is_valid() and route_evaluator.call(sender, receiver, _entities.duplicate(true)) == true

func _receive(sender: int, packet: Dictionary) -> void:
	if not started or packet.get("scope") != scope or packet.get("epoch") != epoch or not packet.get("pcm") is PackedByteArray or packet.pcm.size() != PCM.BYTES:
		return
	if not packet.get("segment") is int or not packet.get("sequence") is int or packet.segment < 0 or packet.sequence < 0:
		return
	if connection.host:
		var identity: Dictionary = connection._player_peer(sender)
		if identity.is_empty() or not identity.connected:
			return
		var now: int = Time.get_ticks_msec()
		var limit: Dictionary = _limits.get(sender, {"time": now, "count": 0})
		if now - int(limit.time) > 1000:
			limit = {"time": now, "count": 0}
		limit.count += 1
		_limits[sender] = limit
		if limit.count > 60:
			return
		packet = packet.duplicate(true)
		packet["speaker"] = identity.player_id
		var state: Dictionary = _segments.get(identity.player_id, {})
		if packet.segment < state.get("segment", -1) or (packet.segment == state.get("segment", -1) and not state.get("sending", false)):
			return
		for player: Dictionary in connection.players:
			if player.connected and _allowed(identity.player_id, player.player_id):
				if player.peer_id == 1:
					_enqueue(packet)
				else:
					connection.send_media(player.peer_id, packet)
	elif sender == 1 and packet.get("speaker") is String:
		_enqueue(packet)

func _enqueue(packet: Dictionary) -> void:
	if not _endpoint.get("receive_requested", false):
		return
	var id: String = packet.speaker
	var state: Dictionary = _segments.get(id, {})
	if packet.segment < state.get("segment", -1) or (packet.segment == state.get("segment", -1) and not state.get("sending", false)):
		return
	var floor_value: Dictionary = _playout_floor.get(id, {})
	if packet.segment < floor_value.get("segment", -1) or (packet.segment == floor_value.get("segment", -1) and packet.sequence < floor_value.get("next", 0)):
		return
	if not _streams.has(id):
		_create_stream(id, packet)
	if not _streams.has(id):
		return
	var stream: Dictionary = _streams[id]
	if packet.segment < stream.segment:
		return
	if packet.segment > stream.segment:
		_remove_stream(id)
		_create_stream(id, packet)
		stream = _streams.get(id, {})
		if stream.is_empty():
			return
	if packet.sequence < stream.next or packet.sequence > stream.next + 50:
		return
	if stream.queue.size() >= 10:
		stream.queue.clear()
		stream.next = packet.sequence
		stream.due = Time.get_ticks_msec() + 60
	stream.queue[packet.sequence] = packet.pcm
	stream.last = Time.get_ticks_msec()
	_received += 1

func _create_stream(id: String, packet: Dictionary) -> void:
	var bus: String = _endpoint.get("playback_bus", "")
	if bus not in _buses or AudioServer.get_bus_index(bus) < 0:
		_reason = "播放总线不可用"
		return
	var anchor: Node = _anchors[id].get_ref() if _anchors.has(id) else null
	var player: Node = AudioStreamPlayer2D.new() if anchor is Node2D else (AudioStreamPlayer3D.new() if anchor is Node3D else AudioStreamPlayer.new())
	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = PCM.RATE
	generator.buffer_length = 0.08
	player.stream = generator
	player.bus = bus
	add_child(player)
	player.play()
	_streams[id] = {"player": player, "playback": player.get_stream_playback(), "queue": {}, "next": packet.sequence, "segment": packet.segment, "due": Time.get_ticks_msec() + 60, "last": Time.get_ticks_msec()}

func _playout() -> void:
	var now: int = Time.get_ticks_msec()
	for id: String in _streams.keys():
		var stream: Dictionary = _streams[id]
		if now - int(stream.last) > 240 or not _endpoint.get("receive_requested", false):
			_remove_stream(id)
			continue
		var anchor: Node = _anchors[id].get_ref() if _anchors.has(id) else null
		if is_instance_valid(anchor):
			stream.player.global_position = anchor.global_position
		if now < stream.due:
			continue
		if now - int(stream.due) > 200:
			_remove_stream(id)
			continue
		var playback: AudioStreamGeneratorPlayback = stream.playback
		if playback.get_frames_available() < PCM.SAMPLES:
			continue
		var bytes: PackedByteArray = stream.queue.get(stream.next, PackedByteArray())
		var frames: PackedVector2Array = PCM.decode(bytes)
		if frames.is_empty():
			frames.resize(PCM.SAMPLES)
		playback.push_buffer(frames)
		stream.queue.erase(stream.next)
		stream.next += 1
		_playout_floor[id] = {"segment": stream.segment, "next": stream.next}
		stream.due += 20

func _remove_stream(id: String) -> void:
	if _streams.has(id):
		var player: Node = _streams[id].player
		player.stop()
		player.queue_free()
		_streams.erase(id)

func _clear_streams() -> void:
	for id: String in _streams.keys():
		_remove_stream(id)
