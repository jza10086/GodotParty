## Focused target-race movement, capture, respawn, and correction checks.
extends SceneTree

var _failures: Array[String] = []
var _latest_results: Array[MinigamePlayerResult] = []
var _state_count: int = 0
var _session: GameSessionState = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_session = root.get_node_or_null("GameSession") as GameSessionState
	if _session == null:
		_session = GameSessionState.new()
		_session.name = "GameSession"
		root.add_child(_session)
	InputConfigLoader.ensure_global_movement_actions()
	_session.begin_session(1, true)
	_session.upsert_player(SessionPlayer.new(1, "Host", true, true))
	_session.upsert_player(SessionPlayer.new(2, "Client", false, true))
	var packed_scene: PackedScene = load(
		"res://game/minigames/target_race/target_race.tscn"
	) as PackedScene
	var definition: MinigameDefinition = load(
		"res://game/minigames/target_race/target_race_definition.tres"
	) as MinigameDefinition
	_expect(packed_scene != null and definition != null, "Target-race resources should load.")
	if packed_scene == null or definition == null:
		_finish()
		return
	var controller: MinigameController = packed_scene.instantiate() as MinigameController
	_expect(controller != null, "Target-race root should implement MinigameController.")
	if controller == null:
		_finish()
		return
	root.add_child(controller)
	await process_frame
	controller.authoritative_progress_updated.connect(_on_progress_updated)
	controller.authoritative_realtime_state_updated.connect(_on_state_updated)
	var players: Array[SessionPlayer] = _session.get_sorted_players()
	_expect(
		controller.prepare_round(1, 12345, players, definition) == OK,
		"A valid target-race round should prepare."
	)
	var normalized: Vector2 = Vector2(1.0, 1.0).normalized()
	var input_payload: Dictionary[StringName, Variant] = {}
	input_payload[&"direction"] = normalized
	_expect(
		controller.handle_authoritative_realtime_input(2, 1, input_payload) == OK,
		"A normalized movement direction should be accepted."
	)
	input_payload[&"direction"] = Vector2(2.0, 0.0)
	_expect(
		controller.handle_authoritative_realtime_input(2, 2, input_payload) != OK,
		"An over-length movement direction should be rejected."
	)
	controller.begin_play()
	await physics_frame
	await physics_frame
	var positions: Dictionary = controller.get("_authoritative_positions") as Dictionary
	var initial_client_position: Vector2 = positions[2]
	await physics_frame
	positions = controller.get("_authoritative_positions") as Dictionary
	_expect(
		positions[2].distance_to(initial_client_position) > 0.0,
		"Accepted input should move the authoritative player."
	)
	var target: Vector2 = controller.get("_target_position") as Vector2
	positions[2] = target
	controller.set("_authoritative_positions", positions)
	await physics_frame
	var client_result: MinigamePlayerResult = _find_result(2)
	_expect(
		client_result != null and client_result.score == 1,
		"Entering the target should award one point."
	)
	var next_target: Vector2 = controller.get("_target_position") as Vector2
	_expect(next_target != target, "A captured target should respawn.")
	positions = controller.get("_authoritative_positions") as Dictionary
	for position: Vector2 in positions.values():
		_expect(
			position.distance_to(next_target) >= 70.0,
			"Respawned target must not overlap a player."
		)
	_expect(_state_count > 0, "Host should publish realtime state snapshots.")

	controller.set("_simulation_stopped", true)
	_session.local_is_host = false
	_session.local_peer_id = 2
	var state_payload: Dictionary[StringName, Variant] = {}
	state_payload[&"server_tick"] = 10
	state_payload[&"positions"] = {
		1: Vector2(300.0, 300.0),
		2: Vector2(1400.0, 700.0),
	}
	state_payload[&"acknowledged_inputs"] = {1: 0, 2: 2}
	state_payload[&"target_position"] = next_target
	state_payload[&"scores"] = {1: 0, 2: 1}
	_expect(
		controller.apply_authoritative_realtime_state(10, state_payload) == OK,
		"A valid authority state should apply."
	)
	var render_positions: Dictionary = controller.get("_render_positions") as Dictionary
	_expect(
		render_positions[2].distance_to(Vector2(1400.0, 700.0)) < 0.1,
		"A correction over 96 pixels should snap the local player."
	)
	await create_timer(0.2).timeout
	render_positions = controller.get("_render_positions") as Dictionary
	_expect(
		render_positions[1].distance_to(Vector2(300.0, 300.0)) < 2.0,
		"Remote player interpolation should reach the authority position."
	)
	controller.cleanup_round()
	controller.queue_free()
	await process_frame
	_session.reset_session()
	_finish()


func _on_progress_updated(
		results: Array[MinigamePlayerResult],
		_finish_requested: bool
) -> void:
	_latest_results.clear()
	for result: MinigamePlayerResult in results:
		_latest_results.append(result.duplicate_result())


func _on_state_updated(_sequence: int, _payload: Dictionary) -> void:
	_state_count += 1


func _find_result(peer_id: int) -> MinigamePlayerResult:
	for result: MinigamePlayerResult in _latest_results:
		if result.peer_id == peer_id:
			return result
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TARGET_RACE_CONTROLLER_TEST: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("TARGET_RACE_CONTROLLER_TEST: %s" % failure)
	quit(1)
