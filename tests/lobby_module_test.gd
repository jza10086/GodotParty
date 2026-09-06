## Focused pure-logic checks for lobby and minigame lifecycle state.
extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_display_names_and_ports()
	_test_registration_and_action_payloads()
	_test_session_player_round_trip()
	_test_result_round_trip_and_order()
	_test_result_capacity_orders()
	_test_player_counts_sorting_and_readiness()
	_test_lifecycle_snapshots()

	if _failures.is_empty():
		print("LOBBY_MODULE_TEST: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("LOBBY_MODULE_TEST: %s" % failure)
	quit(1)


func _test_display_names_and_ports() -> void:
	_expect(SessionPlayer.validate_display_name("玩家-1234") == OK, "Chinese nickname should be valid.")
	_expect(SessionPlayer.normalize_display_name("  Alice  ") == "Alice", "Nickname edges should be trimmed.")
	_expect(SessionPlayer.validate_display_name("") != OK, "Empty nickname should be rejected.")
	_expect(SessionPlayer.validate_display_name("123456789012345678901") != OK, "Nickname over 20 characters should be rejected.")
	_expect(SessionPlayer.validate_display_name("Bad\nName") != OK, "Control characters should be rejected.")
	_expect(LobbyProtocol.validate_port(7000) == OK, "Default port should be valid.")
	_expect(LobbyProtocol.validate_port(1023) != OK, "Ports below 1024 should be rejected.")
	_expect(LobbyProtocol.validate_port(65536) != OK, "Ports above 65535 should be rejected.")


func _test_registration_and_action_payloads() -> void:
	var payload: Dictionary[StringName, Variant] = LobbyProtocol.make_registration_payload("  Alice  ")
	_expect(LobbyProtocol.validate_registration_payload(payload) == OK, "Generated registration should be valid.")
	_expect(String(payload[LobbyProtocol.KEY_DISPLAY_NAME]) == "Alice", "Generated registration should normalize nickname.")

	var wrong_version: Dictionary = payload.duplicate(true)
	wrong_version[LobbyProtocol.KEY_PROTOCOL_VERSION] = LobbyProtocol.PROTOCOL_VERSION + 1
	_expect(LobbyProtocol.validate_registration_payload(wrong_version) == ERR_UNAVAILABLE, "Wrong protocol version should be rejected distinctly.")

	var action_payload: Dictionary[StringName, Variant] = {}
	action_payload[LobbyProtocol.KEY_HIT_INDEX] = 0
	action_payload[LobbyProtocol.KEY_ELAPSED_MS] = 100
	_expect(
		LobbyProtocol.validate_action_envelope(
			LobbyProtocol.TARGET_HIT_ACTION,
			action_payload
		) == OK,
		"Small logical action payload should be valid."
	)
	_expect(
		LobbyProtocol.validate_action_envelope(&"", action_payload) != OK,
		"Empty action ID should be rejected."
	)


func _test_session_player_round_trip() -> void:
	var source: SessionPlayer = SessionPlayer.new(7, "七号", false, true)
	var parsed: SessionPlayer = SessionPlayer.from_payload(source.to_payload())
	_expect(parsed != null, "Valid player payload should parse.")
	if parsed != null:
		_expect(parsed.peer_id == 7, "Peer ID should survive payload round-trip.")
		_expect(parsed.display_name == "七号", "Display name should survive payload round-trip.")
		_expect(parsed.is_ready, "Ready state should survive payload round-trip.")


func _test_result_round_trip_and_order() -> void:
	var completed: MinigamePlayerResult = MinigamePlayerResult.new(
		2,
		"完成者",
		10,
		1200,
		true
	)
	var parsed: MinigamePlayerResult = MinigamePlayerResult.from_payload(
		completed.to_payload()
	)
	_expect(parsed != null, "Valid result payload should parse.")
	if parsed != null:
		_expect(parsed.elapsed_ms == 1200, "Result elapsed time should round-trip.")

	var results: Array[MinigamePlayerResult] = [
		MinigamePlayerResult.new(8, "退出者", 9, 900, false, true),
		MinigamePlayerResult.new(5, "未完成", 7, 800),
		MinigamePlayerResult.new(4, "较慢完成", 10, 1500, true),
		completed,
		MinigamePlayerResult.new(3, "同分较慢", 7, 900),
	]
	results.sort_custom(Callable(MinigamePlayerResult, "is_before"))
	_expect(results[0].peer_id == 2, "Fastest completed player should rank first.")
	_expect(results[1].peer_id == 4, "Slower completed player should rank second.")
	_expect(results[2].peer_id == 5, "Incomplete ties should use lower elapsed time.")
	_expect(results[4].peer_id == 8, "Withdrawn player should rank after active players.")


func _test_result_capacity_orders() -> void:
	var player_counts: Array[int] = [1, 2, 4, 8]
	for player_count: int in player_counts:
		var session: GameSessionState = GameSessionState.new()
		session.begin_session(1, true)
		var peer_id: int = 1
		while peer_id <= player_count:
			session.upsert_player(
				SessionPlayer.new(
					peer_id,
					"Player-%d" % peer_id,
					peer_id == 1,
					true
				)
			)
			peer_id += 1
		_expect(
			session.begin_round(1, LobbyProtocol.TARGET_CLICK_GAME_ID, 77) == OK,
			"A %d-player result set should initialize." % player_count
		)
		_expect(
			session.set_round_phase(GameSessionState.Phase.PLAYING) == OK,
			"A %d-player result set should enter PLAYING." % player_count
		)
		var progress: Array[MinigamePlayerResult] = session.get_sorted_results()
		for result: MinigamePlayerResult in progress:
			result.hit_count = 10
			result.elapsed_ms = (player_count - result.peer_id + 1) * 100
			result.is_complete = true
		_expect(
			session.set_round_results(progress) == OK,
			"A %d-player result set should update." % player_count
		)
		var ranked: Array[MinigamePlayerResult] = session.finalize_round_results()
		_expect(ranked.size() == player_count, "Final ranking should retain all players.")
		_expect(ranked[0].peer_id == player_count, "Fastest player should lead a %d-player ranking." % player_count)
		var rank_index: int = 0
		while rank_index < ranked.size():
			_expect(ranked[rank_index].rank == rank_index + 1, "Final ranks should be contiguous.")
			rank_index += 1
		session.free()


func _test_player_counts_sorting_and_readiness() -> void:
	var session: GameSessionState = GameSessionState.new()
	session.begin_session(LobbyProtocol.SERVER_PEER_ID, true)
	session.upsert_player(SessionPlayer.new(1, "房主", true, true))
	_expect(not session.can_host_start(), "One player should not be enough to start.")

	session.upsert_player(SessionPlayer.new(8, "客户端八", false, false))
	_expect(not session.can_host_start(), "An unready client should block start.")
	_expect(session.set_player_ready(8, true) == OK, "Known client should be able to become ready.")
	_expect(session.can_host_start(), "Two ready players should be enough to start.")

	var peer_id: int = 2
	while peer_id <= 7:
		session.upsert_player(SessionPlayer.new(peer_id, "玩家-%d" % peer_id, false, true))
		peer_id += 1
	_expect(session.players_by_peer.size() == 8, "Session should represent the full eight-player capacity.")
	_expect(session.can_host_start(), "Eight ready players should be able to start.")

	var sorted_players: Array[SessionPlayer] = session.get_sorted_players()
	_expect(sorted_players[0].peer_id == 1 and sorted_players[0].is_host, "Host should always sort first.")
	_expect(sorted_players[1].peer_id == 2 and sorted_players[7].peer_id == 8, "Clients should sort by peer ID.")
	session.free()


func _test_lifecycle_snapshots() -> void:
	var host_session: GameSessionState = GameSessionState.new()
	host_session.begin_session(1, true)
	host_session.upsert_player(SessionPlayer.new(1, "Host", true, true))
	host_session.upsert_player(SessionPlayer.new(4, "Client", false, true))
	_expect(
		host_session.begin_round(1, LobbyProtocol.TARGET_CLICK_GAME_ID, 12345) == OK,
		"Host should begin the first round."
	)

	var client_session: GameSessionState = GameSessionState.new()
	client_session.begin_session(4, false)
	_expect(
		client_session.replace_from_snapshot(host_session.create_snapshot()) == OK,
		"Loading snapshot should replace client state."
	)
	_expect(
		client_session.phase == GameSessionState.Phase.LOADING_GAME,
		"Client should enter loading phase."
	)
	_expect(client_session.round_id == 1, "Round ID should synchronize.")
	var invalid_phase_snapshot: Dictionary = host_session.create_snapshot()
	invalid_phase_snapshot[LobbyProtocol.KEY_PHASE] = GameSessionState.Phase.LOBBY
	_expect(
		client_session.replace_from_snapshot(invalid_phase_snapshot) != OK,
		"A lobby snapshot carrying active-round fields should be rejected."
	)

	_expect(
		host_session.set_round_phase(GameSessionState.Phase.PLAYING) == OK,
		"Host should enter playing phase."
	)
	var progress: Array[MinigamePlayerResult] = host_session.get_sorted_results()
	progress[0].hit_count = 10
	progress[0].elapsed_ms = 1000
	progress[0].is_complete = true
	progress[1].hit_count = 6
	progress[1].elapsed_ms = 800
	_expect(host_session.set_round_results(progress) == OK, "Progress should update.")
	_expect(
		client_session.replace_from_snapshot(host_session.create_snapshot()) == OK,
		"Playing progress should synchronize."
	)

	host_session.mark_player_withdrawn(4)
	var final_results: Array[MinigamePlayerResult] = host_session.finalize_round_results()
	_expect(final_results[0].peer_id == 1, "Completed host should rank first.")
	_expect(final_results[1].peer_id == 4, "Withdrawn client should rank last.")
	_expect(
		client_session.replace_from_snapshot(host_session.create_snapshot()) == OK,
		"Final results should synchronize."
	)
	_expect(
		client_session.phase == GameSessionState.Phase.RESULTS,
		"Client should enter results phase."
	)

	var stale_snapshot: Dictionary = host_session.create_snapshot()
	stale_snapshot[LobbyProtocol.KEY_ROUND_ID] = 0
	_expect(
		client_session.replace_from_snapshot(stale_snapshot) != OK,
		"Stale round snapshot should be rejected."
	)

	host_session.return_to_lobby()
	_expect(
		client_session.replace_from_snapshot(host_session.create_snapshot()) == OK,
		"Lobby return snapshot should synchronize."
	)
	_expect(client_session.round_id == 1, "Lobby return should retain last round ID.")
	_expect(
		not client_session.get_local_player().is_ready,
		"Returning to lobby should clear client readiness."
	)
	host_session.free()
	client_session.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
