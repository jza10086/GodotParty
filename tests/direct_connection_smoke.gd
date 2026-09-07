## Two-process ENet connection smoke for configurable IPv4 and IPv6 binds.
extends SceneTree

const TIMEOUT_SECONDS: float = 20.0

var _role: String = ""
var _bind_address: String = LobbyProtocol.DEFAULT_BIND_ADDRESS
var _join_address: String = LobbyProtocol.DEFAULT_ADDRESS
var _port: int = 17100
var _finishing: bool = false
var _session: GameSessionState = null
var _network: NetworkManagerService = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_read_arguments()
	if _role != "host" and _role != "client":
		_fail("missing --role=host or --role=client")
		return
	_session = GameSessionState.new()
	root.add_child(_session)
	_network = NetworkManagerService.new()
	_network.game_session = _session
	root.add_child(_network)
	var definition: MinigameDefinition = load(
		"res://game/minigames/target_click/target_click_definition.tres"
	) as MinigameDefinition
	if definition == null:
		_fail("target click definition did not load")
		return
	var definitions: Array[MinigameDefinition] = [definition]
	if _network.register_minigames(definitions) != OK:
		_fail("definition registration failed")
		return
	_network.connection_failed.connect(_fail)
	create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)
	if _role == "host":
		_session.players_changed.connect(_on_host_players_changed)
		var host_error: Error = _network.host_session(
			"DirectHost",
			_port,
			_bind_address
		)
		if host_error != OK:
			_fail("host_session failed: %s" % error_string(host_error))
	else:
		_network.lobby_joined.connect(_on_client_lobby_joined)
		var join_error: Error = _network.join_session(
			"DirectClient",
			_join_address,
			_port
		)
		if join_error != OK:
			_fail("join_session failed: %s" % error_string(join_error))


func _read_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.trim_prefix("--role=")
		elif argument.begins_with("--bind="):
			_bind_address = argument.trim_prefix("--bind=")
		elif argument.begins_with("--address="):
			_join_address = argument.trim_prefix("--address=")
		elif argument.begins_with("--port="):
			_port = int(argument.trim_prefix("--port="))


func _on_host_players_changed(players: Array[SessionPlayer]) -> void:
	if players.size() < 2 or _finishing:
		return
	_finishing = true
	print(
		"DIRECT_CONNECTION_SMOKE_HOST: PASS %s"
		% LobbyProtocol.format_endpoint(_bind_address, _port)
	)
	await create_timer(0.5).timeout
	_network.leave_session()
	quit(0)


func _on_client_lobby_joined() -> void:
	if _finishing:
		return
	_finishing = true
	print(
		"DIRECT_CONNECTION_SMOKE_CLIENT: PASS %s"
		% LobbyProtocol.format_endpoint(_join_address, _port)
	)
	await create_timer(0.2).timeout
	_network.leave_session()
	quit(0)


func _on_timeout() -> void:
	if not _finishing:
		_fail("timed out")


func _fail(reason: String) -> void:
	if _finishing:
		return
	_finishing = true
	push_error("DIRECT_CONNECTION_SMOKE_%s: %s" % [_role.to_upper(), reason])
	if _network != null:
		_network.leave_session()
	quit(1)
