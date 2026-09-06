## Focused pure-logic checks for playlist rules, ranking, scoring, and snapshots.
extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_protocol_and_result_round_trip()
	_test_playlist_rules_and_schedule()
	_test_competition_ranking_and_points()
	if _failures.is_empty():
		print("LOBBY_MODULE_TEST: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("LOBBY_MODULE_TEST: %s" % failure)
	quit(1)


func _test_protocol_and_result_round_trip() -> void:
	_expect(LobbyProtocol.PROTOCOL_VERSION == 3, "Protocol should be version 3.")
	var result: MinigamePlayerResult = MinigamePlayerResult.new(
		2,
		"玩家二",
		7,
		1200,
		true
	)
	var parsed: MinigamePlayerResult = MinigamePlayerResult.from_payload(
		result.to_payload()
	)
	_expect(parsed != null, "Result payload should parse.")
	if parsed != null:
		_expect(parsed.score == 7, "Generic score should round-trip.")
		_expect(parsed.elapsed_ms == 1200, "Elapsed time should round-trip.")


func _test_playlist_rules_and_schedule() -> void:
	var available: Array[StringName] = [
		LobbyProtocol.TARGET_CLICK_GAME_ID,
		LobbyProtocol.TARGET_RACE_GAME_ID,
	]
	var config: PartyPlaylistConfig = PartyPlaylistConfig.new()
	config.total_rounds = 5
	config.selected_game_ids = available.duplicate()
	config.order_mode = PartyPlaylistConfig.OrderMode.SEQUENTIAL
	var sequential: Array[StringName] = config.build_schedule(17)
	_expect(sequential.size() == 5, "Sequential schedule should contain every round.")
	_expect(
		sequential == [
			LobbyProtocol.TARGET_CLICK_GAME_ID,
			LobbyProtocol.TARGET_RACE_GAME_ID,
			LobbyProtocol.TARGET_CLICK_GAME_ID,
			LobbyProtocol.TARGET_RACE_GAME_ID,
			LobbyProtocol.TARGET_CLICK_GAME_ID,
		],
		"Sequential schedule should cycle through selected games."
	)
	config.order_mode = PartyPlaylistConfig.OrderMode.RANDOM
	var random_schedule: Array[StringName] = config.build_schedule(42)
	for index: int in range(1, random_schedule.size()):
		_expect(
			random_schedule[index] != random_schedule[index - 1],
			"Random no-consecutive schedule should not repeat adjacent games."
		)
	config.total_rounds = 2
	config.repeat_policy = PartyPlaylistConfig.RepeatPolicy.ONCE_ONLY
	var once_schedule: Array[StringName] = config.build_schedule(99)
	_expect(
		once_schedule.size() == 2 and once_schedule[0] != once_schedule[1],
		"Once-only schedule should use each selected game at most once."
	)
	config.total_rounds = 5
	config.normalize()
	_expect(
		config.repeat_policy == PartyPlaylistConfig.RepeatPolicy.NO_CONSECUTIVE,
		"Impossible once-only rules should automatically switch repeat policy."
	)
	config.selected_game_ids = [LobbyProtocol.TARGET_CLICK_GAME_ID]
	_expect(
		config.validate_for_start(available) != OK,
		"One selected game cannot start multiple no-consecutive rounds."
	)


func _test_competition_ranking_and_points() -> void:
	var host_session: GameSessionState = GameSessionState.new()
	host_session.begin_session(1, true)
	for peer_id: int in range(1, 5):
		host_session.upsert_player(
			SessionPlayer.new(
				peer_id,
				"Player-%d" % peer_id,
				peer_id == 1,
				true
			)
		)
	var config: PartyPlaylistConfig = PartyPlaylistConfig.new()
	config.total_rounds = 2
	config.order_mode = PartyPlaylistConfig.OrderMode.SEQUENTIAL
	config.selected_game_ids = [
		LobbyProtocol.TARGET_RACE_GAME_ID,
		LobbyProtocol.TARGET_CLICK_GAME_ID,
	]
	host_session.set_playlist_config(config)
	host_session.begin_playlist(config.build_schedule(5))
	host_session.begin_next_round(77)
	host_session.set_round_phase(GameSessionState.Phase.PLAYING)
	var scores: Array[int] = [10, 7, 7, 3]
	var results: Array[MinigamePlayerResult] = host_session.get_sorted_results()
	for index: int in range(results.size()):
		results[index].score = scores[index]
	host_session.set_round_results(results)
	_expect(
		host_session.finalize_round_results(
			MinigameDefinition.RankingMode.COMPETITION_SCORE
		) == OK,
		"Competition results should finalize."
	)
	var ranked: Array[MinigamePlayerResult] = host_session.get_ranked_results_for_display()
	_expect(
		[
			ranked[0].rank,
			ranked[1].rank,
			ranked[2].rank,
			ranked[3].rank,
		] == [1, 2, 2, 4],
		"Competition ranking should produce 1, 2, 2, 4."
	)
	var standings: Array[PartyStanding] = host_session.get_sorted_standings()
	_expect(
		[
			standings[0].points,
			standings[1].points,
			standings[2].points,
			standings[3].points,
		] == [3, 2, 2, 0],
		"Tied second place should award 2 points to both and consume third place."
	)
	var client_session: GameSessionState = GameSessionState.new()
	client_session.begin_session(2, false)
	_expect(
		client_session.replace_from_snapshot(host_session.create_snapshot()) == OK,
		"Intermission playlist snapshot should replace client state."
	)
	_expect(
		client_session.phase == GameSessionState.Phase.INTERMISSION,
		"Client should enter intermission."
	)
	host_session.begin_next_round(88)
	host_session.set_round_phase(GameSessionState.Phase.PLAYING)
	var second_results: Array[MinigamePlayerResult] = host_session.get_sorted_results()
	for result: MinigamePlayerResult in second_results:
		result.score = 10
		result.elapsed_ms = result.peer_id * 100
		result.is_complete = true
	host_session.set_round_results(second_results)
	host_session.finalize_round_results(MinigameDefinition.RankingMode.STRICT_ORDER)
	_expect(
		host_session.phase == GameSessionState.Phase.SESSION_RESULTS,
		"Last round should enter session results."
	)
	host_session.free()
	client_session.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
