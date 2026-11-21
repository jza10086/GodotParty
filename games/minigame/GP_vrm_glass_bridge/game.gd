extends Control

const Pages = preload("res://games/protocols/GP_default_protocol/round_pages.gd")
const Pane = preload("res://games/assets/GP_platformer_3d_components/obstacles/one_shot_platform.gd")
const MOTION_INTERVAL: float = 1.0 / 15.0

@export var columns: Array[Dictionary]
@onready var course: VrmBridgeCourse = $Course
@onready var pages: Pages = $ProtocolPages
var api: PartyAPI
var request: Dictionary
var players: Array[Dictionary]
var panes: Array[Pane] = []
var previous_stats: Array = []
var targets: PackedVector3Array
var headings: PackedFloat32Array
var velocities: PackedVector3Array
var grounded: Array[bool] = []
var received_pose: bool = false
var sample_clock: float = 0.0
var last_controls: Dictionary
var jump_held: bool = false
var jump_pending: bool = false
var stopped: bool = false

func party_setup(context: PartyAPI, config: Dictionary) -> void:
	api = context
	request = config
	players = api.get_players()
	$Course.api = api
	$Course.roster = players
	var rules: Dictionary = api.get_settings()
	$Course.run_speed = rules.run_speed
	$Course.sprint_speed = rules.sprint_speed
	$Course.jump_height = rules.jump_height

func _ready() -> void:
	if api == null:
		push_error("请从 GodotParty 启动 VRM 玻璃桥，F6 预览请打开地图场景。")
		return
	for body: Node in course.find_children("*", "StaticBody3D", true, false):
		if body is Pane:
			panes.append(body)
	for racer: VrmBridgeRacer in course.racers:
		targets.append(racer.position)
		headings.append(racer.character.rotation.y)
		velocities.append(Vector3.ZERO)
		grounded.append(true)

		if api.is_host():
			racer.pane_broken.connect(_pane_broken)
	if api.is_host():
		course.completed.connect(_finish)
		course.race_started.connect(_race_started)
	pages.settlement.visibility_changed.connect(_settlement_visibility_changed)
	api.net.message_received.connect(_message)
	api.players_changed.connect(_players_changed)
	_players_changed()
	var error: Error = pages.prepare(self, api, request, course.start_round)
	if error != OK:
		api.fail("bridge_prepare", error_string(error))

func party_start() -> void:
	pages.transport_started()

func godot_party_graphics_targets() -> Dictionary:
	return {"world": $Course/Environment, "sun": $Course/Sun}

func godot_party_audio_target() -> PartyGameAudio:
	return null

func _players_changed() -> void:
	for player: Dictionary in api.get_players():
		if player.connected:
			continue
		for i: int in players.size():
			if players[i].player_id == player.player_id:
				var racer: VrmBridgeRacer = course.racers[i]
				racer.withdrawn = true
				racer.active = false
				racer.set_paused(true)
				racer.hide()
				racer.collision_layer = 0
				racer.collision_mask = 0

func _broadcast(topic: StringName, payload: Variant, mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE) -> void:
	var error: Error = api.net.broadcast(topic, payload, mode, false)
	if error != OK:
		party_stop(&"send_failed")
		api.fail("bridge_broadcast", error_string(error))

func _race_started() -> void:
	_broadcast(&"bridge/run", {})

func _pane_broken(pane: StaticBody3D) -> void:
	_broadcast(&"bridge/break", panes.find(pane))

func _physics_process(delta: float) -> void:
	if not course.playing or stopped:
		return
	if course.local_index >= 0 and course.phase == VrmBridgeCourse.Phase.RUNNING:
		var down: bool = api.input.is_pressed(&"vrm_bridge_jump")
		jump_pending = jump_pending or (down and not jump_held)
		jump_held = down
	if not api.is_host():
		_animate_replicas(delta)
		if course.phase == VrmBridgeCourse.Phase.COUNTDOWN:
			course.remaining = maxf(0.0, course.remaining - delta)
		elif course.phase == VrmBridgeCourse.Phase.RUNNING:
			course.elapsed += delta
	sample_clock += delta
	if sample_clock < MOTION_INTERVAL:
		return
	sample_clock = fmod(sample_clock, MOTION_INTERVAL)
	if course.phase != VrmBridgeCourse.Phase.RUNNING:
		return
	if course.local_index >= 0 and course.racers[course.local_index].active:
		_send_controls()
	if api.is_host():
		var pose: PackedVector3Array = []
		for racer: VrmBridgeRacer in course.racers:
			pose.append(racer.position)
			pose.append(racer.motion_velocity)
			pose.append(Vector3(racer.character.rotation.y, float(racer.is_on_floor()), 0))
		_broadcast(&"bridge/motion", pose, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)
		_publish_progress()

func _send_controls() -> void:
	var movement: Vector2 = api.input.get_vector(&"vrm_bridge_left", &"vrm_bridge_right", &"vrm_bridge_forward", &"vrm_bridge_back")
	var data: Dictionary = {"move": movement.rotated(-course.view.yaw), "sprint": api.input.is_pressed(&"vrm_bridge_sprint"), "jump": jump_pending}
	jump_pending = false
	if data == last_controls and not data.jump:
		return
	last_controls = data
	if api.is_host():
		_apply_controls(course.local_index, data)
	else:
		var error: Error = api.net.send_to_host(&"bridge/input", data)
		if error != OK:
			party_stop(&"send_failed")
			api.fail("bridge_input", error_string(error))

func _apply_controls(index: int, data: Dictionary) -> void:
	var racer: VrmBridgeRacer = course.racers[index]
	if racer.active:
		racer.set_motion_input(data.move, data.sprint, data.jump)

func _message(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if stopped:
		return
	if topic == &"bridge/input":
		if not api.is_host() or course.phase != VrmBridgeCourse.Phase.RUNNING or not payload is Dictionary:
			return
		if not payload.get("move") is Vector2 or not payload.move.is_finite() or payload.move.length_squared() > 1.001 or not payload.get("jump") is bool or not payload.get("sprint") is bool:
			return
		for i: int in players.size():
			if players[i].peer_id == sender.peer_id and players[i].player_id in sender.player_ids and not course.racers[i].withdrawn:
				_apply_controls(i, payload)
				return
	if sender.peer_id != 1 or api.is_host():
		return
	match topic:
		&"bridge/run":
			course.phase = VrmBridgeCourse.Phase.RUNNING
			for racer: VrmBridgeRacer in course.racers:
				racer.active = not racer.withdrawn
				racer.set_paused(racer.withdrawn)
		&"bridge/break":
			if payload is int and payload >= 0 and payload < panes.size():
				panes[payload].stepped_on()
		&"bridge/motion":
			if payload is PackedVector3Array and payload.size() == players.size() * 3:
				for i: int in players.size():
					targets[i] = payload[3*i]
					velocities[i] = payload[3*i+1]
					headings[i] = payload[3*i+2].x
					grounded[i] = payload[3*i+2].y > 0.5
				received_pose = true
		&"bridge/progress":
			if payload is Array and payload.size() == players.size():
				for i: int in players.size():
					var row: Variant = payload[i]
					if not row is Array or row.size() != 4 or not row[0] is int or not row[1] is int or not row[2] is int or not row[3] is float:
						return
				course.results.clear()
				for i: int in players.size():
					var racer: VrmBridgeRacer = course.racers[i]
					racer.tokens = payload[i][0]
					racer.checkpoint_count = payload[i][1]
					racer.rank = payload[i][2]
					racer.finish_time = payload[i][3]
					if racer.rank > 0:
						racer.active = false
						racer.set_paused(true)
						course.results.append(racer)

func _animate_replicas(delta: float) -> void:
	if not received_pose:
		return
	for i: int in players.size():
		var racer: VrmBridgeRacer = course.racers[i]
		racer.apply_replica_pose(targets[i], headings[i], velocities[i], grounded[i], delta)


func _publish_progress() -> void:
	var stats: Array = []
	for racer: VrmBridgeRacer in course.racers:
		stats.append([racer.tokens, racer.checkpoint_count, racer.rank, racer.finish_time])
	if stats != previous_stats:
		previous_stats = stats
		_broadcast(&"bridge/progress", stats)

func _settlement_visibility_changed() -> void:
	if pages.settlement.visible:
		course.playing = false
		for racer: VrmBridgeRacer in course.racers:
			racer.set_paused(true)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _finish() -> void:
	_publish_progress()
	var rows: Array[Dictionary] = []
	var standings: Array[VrmBridgeRacer] = course.ranked_racers()
	var places: Array[int] = course.standing_places(standings)
	for i: int in standings.size():
		var racer: VrmBridgeRacer = standings[i]
		var player: Dictionary = players[course.racers.find(racer)]
		var seconds: float = racer.finish_time if racer.rank > 0 else course.elapsed
		rows.append({"player_id": player.player_id, "rank": places[i],
			"status": "withdrawn" if racer.withdrawn else "completed", "metrics": {"score": racer.tokens,
			"gates": racer.checkpoint_count, "finished": int(racer.rank > 0), "time": roundi(seconds * 1000.0)}})
	var error: Error = pages.present({"request_id": request.request_id, "rankings": rows, "columns": columns, "reason": "completed"})
	if error != OK:
		api.fail("bridge_result", error_string(error))

func party_stop(_reason: StringName) -> void:
	if stopped:
		return
	stopped = true
	$Course.stop_round()
	if api != null and api.net.message_received.is_connected(_message):
		api.net.message_received.disconnect(_message)
		api.players_changed.disconnect(_players_changed)
