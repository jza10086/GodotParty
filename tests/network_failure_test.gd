## Focused host-side fault checks for loading cancellation and RPC boundaries.
extends SceneTree

const BASE_PORT: int = 17020

var _failures: Array[String] = []
var _received_action_count: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_reported_load_failure()
	await _test_load_timeout()
	await _test_loading_disconnect()
	await _test_playing_disconnect_and_action_filters()

	if _failures.is_empty():
		print("NETWORK_FAILURE_TEST: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("NETWORK_FAILURE_TEST: %s" % failure)
	quit(1)


func _test_reported_load_failure() -> void:
	var context: Array[Node] = _create_host_context(BASE_PORT, 15.0)
	if context.is_empty():
		return
	var session: GameSessionState = context[0] as GameSessionState
	var manager: NetworkManagerService = context[1] as NetworkManagerService
	manager.request_start_game(LobbyProtocol.TARGET_CLICK_GAME_ID)
	var active_round_id: int = session.round_id
	manager.report_local_game_loaded(
		active_round_id,
		LobbyProtocol.TARGET_CLICK_GAME_ID,
		false,
		"simulated load failure"
	)
	_expect(session.phase == GameSessionState.Phase.LOBBY, "A reported load failure should cancel the round.")
	_expect(session.round_id == active_round_id, "Cancelling a round should retain its round ID.")
	_expect(not session.players_by_peer[2].is_ready, "Cancellation should clear client readiness.")
	await _dispose_context(context)


func _test_load_timeout() -> void:
	var context: Array[Node] = _create_host_context(BASE_PORT + 1, 0.05)
	if context.is_empty():
		return
	var session: GameSessionState = context[0] as GameSessionState
	var manager: NetworkManagerService = context[1] as NetworkManagerService
	manager.request_start_game(LobbyProtocol.TARGET_CLICK_GAME_ID)
	manager.report_local_game_loaded(
		session.round_id,
		LobbyProtocol.TARGET_CLICK_GAME_ID,
		true,
		""
	)
	await create_timer(0.12).timeout
	_expect(session.phase == GameSessionState.Phase.LOBBY, "A missing participant load ACK should time out and cancel.")
	await _dispose_context(context)


func _test_loading_disconnect() -> void:
	var context: Array[Node] = _create_host_context(BASE_PORT + 2, 15.0)
	if context.is_empty():
		return
	var session: GameSessionState = context[0] as GameSessionState
	var manager: NetworkManagerService = context[1] as NetworkManagerService
	manager.request_start_game(LobbyProtocol.TARGET_CLICK_GAME_ID)
	manager._on_peer_disconnected(2)
	_expect(session.phase == GameSessionState.Phase.LOBBY, "A loading participant disconnect should cancel the round.")
	_expect(not session.players_by_peer.has(2), "The disconnected player should be removed from the lobby.")
	await _dispose_context(context)


func _test_playing_disconnect_and_action_filters() -> void:
	var context: Array[Node] = _create_host_context(BASE_PORT + 3, 15.0)
	if context.is_empty():
		return
	var session: GameSessionState = context[0] as GameSessionState
	var manager: NetworkManagerService = context[1] as NetworkManagerService
	manager.request_start_game(LobbyProtocol.TARGET_CLICK_GAME_ID)
	_expect(
		session.set_round_phase(GameSessionState.Phase.PLAYING) == OK,
		"Fault test should enter PLAYING."
	)
	manager._on_peer_disconnected(2)
	var withdrawn_result: MinigamePlayerResult = session.get_round_result(2)
	_expect(session.phase == GameSessionState.Phase.PLAYING, "A playing client disconnect should not cancel the round.")
	_expect(withdrawn_result != null and withdrawn_result.is_withdrawn, "A playing disconnect should retain a withdrawn result.")

	_received_action_count = 0
	manager.minigame_action_received.connect(_on_minigame_action_received)
	var payload: Dictionary[StringName, Variant] = {}
	payload[LobbyProtocol.KEY_HIT_INDEX] = 0
	payload[LobbyProtocol.KEY_ELAPSED_MS] = 100
	manager._handle_minigame_action(
		LobbyProtocol.SERVER_PEER_ID,
		session.round_id - 1,
		LobbyProtocol.TARGET_HIT_ACTION,
		payload
	)
	manager._handle_minigame_action(
		999,
		session.round_id,
		LobbyProtocol.TARGET_HIT_ACTION,
		payload
	)
	var oversized_payload: Dictionary[StringName, Variant] = {}
	var field_index: int = 0
	while field_index <= LobbyProtocol.MAX_ACTION_PAYLOAD_FIELDS:
		oversized_payload[StringName("field_%d" % field_index)] = field_index
		field_index += 1
	manager._handle_minigame_action(
		LobbyProtocol.SERVER_PEER_ID,
		session.round_id,
		LobbyProtocol.TARGET_HIT_ACTION,
		oversized_payload
	)
	manager._handle_minigame_action(
		LobbyProtocol.SERVER_PEER_ID,
		session.round_id,
		LobbyProtocol.TARGET_HIT_ACTION,
		payload
	)
	_expect(_received_action_count == 1, "Only the current, known, well-formed action should be forwarded.")
	await _dispose_context(context)


func _create_host_context(port: int, load_timeout_seconds: float) -> Array[Node]:
	var definition_template: MinigameDefinition = load(
		"res://game/minigames/target_click/target_click_definition.tres"
	) as MinigameDefinition
	if definition_template == null:
		_failures.append("Target-click definition should load for fault tests.")
		return []
	var definition: MinigameDefinition = definition_template.duplicate(true) as MinigameDefinition
	definition.load_timeout_seconds = load_timeout_seconds

	var session: GameSessionState = GameSessionState.new()
	session.name = "FaultGameSession"
	root.add_child(session)
	var manager: NetworkManagerService = NetworkManagerService.new()
	manager.name = "FaultNetworkManager"
	manager.game_session = session
	root.add_child(manager)
	var definitions: Array[MinigameDefinition] = [definition]
	_expect(manager.register_minigames(definitions) == OK, "Fault-test definition should register.")
	var host_error: Error = manager.host_session("FaultHost", port)
	if host_error != OK:
		_failures.append("Fault-test host failed on port %d: %s" % [port, error_string(host_error)])
		manager.queue_free()
		session.queue_free()
		return []
	session.upsert_player(SessionPlayer.new(2, "FaultClient", false, true))
	return [session, manager]


func _dispose_context(context: Array[Node]) -> void:
	var session: GameSessionState = context[0] as GameSessionState
	var manager: NetworkManagerService = context[1] as NetworkManagerService
	manager.leave_session()
	manager.queue_free()
	session.queue_free()
	await process_frame


func _on_minigame_action_received(
		_peer_id: int,
		_round_id: int,
		_action_id: StringName,
		_payload: Dictionary
) -> void:
	_received_action_count += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
