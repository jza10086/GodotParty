## Two-process ENet smoke for playlist, realtime transport, pause/manual advance, and final results.
extends SceneTree

const TEST_PORT: int = 17000
const TIMEOUT_SECONDS: float = 30.0

var _role: String = ""
var _finishing: bool = false
var _start_requested: bool = false
var _session: GameSessionState = null
var _network: NetworkManagerService = null
var _definitions: Array[MinigameDefinition] = []
var _completed_rounds: int = 0
var _saw_realtime_state: bool = false
var _saw_paused_intermission: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_role = _read_role()
	if _role != "host" and _role != "client":
		_fail("missing --role=host or --role=client")
		return
	_session = GameSessionState.new()
	root.add_child(_session)
	_network = NetworkManagerService.new()
	_network.game_session = _session
	root.add_child(_network)
	for path: String in [
		"res://game/minigames/target_race/target_race_definition.tres",
		"res://game/minigames/target_click/target_click_definition.tres",
	]:
		var source: MinigameDefinition = load(path) as MinigameDefinition
		if source == null:
			_fail("definition did not load: %s" % path)
			return
		var definition: MinigameDefinition = source.duplicate(true) as MinigameDefinition
		definition.countdown_seconds = 0.05
		definition.load_timeout_seconds = 2.0
		_definitions.append(definition)
	if _network.register_minigames(_definitions) != OK:
		_fail("definition registration failed")
		return
	_network.connection_failed.connect(_fail)
	_network.session_left.connect(_on_session_left)
	_network.round_cancelled.connect(_fail)
	_network.round_loading_started.connect(_on_round_loading_started)
	_network.round_play_started.connect(_on_round_play_started)
	_network.intermission_started.connect(_on_intermission_started)
	_network.intermission_pause_changed.connect(_on_intermission_pause_changed)
	_network.session_results_ready.connect(_on_session_results_ready)
	_network.minigame_realtime_state_received.connect(_on_realtime_state)
	_network.lobby_returned.connect(_on_lobby_returned)
	create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)
	if _role == "host":
		_session.players_changed.connect(_on_host_players_changed)
		var host_error: Error = _network.host_session("SmokeHost", TEST_PORT)
		if host_error != OK:
			_fail("host_session failed: %s" % error_string(host_error))
	else:
		_network.lobby_joined.connect(_on_client_lobby_joined)
		var join_error: Error = _network.join_session(
			"SmokeClient",
			LobbyProtocol.DEFAULT_ADDRESS,
			TEST_PORT
		)
		if join_error != OK:
			_fail("join_session failed: %s" % error_string(join_error))


func _read_role() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			return argument.trim_prefix("--role=")
	return ""


func _on_client_lobby_joined() -> void:
	_network.set_local_ready(true)


func _on_host_players_changed(_players: Array[SessionPlayer]) -> void:
	if _start_requested or not _session.can_host_start():
		return
	_start_requested = true
	var config: PartyPlaylistConfig = PartyPlaylistConfig.new()
	config.total_rounds = 2
	config.intermission_seconds = 2
	config.order_mode = PartyPlaylistConfig.OrderMode.SEQUENTIAL
	config.repeat_policy = PartyPlaylistConfig.RepeatPolicy.NO_CONSECUTIVE
	config.selected_game_ids = [
		LobbyProtocol.TARGET_RACE_GAME_ID,
		LobbyProtocol.TARGET_CLICK_GAME_ID,
	]
	if _network.update_playlist_config(config) != OK:
		_fail("playlist configuration failed")
		return
	_network.request_start_playlist()


func _on_round_loading_started(
		round_id: int,
		game_id: StringName,
		_random_seed: int
) -> void:
	var expected_id: StringName = (
		LobbyProtocol.TARGET_RACE_GAME_ID
		if _completed_rounds == 0
		else LobbyProtocol.TARGET_CLICK_GAME_ID
	)
	if game_id != expected_id:
		_fail("unexpected game order")
		return
	await process_frame
	_network.report_local_game_loaded(round_id, game_id, true, "")


func _on_round_play_started(round_id: int) -> void:
	if _role != "host":
		return
	if _session.current_game_id == LobbyProtocol.TARGET_RACE_GAME_ID:
		var state: Dictionary[StringName, Variant] = {}
		state[&"server_tick"] = 1
		state[&"positions"] = {1: Vector2(100.0, 100.0), 2: Vector2(200.0, 100.0)}
		state[&"acknowledged_inputs"] = {1: 1, 2: 1}
		state[&"target_position"] = Vector2(400.0, 300.0)
		state[&"scores"] = {1: 1, 2: 0}
		_network.publish_minigame_realtime_state(round_id, 1, state)
		await create_timer(0.15).timeout
	var results: Array[MinigamePlayerResult] = _session.get_sorted_results()
	for result: MinigamePlayerResult in results:
		if _session.current_game_id == LobbyProtocol.TARGET_RACE_GAME_ID:
			result.score = 1 if result.peer_id == 1 else 0
		else:
			result.score = 10
			result.elapsed_ms = 100 if result.peer_id == 1 else 200
			result.is_complete = true
	_network.publish_minigame_progress(round_id, results, true)


func _on_realtime_state(
		_round_id: int,
		_state_sequence: int,
		payload: Dictionary
) -> void:
	if payload.has(&"target_position"):
		_saw_realtime_state = true


func _on_intermission_started(
		_round_id: int,
		_duration_seconds: float,
		next_game_id: StringName
) -> void:
	_completed_rounds = 1
	if next_game_id != LobbyProtocol.TARGET_CLICK_GAME_ID:
		_fail("intermission should name the next game")
		return
	if _role == "host":
		_network.pause_intermission_auto_advance()
		await create_timer(0.2).timeout
		if not _session.intermission_paused:
			_fail("host pause did not persist")
			return
		_network.request_next_round()


func _on_intermission_pause_changed(_round_id: int, paused: bool) -> void:
	if paused:
		_saw_paused_intermission = true


func _on_session_results_ready(standings: Array[PartyStanding]) -> void:
	_completed_rounds = 2
	if standings.size() != 2:
		_fail("final standings should contain two players")
		return
	if not _saw_paused_intermission:
		_fail("paused intermission was not synchronized")
		return
	if _role == "client" and not _saw_realtime_state:
		_fail("client did not receive realtime state")
		return
	if _role == "host":
		await create_timer(0.15).timeout
		_network.request_return_to_lobby()


func _on_lobby_returned() -> void:
	if _completed_rounds != 2:
		_fail("returned before the playlist completed")
		return
	var local_player: SessionPlayer = _session.get_local_player()
	if local_player == null:
		_fail("local player missing after lobby return")
		return
	if not local_player.is_host and local_player.is_ready:
		_fail("client readiness was not cleared")
		return
	_finishing = true
	print("NETWORK_PLAYLIST_SMOKE_%s: PASS" % _role.to_upper())
	if _role == "host":
		await create_timer(0.4).timeout
	_network.leave_session()
	quit(0)


func _on_session_left(reason: String) -> void:
	if not _finishing:
		_fail(reason)


func _on_timeout() -> void:
	if not _finishing:
		_fail("timed out")


func _fail(reason: String) -> void:
	if _finishing:
		return
	_finishing = true
	push_error("NETWORK_PLAYLIST_SMOKE_%s: %s" % [_role.to_upper(), reason])
	if _network != null:
		_network.leave_session()
	quit(1)
