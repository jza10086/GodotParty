## Two-process ENet smoke test used to validate the real RPC lobby/start path.
extends SceneTree

const TEST_PORT: int = 17000
const TIMEOUT_SECONDS: float = 30.0

var _role: String = ""
var _finishing: bool = false
var _session: GameSessionState = null
var _network_manager: NetworkManagerService = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_session = GameSessionState.new()
	_session.name = "GameSession"
	root.add_child(_session)
	_network_manager = NetworkManagerService.new()
	_network_manager.name = "NetworkManager"
	_network_manager.game_session = _session
	root.add_child(_network_manager)
	_role = _read_role()
	_network_manager.connection_failed.connect(_on_failure)
	_network_manager.session_left.connect(_on_session_left)
	_network_manager.game_started.connect(_on_game_started)
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
	if _session.can_host_start():
		_network_manager.request_start_game()


func _on_game_started() -> void:
	if _session.current_game_id != LobbyProtocol.PLACEHOLDER_GAME_ID:
		_fail("unexpected game ID")
		return
	if _session.random_seed <= 0:
		_fail("random seed was not synchronized")
		return
	if _session.players_by_peer.size() != 2:
		_fail("player snapshot does not contain both peers")
		return
	_finishing = true
	print("NETWORK_LOBBY_SMOKE_%s: PASS" % _role.to_upper())
	if _role == "host":
		var close_delay: SceneTreeTimer = create_timer(0.5)
		close_delay.timeout.connect(_finish_success)
	else:
		_finish_success()


func _finish_success() -> void:
	_network_manager.leave_session()
	quit(0)


func _on_failure(reason: String) -> void:
	_fail(reason)


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
	push_error("NETWORK_LOBBY_SMOKE_%s: %s" % [_role.to_upper(), reason])
	if _network_manager != null:
		_network_manager.leave_session()
	quit(1)
