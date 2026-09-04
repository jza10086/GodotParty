## Focused pure-logic checks for the completed lobby module.
extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_display_names_and_ports()
	_test_registration_payloads()
	_test_session_player_round_trip()
	_test_player_counts_sorting_and_readiness()
	_test_snapshot_replacement()

	if _failures.is_empty():
		print("LOBBY_MODULE_TEST: PASS")
		quit(0)
		return

	var index: int = 0
	while index < _failures.size():
		push_error("LOBBY_MODULE_TEST: %s" % _failures[index])
		index += 1
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


func _test_registration_payloads() -> void:
	var payload: Dictionary[StringName, Variant] = LobbyProtocol.make_registration_payload("  Alice  ")
	_expect(LobbyProtocol.validate_registration_payload(payload) == OK, "Generated registration should be valid.")
	_expect(String(payload[LobbyProtocol.KEY_DISPLAY_NAME]) == "Alice", "Generated registration should normalize nickname.")

	var wrong_version: Dictionary = payload.duplicate(true)
	wrong_version[LobbyProtocol.KEY_PROTOCOL_VERSION] = LobbyProtocol.PROTOCOL_VERSION + 1
	_expect(LobbyProtocol.validate_registration_payload(wrong_version) == ERR_UNAVAILABLE, "Wrong protocol version should be rejected distinctly.")

	var padded_name: Dictionary = payload.duplicate(true)
	padded_name[LobbyProtocol.KEY_DISPLAY_NAME] = " Alice "
	_expect(LobbyProtocol.validate_registration_payload(padded_name) != OK, "Unnormalized network nickname should be rejected.")


func _test_session_player_round_trip() -> void:
	var source: SessionPlayer = SessionPlayer.new(7, "七号", false, true)
	var parsed: SessionPlayer = SessionPlayer.from_payload(source.to_payload())
	_expect(parsed != null, "Valid player payload should parse.")
	if parsed != null:
		_expect(parsed.peer_id == 7, "Peer ID should survive payload round-trip.")
		_expect(parsed.display_name == "七号", "Display name should survive payload round-trip.")
		_expect(parsed.is_ready, "Ready state should survive payload round-trip.")


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
		if session.players_by_peer.size() == 4:
			_expect(session.can_host_start(), "Four ready players should be able to start.")
		peer_id += 1
	_expect(session.players_by_peer.size() == 8, "Session should represent the full eight-player capacity.")
	_expect(session.can_host_start(), "Eight ready players should be able to start.")

	var sorted_players: Array[SessionPlayer] = session.get_sorted_players()
	_expect(sorted_players[0].peer_id == 1 and sorted_players[0].is_host, "Host should always sort first.")
	_expect(sorted_players[1].peer_id == 2 and sorted_players[7].peer_id == 8, "Clients should sort by peer ID.")

	session.remove_player(5)
	_expect(session.players_by_peer.size() == 7, "Disconnected player should be removed.")
	_expect(session.can_host_start(), "Remaining ready players should still satisfy start conditions.")
	session.free()


func _test_snapshot_replacement() -> void:
	var host_session: GameSessionState = GameSessionState.new()
	host_session.begin_session(1, true)
	host_session.upsert_player(SessionPlayer.new(1, "Host", true, true))
	host_session.upsert_player(SessionPlayer.new(4, "Client", false, true))
	var game_snapshot: Dictionary[StringName, Variant] = host_session.create_game_snapshot("placeholder", 12345)

	var client_session: GameSessionState = GameSessionState.new()
	client_session.begin_session(4, false)
	_expect(client_session.replace_from_snapshot(game_snapshot) == OK, "Valid authoritative game snapshot should replace client state.")
	_expect(client_session.phase == GameSessionState.Phase.PLACEHOLDER_GAME, "Game snapshot should advance the phase.")
	_expect(client_session.random_seed == 12345, "Game snapshot should preserve the random seed.")
	_expect(client_session.players_by_peer.size() == 2, "Game snapshot should preserve all players.")

	var wrong_version: Dictionary = game_snapshot.duplicate(true)
	wrong_version[LobbyProtocol.KEY_PROTOCOL_VERSION] = 999
	_expect(client_session.replace_from_snapshot(wrong_version) == ERR_UNAVAILABLE, "Snapshot protocol mismatch should be rejected.")

	var missing_local: Dictionary = game_snapshot.duplicate(true)
	missing_local[LobbyProtocol.KEY_PLAYERS] = [SessionPlayer.new(1, "Host", true, true).to_payload()]
	_expect(client_session.replace_from_snapshot(missing_local) != OK, "Snapshot missing the local peer should be rejected.")
	host_session.free()
	client_session.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
