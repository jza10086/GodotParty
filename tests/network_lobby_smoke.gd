## Two-process ENet smoke test for lobby, two full rounds, replay, and lobby return.
extends SceneTree

const TEST_PORT: int = 17000
const TIMEOUT_SECONDS: float = 45.0
const EXPECTED_ROUNDS: int = 2

var _role: String = ""
var _finishing: bool = false
var _start_requested: bool = false
var _session: GameSessionState = null
var _network_manager: NetworkManagerService = null
var _definition: MinigameDefinition = null
var _controller: MinigameController = null
var _submitted_rounds: Dictionary[int, bool] = {}
var _completed_rounds: int = 0
var _last_result_round_id: int = 0
var _last_loaded_round_id: int = 0
var _first_controller_instance_id: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_session = GameSessionState.new()
	_session.name = "SmokeGameSession"
	root.add_child(_session)
	_network_manager = NetworkManagerService.new()
	_network_manager.name = "SmokeNetworkManager"
	_network_manager.game_session = _session
	root.add_child(_network_manager)
	_definition = load(
		"res://game/minigames/target_click/target_click_definition.tres"
	) as MinigameDefinition
	if _definition == null:
		_fail("target-click definition did not load")
		return
	var definitions: Array[MinigameDefinition] = [_definition]
	var registration_error: Error = _network_manager.register_minigames(definitions)
	if registration_error != OK:
		_fail("definition registration failed: %s" % error_string(registration_error))
		return

	_role = _read_role()
	_network_manager.connection_failed.connect(_on_failure)
	_network_manager.session_left.connect(_on_session_left)
	_network_manager.round_cancelled.connect(_on_round_cancelled)
	_network_manager.round_loading_started.connect(_on_round_loading_started)
	_network_manager.round_countdown_started.connect(_on_round_countdown_started)
	_network_manager.round_play_started.connect(_on_round_play_started)
	_network_manager.round_progress_changed.connect(_on_round_progress_changed)
	_network_manager.round_results_ready.connect(_on_round_results_ready)
	_network_manager.lobby_returned.connect(_on_lobby_returned)
	_network_manager.minigame_action_received.connect(_on_minigame_action_received)
	var timeout: SceneTreeTimer = create_timer(TIMEOUT_SECONDS)
	timeout.timeout.connect(_on_timeout)

	if _role == "host":
		_session.players_changed.connect(_on_host_players_changed)
		var host_error: Error = _network_manager.host_session("SmokeHost", TEST_PORT)
		if host_error != OK:
			_fail("host_session failed: %s" % error_string(host_error))
		return
	if _role == "client":
		_network_manager.lobby_joined.connect(_on_client_lobby_joined)
		var join_error: Error = _network_manager.join_session(
			"SmokeClient",
			LobbyProtocol.DEFAULT_ADDRESS,
			TEST_PORT
		)
		if join_error != OK:
			_fail("join_session failed: %s" % error_string(join_error))
		return
	_fail("missing --role=host or --role=client")


func _read_role() -> String:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = 0
	while index < arguments.size():
		if arguments[index].begins_with("--role="):
			return arguments[index].trim_prefix("--role=")
		index += 1
	return ""


func _on_client_lobby_joined() -> void:
	_network_manager.set_local_ready(true)


func _on_host_players_changed(_players: Array[SessionPlayer]) -> void:
	if _start_requested or not _session.can_host_start():
		return
	_start_requested = true
	_network_manager.request_start_game(LobbyProtocol.TARGET_CLICK_GAME_ID)


func _on_round_loading_started(
		round_id: int,
		game_id: StringName,
		random_seed_value: int
) -> void:
	if game_id != LobbyProtocol.TARGET_CLICK_GAME_ID:
		_fail("unexpected game ID")
		return
	if round_id <= _last_loaded_round_id:
		_fail("round ID did not increase")
		return
	_last_loaded_round_id = round_id

	if _controller != null:
		_controller.cleanup_round()
		_controller.queue_free()
		_controller = null
		await process_frame

	_controller = _definition.scene.instantiate() as MinigameController
	if _controller == null:
		_network_manager.report_local_game_loaded(
			round_id,
			game_id,
			false,
			"scene root is not MinigameController"
		)
		return
	root.add_child(_controller)
	await process_frame
	var instance_id: int = _controller.get_instance_id()
	if _first_controller_instance_id == 0:
		_first_controller_instance_id = instance_id
	elif instance_id == _first_controller_instance_id:
		_fail("replay did not instantiate a fresh controller")
		return
	_controller.authoritative_progress_updated.connect(
		_on_authoritative_progress_updated
	)
	var prepare_error: Error = _controller.prepare_round(
		round_id,
		random_seed_value,
		_session.get_sorted_players(),
		_definition
	)
	var failure_reason: String = ""
	if prepare_error != OK:
		failure_reason = error_string(prepare_error)
	_network_manager.report_local_game_loaded(
		round_id,
		game_id,
		prepare_error == OK,
		failure_reason
	)


func _on_round_countdown_started(round_id: int, duration_seconds: float) -> void:
	if not _is_active_round(round_id):
		_fail("countdown started without an active controller")
		return
	_controller.begin_countdown(duration_seconds)


func _on_round_play_started(round_id: int) -> void:
	if not _is_active_round(round_id):
		_fail("play started without an active controller")
		return
	_controller.begin_play()
	if _submitted_rounds.has(round_id):
		_fail("play event was emitted more than once")
		return
	_submitted_rounds[round_id] = true
	call_deferred("_submit_all_hits", round_id)


func _submit_all_hits(round_id: int) -> void:
	var hit_index: int = 0
	while hit_index < 10:
		if _session.phase != GameSessionState.Phase.PLAYING:
			_fail("round left PLAYING before all smoke-test hits were submitted")
			return
		var payload: Dictionary[StringName, Variant] = {}
		payload[LobbyProtocol.KEY_HIT_INDEX] = hit_index
		var base_elapsed_ms: int = 100 if _role == "host" else 200
		payload[LobbyProtocol.KEY_ELAPSED_MS] = base_elapsed_ms + hit_index * 10
		_network_manager.submit_minigame_action(
			round_id,
			LobbyProtocol.TARGET_HIT_ACTION,
			payload
		)
		hit_index += 1
		await create_timer(0.01).timeout


func _on_minigame_action_received(
		peer_id: int,
		round_id: int,
		action_id: StringName,
		payload: Dictionary
) -> void:
	if _role != "host" or not _is_active_round(round_id):
		return
	var action_error: Error = _controller.handle_authoritative_action(
		peer_id,
		action_id,
		payload
	)
	if action_error != OK:
		_fail(
			"authoritative action was rejected: %s"
			% error_string(action_error)
		)


func _on_authoritative_progress_updated(
		results: Array[MinigamePlayerResult],
		finish_requested: bool
) -> void:
	if _role != "host" or _controller == null:
		return
	_network_manager.publish_minigame_progress(
		_controller.active_round_id,
		results,
		finish_requested
	)


func _on_round_progress_changed(
		round_id: int,
		results: Array[MinigamePlayerResult]
) -> void:
	if _is_active_round(round_id):
		_controller.apply_authoritative_results(results)


func _on_round_results_ready(
		round_id: int,
		results: Array[MinigamePlayerResult]
) -> void:
	if round_id == _last_result_round_id:
		return
	_last_result_round_id = round_id
	_completed_rounds += 1
	if results.size() != 2:
		_fail("result snapshot should contain two players")
		return
	if results[0].rank != 1 or results[1].rank != 2:
		_fail("final rankings were not synchronized")
		return
	if not results[0].is_complete or not results[1].is_complete:
		_fail("both smoke-test players should complete")
		return
	if _role != "host":
		return
	var decision_delay: SceneTreeTimer = create_timer(0.1)
	if _completed_rounds == 1:
		decision_delay.timeout.connect(_network_manager.request_replay_round)
	elif _completed_rounds == EXPECTED_ROUNDS:
		decision_delay.timeout.connect(_network_manager.request_return_to_lobby)
	else:
		_fail("host completed an unexpected number of rounds")


func _on_lobby_returned() -> void:
	if _completed_rounds != EXPECTED_ROUNDS:
		_fail("returned to lobby before two rounds completed")
		return
	if _session.phase != GameSessionState.Phase.LOBBY:
		_fail("lobby return did not restore the LOBBY phase")
		return
	var local_player: SessionPlayer = _session.get_local_player()
	if local_player == null:
		_fail("local player was lost on lobby return")
		return
	if not local_player.is_host and local_player.is_ready:
		_fail("client readiness was not cleared on lobby return")
		return
	_finishing = true
	print("NETWORK_LIFECYCLE_SMOKE_%s: PASS" % _role.to_upper())
	if _role == "host":
		var close_delay: SceneTreeTimer = create_timer(0.5)
		close_delay.timeout.connect(_finish_success)
	else:
		_finish_success()


func _is_active_round(round_id: int) -> bool:
	return _controller != null and _controller.active_round_id == round_id


func _finish_success() -> void:
	if _controller != null:
		_controller.cleanup_round()
	_network_manager.leave_session()
	quit(0)


func _on_failure(reason: String) -> void:
	_fail(reason)


func _on_session_left(reason: String) -> void:
	if not _finishing:
		_fail(reason)


func _on_round_cancelled(reason: String) -> void:
	_fail("round was cancelled: %s" % reason)


func _on_timeout() -> void:
	if not _finishing:
		_fail("timed out")


func _fail(reason: String) -> void:
	if _finishing:
		return
	_finishing = true
	push_error("NETWORK_LIFECYCLE_SMOKE_%s: %s" % [_role.to_upper(), reason])
	if _network_manager != null:
		_network_manager.leave_session()
	quit(1)
