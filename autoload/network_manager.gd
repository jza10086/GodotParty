## Owns the ENet peer, connection lifecycle, and all authoritative session RPCs.
class_name NetworkManagerService
extends Node

signal connection_state_changed(state: int)
signal connection_failed(reason: String)
signal connection_cancelled(reason: String)
signal public_addresses_changed()
signal lobby_joined()
signal session_left(reason: String)
signal round_loading_started(round_id: int, game_id: StringName, random_seed: int)
signal round_countdown_started(round_id: int, duration_seconds: float)
signal round_play_started(round_id: int)
signal round_progress_changed(round_id: int, results: Array[MinigamePlayerResult])
signal round_results_ready(round_id: int, results: Array[MinigamePlayerResult])
signal round_cancelled(reason: String)
signal lobby_returned()
signal intermission_started(round_id: int, duration_seconds: float, next_game_id: StringName)
signal intermission_pause_changed(round_id: int, paused: bool)
signal session_results_ready(standings: Array[PartyStanding])
signal minigame_action_received(
	peer_id: int,
	round_id: int,
	action_id: StringName,
	payload: Dictionary
)
signal minigame_realtime_input_received(
	peer_id: int,
	round_id: int,
	sequence: int,
	payload: Dictionary
)
signal minigame_realtime_state_received(
	round_id: int,
	state_sequence: int,
	payload: Dictionary
)
signal round_time_expired(round_id: int)

enum ConnectionState {
	OFFLINE,
	STARTING_HOST,
	HOSTING,
	CONNECTING,
	CONNECTED,
}

const CONNECTION_TIMEOUT_SECONDS: float = 10.0
const PUBLIC_ADDRESS_TIMEOUT_SECONDS: float = 6.0
const PUBLIC_IPV4_URL: String = "https://api.ipify.org"
const PUBLIC_IPV6_URL: String = "https://api6.ipify.org"

var connection_state: int = ConnectionState.OFFLINE
var last_status_message: String = ""
var current_bind_address: String = LobbyProtocol.DEFAULT_BIND_ADDRESS
var current_port: int = 0
var current_remote_address: String = ""
var public_ipv4_address: String = ""
var public_ipv6_address: String = ""
var public_ipv4_query_finished: bool = false
var public_ipv6_query_finished: bool = false
var game_session: GameSessionState = null

var _peer: ENetMultiplayerPeer = null
var _local_display_name: String = ""
var _has_joined_lobby: bool = false
var _definitions_by_id: Dictionary[StringName, MinigameDefinition] = {}
var _definition_order: Array[StringName] = []
var _loaded_peer_ids: Dictionary[int, bool] = {}
var _last_applied_phase: int = GameSessionState.Phase.OFFLINE
var _last_applied_round_id: int = 0
var _last_intermission_paused: bool = false
var _connection_attempt_id: int = 0
var _public_ipv4_request: HTTPRequest = null
var _public_ipv6_request: HTTPRequest = null


func _ready() -> void:
	if game_session == null:
		game_session = get_node_or_null("/root/GameSession") as GameSessionState
	assert(game_session != null, "NetworkManager requires the GameSession Autoload.")
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_setup_public_address_requests()


func register_minigames(definitions: Array[MinigameDefinition]) -> Error:
	var replacement: Dictionary[StringName, MinigameDefinition] = {}
	var order: Array[StringName] = []
	for definition: MinigameDefinition in definitions:
		if definition == null or definition.validate() != OK:
			return ERR_INVALID_DATA
		if replacement.has(definition.game_id):
			return ERR_ALREADY_EXISTS
		replacement[definition.game_id] = definition
		order.append(definition.game_id)
	if replacement.is_empty():
		return ERR_DOES_NOT_EXIST
	_definitions_by_id = replacement
	_definition_order = order
	return OK


func get_minigame_definition(game_id: StringName) -> MinigameDefinition:
	return _definitions_by_id.get(game_id) as MinigameDefinition


func get_minigame_definitions() -> Array[MinigameDefinition]:
	var definitions: Array[MinigameDefinition] = []
	for game_id: StringName in _definition_order:
		var definition: MinigameDefinition = get_minigame_definition(game_id)
		if definition != null:
			definitions.append(definition)
	return definitions


## Starts a host-authoritative ENet lobby. The server occupies peer slot 1.
func host_session(
		display_name: String,
		port: int,
		bind_address: String = LobbyProtocol.DEFAULT_BIND_ADDRESS
) -> Error:
	if connection_state != ConnectionState.OFFLINE:
		return ERR_ALREADY_IN_USE
	last_status_message = ""
	var normalized_name: String = SessionPlayer.normalize_display_name(display_name)
	var normalized_bind: String = LobbyProtocol.normalize_connection_address(bind_address)
	var validation_error: Error = SessionPlayer.validate_display_name(normalized_name)
	if validation_error != OK:
		return validation_error
	validation_error = LobbyProtocol.validate_port(port)
	if validation_error != OK:
		return validation_error
	validation_error = LobbyProtocol.validate_bind_address(normalized_bind)
	if validation_error != OK:
		last_status_message = "监听地址格式或 IPv6 范围不受支持。"
		return validation_error
	if not _is_available_local_bind(normalized_bind):
		last_status_message = "指定监听地址不属于本机当前可用网卡。"
		return ERR_DOES_NOT_EXIST

	var next_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	next_peer.set_bind_ip(normalized_bind)
	_set_connection_state(ConnectionState.STARTING_HOST)
	var create_error: Error = next_peer.create_server(
		port,
		LobbyProtocol.MAX_REMOTE_CLIENTS
	)
	if create_error != OK:
		last_status_message = "无法创建大厅：UDP 端口可能已被占用，或监听地址无法绑定。"
		_reset_connection()
		return create_error
	_peer = next_peer
	multiplayer.multiplayer_peer = _peer
	_local_display_name = normalized_name
	_has_joined_lobby = true
	current_bind_address = normalized_bind
	current_port = port
	current_remote_address = ""
	game_session.begin_session(LobbyProtocol.SERVER_PEER_ID, true)
	game_session.upsert_player(
		SessionPlayer.new(LobbyProtocol.SERVER_PEER_ID, normalized_name, true, true)
	)
	var default_config: PartyPlaylistConfig = PartyPlaylistConfig.new()
	default_config.selected_game_ids = _definition_order.duplicate()
	game_session.set_playlist_config(default_config)
	_last_applied_phase = GameSessionState.Phase.LOBBY
	_last_applied_round_id = 0
	last_status_message = (
		"大厅已创建。ENet 使用 UDP；首次运行时请允许 Windows 私有网络访问。"
	)
	_set_connection_state(ConnectionState.HOSTING)
	lobby_joined.emit()
	return OK


## Connects to an ENet host and submits local identity after the handshake succeeds.
func join_session(display_name: String, address: String, port: int) -> Error:
	if connection_state != ConnectionState.OFFLINE:
		return ERR_ALREADY_IN_USE
	last_status_message = ""
	var normalized_name: String = SessionPlayer.normalize_display_name(display_name)
	var normalized_address: String = LobbyProtocol.normalize_connection_address(
		address
	)
	var validation_error: Error = SessionPlayer.validate_display_name(normalized_name)
	if validation_error != OK:
		return validation_error
	validation_error = LobbyProtocol.validate_address(normalized_address)
	if validation_error != OK:
		last_status_message = "地址格式或 IPv6 范围不受支持。"
		return validation_error
	validation_error = LobbyProtocol.validate_port(port)
	if validation_error != OK:
		return validation_error
	var next_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var create_error: Error = next_peer.create_client(normalized_address, port)
	if create_error != OK:
		last_status_message = "无法创建连接，请检查地址与端口。"
		return create_error
	_peer = next_peer
	multiplayer.multiplayer_peer = _peer
	_local_display_name = normalized_name
	_has_joined_lobby = false
	current_bind_address = LobbyProtocol.DEFAULT_BIND_ADDRESS
	current_port = port
	current_remote_address = normalized_address
	last_status_message = "正在连接 %s……" % LobbyProtocol.format_endpoint(
		normalized_address,
		port
	)
	_connection_attempt_id += 1
	var attempt_id: int = _connection_attempt_id
	_set_connection_state(ConnectionState.CONNECTING)
	get_tree().create_timer(CONNECTION_TIMEOUT_SECONDS).timeout.connect(
		_on_connection_timeout.bind(attempt_id)
	)
	return OK


func cancel_connection() -> void:
	if connection_state != ConnectionState.CONNECTING:
		return
	_reset_connection()
	last_status_message = "已取消连接。"
	connection_cancelled.emit(last_status_message)


## Returns supported local interface addresses for display and exact binding.
func get_local_connection_addresses() -> Array[LocalNetworkAddress]:
	var result: Array[LocalNetworkAddress] = []
	var seen_addresses: Dictionary[String, bool] = {}
	for interface_data: Dictionary in IP.get_local_interfaces():
		var interface_name: String = String(interface_data.get("name", ""))
		var friendly_name: String = String(interface_data.get("friendly", ""))
		var raw_addresses: Variant = interface_data.get("addresses", [])
		for raw_address: Variant in raw_addresses:
			var address: String = LobbyProtocol.normalize_connection_address(
				String(raw_address)
			)
			if seen_addresses.has(address):
				continue
			var ip_type: int = IP.TYPE_NONE
			var is_loopback: bool = false
			if LobbyProtocol.is_supported_ipv6_address(address):
				ip_type = IP.TYPE_IPV6
				is_loopback = address.to_lower() == "::1"
			elif LobbyProtocol.is_supported_ipv4_address(address):
				ip_type = IP.TYPE_IPV4
				is_loopback = address.begins_with("127.")
			else:
				continue
			seen_addresses[address] = true
			result.append(
				LocalNetworkAddress.new(
					interface_name,
					friendly_name,
					address,
					ip_type,
					is_loopback
				)
			)
	result.sort_custom(_sort_local_addresses)
	return result


## Queries externally observed IPv4 and IPv6 addresses without affecting ENet.
func refresh_public_addresses() -> void:
	public_ipv4_address = ""
	public_ipv6_address = ""
	public_ipv4_query_finished = false
	public_ipv6_query_finished = false
	public_addresses_changed.emit()
	_public_ipv4_request.cancel_request()
	_public_ipv6_request.cancel_request()
	var ipv4_error: Error = _public_ipv4_request.request(PUBLIC_IPV4_URL)
	if ipv4_error != OK:
		public_ipv4_query_finished = true
	var ipv6_error: Error = _public_ipv6_request.request(PUBLIC_IPV6_URL)
	if ipv6_error != OK:
		public_ipv6_query_finished = true
	if ipv4_error != OK or ipv6_error != OK:
		public_addresses_changed.emit()


func _setup_public_address_requests() -> void:
	_public_ipv4_request = HTTPRequest.new()
	_public_ipv4_request.name = "PublicIpv4Request"
	_public_ipv4_request.timeout = PUBLIC_ADDRESS_TIMEOUT_SECONDS
	_public_ipv4_request.body_size_limit = 128
	add_child(_public_ipv4_request)
	_public_ipv4_request.request_completed.connect(
		_on_public_ipv4_request_completed
	)

	_public_ipv6_request = HTTPRequest.new()
	_public_ipv6_request.name = "PublicIpv6Request"
	_public_ipv6_request.timeout = PUBLIC_ADDRESS_TIMEOUT_SECONDS
	_public_ipv6_request.body_size_limit = 128
	add_child(_public_ipv6_request)
	_public_ipv6_request.request_completed.connect(
		_on_public_ipv6_request_completed
	)


func _on_public_ipv4_request_completed(
		result: int,
		response_code: int,
		_headers: PackedStringArray,
		body: PackedByteArray
) -> void:
	var address: String = _parse_public_address(result, response_code, body)
	if LobbyProtocol.is_public_ipv4_address(address):
		public_ipv4_address = address
	public_ipv4_query_finished = true
	public_addresses_changed.emit()


func _on_public_ipv6_request_completed(
		result: int,
		response_code: int,
		_headers: PackedStringArray,
		body: PackedByteArray
) -> void:
	var address: String = _parse_public_address(result, response_code, body)
	if LobbyProtocol.is_public_ipv6_address(address):
		public_ipv6_address = address
	public_ipv6_query_finished = true
	public_addresses_changed.emit()


static func _parse_public_address(
		result: int,
		response_code: int,
		body: PackedByteArray
) -> String:
	if (
		result != HTTPRequest.RESULT_SUCCESS
		or response_code != 200
		or body.size() > 128
	):
		return ""
	var address: String = body.get_string_from_utf8().strip_edges()
	return address if address.is_valid_ip_address() else ""


func leave_session() -> void:
	if connection_state == ConnectionState.OFFLINE:
		game_session.reset_session()
		return
	_reset_connection()
	last_status_message = "已离开会话。"
	session_left.emit(last_status_message)


func set_local_ready(is_ready: bool) -> void:
	if connection_state != ConnectionState.CONNECTED or game_session.local_is_host:
		return
	_request_ready.rpc_id(LobbyProtocol.SERVER_PEER_ID, is_ready)


func update_playlist_config(config: PartyPlaylistConfig) -> Error:
	if connection_state != ConnectionState.HOSTING or game_session.phase != GameSessionState.Phase.LOBBY:
		return ERR_UNAUTHORIZED
	if config == null:
		return ERR_INVALID_PARAMETER
	var normalized: PartyPlaylistConfig = config.duplicate_config()
	normalized.normalize()
	var validation_error: Error = normalized.validate(_definition_order)
	if validation_error != OK:
		return validation_error
	game_session.set_playlist_config(normalized)
	_broadcast_snapshot()
	return OK


func request_start_playlist() -> void:
	if connection_state != ConnectionState.HOSTING or not game_session.can_host_start():
		return
	var config_error: Error = game_session.playlist_config.validate_for_start(_definition_order)
	if config_error != OK:
		push_warning("Cannot start invalid playlist configuration.")
		return
	var schedule_seed: int = randi_range(1, 2147483647)
	var schedule: Array[StringName] = game_session.playlist_config.build_schedule(schedule_seed)
	if game_session.begin_playlist(schedule) != OK:
		push_warning("Could not initialize playlist.")
		return
	if _peer != null:
		_peer.refuse_new_connections = true
	_start_next_playlist_round()


## Compatibility helper for focused single-game tests.
func request_start_game(game_id: StringName = LobbyProtocol.TARGET_CLICK_GAME_ID) -> void:
	if connection_state != ConnectionState.HOSTING or not _definitions_by_id.has(game_id):
		return
	var config: PartyPlaylistConfig = PartyPlaylistConfig.new()
	config.total_rounds = 1
	config.selected_game_ids = [game_id]
	if update_playlist_config(config) == OK:
		request_start_playlist()


func report_local_game_loaded(
		report_round_id: int,
		game_id: StringName,
		success: bool,
		reason: String
) -> void:
	if game_session.phase != GameSessionState.Phase.LOADING_GAME:
		return
	if game_session.local_is_host:
		_handle_round_loaded(
			LobbyProtocol.SERVER_PEER_ID,
			report_round_id,
			game_id,
			success,
			reason
		)
		return
	_request_round_loaded.rpc_id(
		LobbyProtocol.SERVER_PEER_ID,
		report_round_id,
		String(game_id),
		success,
		reason.left(200)
	)


func submit_minigame_action(
		action_round_id: int,
		action_id: StringName,
		payload: Dictionary
) -> void:
	if game_session.phase != GameSessionState.Phase.PLAYING:
		return
	if game_session.local_is_host:
		_handle_minigame_action(
			LobbyProtocol.SERVER_PEER_ID,
			action_round_id,
			action_id,
			payload
		)
		return
	_request_minigame_action.rpc_id(
		LobbyProtocol.SERVER_PEER_ID,
		action_round_id,
		String(action_id),
		payload
	)


func submit_minigame_realtime_input(
		input_round_id: int,
		sequence: int,
		payload: Dictionary
) -> void:
	if game_session.phase != GameSessionState.Phase.PLAYING:
		return
	if game_session.local_is_host:
		_handle_realtime_input(LobbyProtocol.SERVER_PEER_ID, input_round_id, sequence, payload)
		return
	_request_realtime_input.rpc_id(
		LobbyProtocol.SERVER_PEER_ID,
		input_round_id,
		sequence,
		payload
	)


func publish_minigame_realtime_state(
		state_round_id: int,
		state_sequence: int,
		payload: Dictionary
) -> void:
	if (
		connection_state != ConnectionState.HOSTING
		or game_session.phase != GameSessionState.Phase.PLAYING
		or state_round_id != game_session.round_id
		or state_sequence < 0
		or payload.size() > LobbyProtocol.MAX_ACTION_PAYLOAD_FIELDS
	):
		return
	_apply_realtime_state.rpc(state_round_id, state_sequence, payload)


func publish_minigame_progress(
		progress_round_id: int,
		results: Array[MinigamePlayerResult],
		finish_requested: bool
) -> void:
	if (
		connection_state != ConnectionState.HOSTING
		or game_session.phase != GameSessionState.Phase.PLAYING
		or progress_round_id != game_session.round_id
	):
		return
	var update_error: Error = game_session.set_round_results(results)
	if update_error != OK:
		push_warning("Ignored invalid authoritative minigame progress.")
		return
	if finish_requested or game_session.are_all_active_results_complete():
		_finish_current_round()
	else:
		_broadcast_snapshot()


func pause_intermission_auto_advance() -> void:
	if connection_state != ConnectionState.HOSTING:
		return
	if game_session.set_intermission_paused(true) == OK:
		_broadcast_snapshot()


func request_next_round() -> void:
	if connection_state != ConnectionState.HOSTING:
		return
	if game_session.phase != GameSessionState.Phase.INTERMISSION:
		return
	_start_next_playlist_round()


func request_return_to_lobby() -> void:
	if connection_state != ConnectionState.HOSTING:
		return
	if (
		game_session.phase != GameSessionState.Phase.INTERMISSION
		and game_session.phase != GameSessionState.Phase.SESSION_RESULTS
	):
		return
	_return_everyone_to_lobby("已返回大厅，请重新准备。")


func _start_next_playlist_round() -> void:
	var random_seed_value: int = randi_range(1, 2147483647)
	var begin_error: Error = game_session.begin_next_round(random_seed_value)
	if begin_error != OK:
		push_error("Could not begin playlist round: %s" % error_string(begin_error))
		return
	_loaded_peer_ids.clear()
	last_status_message = "正在加载%s……" % _current_definition_name()
	_broadcast_snapshot()
	var definition: MinigameDefinition = get_minigame_definition(game_session.current_game_id)
	if definition == null:
		_cancel_playlist("小游戏定义丢失，整场已取消。")
		return
	var timer: SceneTreeTimer = get_tree().create_timer(definition.load_timeout_seconds)
	timer.timeout.connect(_on_load_timeout.bind(game_session.round_id))


func _finish_current_round() -> void:
	var definition: MinigameDefinition = get_minigame_definition(game_session.current_game_id)
	if definition == null:
		_cancel_playlist("小游戏定义丢失，整场已取消。")
		return
	if game_session.finalize_round_results(definition.ranking_mode) != OK:
		push_warning("Could not finalize current round.")
		return
	_broadcast_snapshot()
	if game_session.phase == GameSessionState.Phase.INTERMISSION:
		var timer: SceneTreeTimer = get_tree().create_timer(
			float(game_session.playlist_config.intermission_seconds)
		)
		timer.timeout.connect(_on_intermission_timeout.bind(game_session.round_id))


func _return_everyone_to_lobby(message: String) -> void:
	game_session.return_to_lobby()
	_loaded_peer_ids.clear()
	if _peer != null:
		_peer.refuse_new_connections = false
	last_status_message = message
	_apply_lobby_return.rpc(game_session.create_snapshot(), message)


func _on_peer_connected(peer_id: int) -> void:
	if connection_state == ConnectionState.HOSTING:
		print("Peer %d connected and is awaiting registration." % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if connection_state != ConnectionState.HOSTING:
		return
	if not game_session.players_by_peer.has(peer_id):
		return
	var disconnected_player: SessionPlayer = game_session.players_by_peer[peer_id]
	var disconnected_name: String = disconnected_player.display_name
	if game_session.phase == GameSessionState.Phase.LOADING_GAME:
		game_session.mark_player_withdrawn(peer_id)
		game_session.remove_player(peer_id)
		_cancel_playlist("%s 在加载阶段离开，整场已取消。" % disconnected_name)
		return
	if (
		game_session.phase == GameSessionState.Phase.COUNTDOWN
		or game_session.phase == GameSessionState.Phase.PLAYING
	):
		game_session.mark_player_withdrawn(peer_id)
		game_session.remove_player(peer_id)
		if game_session.are_all_active_results_complete():
			_finish_current_round()
		else:
			_broadcast_snapshot()
		return
	if (
		game_session.phase == GameSessionState.Phase.INTERMISSION
		or game_session.phase == GameSessionState.Phase.SESSION_RESULTS
	):
		game_session.mark_player_withdrawn(peer_id)
		game_session.remove_player(peer_id)
		_broadcast_snapshot()
		return
	game_session.remove_player(peer_id)
	_broadcast_snapshot()


func _on_connection_timeout(attempt_id: int) -> void:
	if (
		connection_state != ConnectionState.CONNECTING
		or attempt_id != _connection_attempt_id
	):
		return
	_fail_and_reset(
		"连接超时：房主无响应，或 UDP 流量被防火墙、路由器拦截。"
	)


func _on_connected_to_server() -> void:
	if connection_state != ConnectionState.CONNECTING:
		return
	var local_id: int = multiplayer.get_unique_id()
	game_session.begin_session(local_id, false)
	_last_applied_phase = GameSessionState.Phase.LOBBY
	_last_applied_round_id = 0
	_set_connection_state(ConnectionState.CONNECTED)
	_request_register.rpc_id(
		LobbyProtocol.SERVER_PEER_ID,
		LobbyProtocol.make_registration_payload(_local_display_name)
	)


func _on_connection_failed() -> void:
	if connection_state != ConnectionState.CONNECTING:
		return
	_fail_and_reset(
		"无法连接到房主：请检查地址、端口、房主状态和 UDP 防火墙设置。"
	)


func _on_server_disconnected() -> void:
	if connection_state == ConnectionState.OFFLINE:
		return
	_reset_connection()
	last_status_message = "房主已离开，会话已结束。"
	session_left.emit(last_status_message)


@rpc("any_peer", "call_remote", "reliable")
func _request_register(payload: Dictionary) -> void:
	if connection_state != ConnectionState.HOSTING:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= LobbyProtocol.SERVER_PEER_ID:
		return
	if game_session.phase != GameSessionState.Phase.LOBBY:
		_reject_peer(sender_id, "游戏已经开始，当前大厅不再接受新玩家。")
		return
	if game_session.players_by_peer.size() >= LobbyProtocol.MAX_PLAYERS:
		_reject_peer(sender_id, "大厅已满，最多支持 8 名玩家。")
		return
	var validation_error: Error = LobbyProtocol.validate_registration_payload(payload)
	if validation_error == ERR_UNAVAILABLE:
		_reject_peer(sender_id, "客户端协议版本与房主不一致。")
		return
	if validation_error != OK:
		_reject_peer(sender_id, "昵称或注册数据不合法。")
		return
	var display_name: String = String(payload[LobbyProtocol.KEY_DISPLAY_NAME])
	if _is_duplicate_display_name(display_name):
		_reject_peer(sender_id, "昵称已被使用，请更换昵称。")
		return
	game_session.upsert_player(SessionPlayer.new(sender_id, display_name, false, false))
	_broadcast_snapshot()


@rpc("any_peer", "call_remote", "reliable")
func _request_ready(is_ready: bool) -> void:
	if connection_state != ConnectionState.HOSTING:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if game_session.phase != GameSessionState.Phase.LOBBY:
		return
	if game_session.set_player_ready(sender_id, is_ready) == OK:
		_broadcast_snapshot()


@rpc("any_peer", "call_remote", "reliable")
func _request_round_loaded(
		report_round_id: int,
		game_id: String,
		success: bool,
		reason: String
) -> void:
	if connection_state == ConnectionState.HOSTING:
		_handle_round_loaded(
			multiplayer.get_remote_sender_id(),
			report_round_id,
			StringName(game_id),
			success,
			reason
		)


@rpc("any_peer", "call_remote", "reliable")
func _request_minigame_action(
		action_round_id: int,
		action_id: String,
		payload: Dictionary
) -> void:
	if connection_state == ConnectionState.HOSTING:
		_handle_minigame_action(
			multiplayer.get_remote_sender_id(),
			action_round_id,
			StringName(action_id),
			payload
		)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _request_realtime_input(
		input_round_id: int,
		sequence: int,
		payload: Dictionary
) -> void:
	if connection_state == ConnectionState.HOSTING:
		_handle_realtime_input(
			multiplayer.get_remote_sender_id(),
			input_round_id,
			sequence,
			payload
		)


@rpc("authority", "call_remote", "reliable")
func _registration_rejected(reason: String) -> void:
	if multiplayer.get_remote_sender_id() == LobbyProtocol.SERVER_PEER_ID:
		_fail_and_reset(reason)


@rpc("authority", "call_local", "reliable")
func _apply_session_snapshot(payload: Dictionary) -> void:
	if (
		not multiplayer.is_server()
		and multiplayer.get_remote_sender_id() != LobbyProtocol.SERVER_PEER_ID
	):
		return
	var previous_phase: int = _last_applied_phase
	var previous_round_id: int = _last_applied_round_id
	var previous_paused: bool = _last_intermission_paused
	var replace_error: Error = game_session.replace_from_snapshot(payload)
	if replace_error != OK:
		if multiplayer.is_server():
			push_error("Host generated an invalid session snapshot: %s" % error_string(replace_error))
		else:
			_fail_and_reset("收到无效的会话数据，已主动断开以避免状态不同步。")
		return
	_last_applied_phase = game_session.phase
	_last_applied_round_id = game_session.round_id
	_last_intermission_paused = game_session.intermission_paused
	if not _has_joined_lobby:
		_has_joined_lobby = true
		last_status_message = "已加入大厅。"
		lobby_joined.emit()
	_emit_snapshot_events(previous_phase, previous_round_id, previous_paused)


@rpc("authority", "call_local", "reliable")
func _apply_round_cancel(payload: Dictionary, reason: String) -> void:
	if (
		not multiplayer.is_server()
		and multiplayer.get_remote_sender_id() != LobbyProtocol.SERVER_PEER_ID
	):
		return
	last_status_message = reason
	_apply_session_snapshot(payload)
	round_cancelled.emit(reason)


@rpc("authority", "call_local", "reliable")
func _apply_lobby_return(payload: Dictionary, message: String) -> void:
	if (
		not multiplayer.is_server()
		and multiplayer.get_remote_sender_id() != LobbyProtocol.SERVER_PEER_ID
	):
		return
	last_status_message = message
	_apply_session_snapshot(payload)


@rpc("authority", "call_local", "unreliable_ordered", 2)
func _apply_realtime_state(
		state_round_id: int,
		state_sequence: int,
		payload: Dictionary
) -> void:
	if (
		not multiplayer.is_server()
		and multiplayer.get_remote_sender_id() != LobbyProtocol.SERVER_PEER_ID
	):
		return
	if (
		game_session.phase != GameSessionState.Phase.PLAYING
		or state_round_id != game_session.round_id
		or state_sequence < 0
		or payload.size() > LobbyProtocol.MAX_ACTION_PAYLOAD_FIELDS
	):
		return
	minigame_realtime_state_received.emit(
		state_round_id,
		state_sequence,
		payload.duplicate(true)
	)


func _handle_round_loaded(
		sender_id: int,
		report_round_id: int,
		game_id: StringName,
		success: bool,
		reason: String
) -> void:
	if (
		game_session.phase != GameSessionState.Phase.LOADING_GAME
		or report_round_id != game_session.round_id
		or game_id != game_session.current_game_id
		or not game_session.players_by_peer.has(sender_id)
	):
		return
	if not success:
		var player: SessionPlayer = game_session.players_by_peer[sender_id]
		var safe_reason: String = reason.strip_edges().left(200)
		if safe_reason.is_empty():
			safe_reason = "未知加载错误"
		_cancel_playlist("%s 加载失败：%s" % [player.display_name, safe_reason])
		return
	if _loaded_peer_ids.has(sender_id):
		return
	_loaded_peer_ids[sender_id] = true
	for peer_id: int in game_session.players_by_peer:
		if not _loaded_peer_ids.has(peer_id):
			return
	if game_session.set_round_phase(GameSessionState.Phase.COUNTDOWN) != OK:
		_cancel_playlist("无法进入倒计时，整场已取消。")
		return
	_broadcast_snapshot()
	var definition: MinigameDefinition = get_minigame_definition(game_session.current_game_id)
	if definition == null:
		_cancel_playlist("小游戏定义丢失，整场已取消。")
		return
	var timer: SceneTreeTimer = get_tree().create_timer(definition.countdown_seconds)
	timer.timeout.connect(_on_countdown_finished.bind(game_session.round_id))


func _handle_minigame_action(
		sender_id: int,
		action_round_id: int,
		action_id: StringName,
		payload: Dictionary
) -> void:
	if (
		game_session.phase != GameSessionState.Phase.PLAYING
		or action_round_id != game_session.round_id
		or not game_session.players_by_peer.has(sender_id)
		or LobbyProtocol.validate_action_envelope(action_id, payload) != OK
	):
		return
	minigame_action_received.emit(
		sender_id,
		action_round_id,
		action_id,
		payload.duplicate(true)
	)


func _handle_realtime_input(
		sender_id: int,
		input_round_id: int,
		sequence: int,
		payload: Dictionary
) -> void:
	if (
		game_session.phase != GameSessionState.Phase.PLAYING
		or input_round_id != game_session.round_id
		or not game_session.players_by_peer.has(sender_id)
		or sequence < 0
		or payload.size() > LobbyProtocol.MAX_ACTION_PAYLOAD_FIELDS
	):
		return
	minigame_realtime_input_received.emit(
		sender_id,
		input_round_id,
		sequence,
		payload.duplicate(true)
	)


func _on_load_timeout(timeout_round_id: int) -> void:
	if (
		game_session.phase == GameSessionState.Phase.LOADING_GAME
		and timeout_round_id == game_session.round_id
	):
		_cancel_playlist("等待玩家加载超时，整场已取消。")


func _on_countdown_finished(countdown_round_id: int) -> void:
	if (
		game_session.phase != GameSessionState.Phase.COUNTDOWN
		or countdown_round_id != game_session.round_id
	):
		return
	if game_session.set_round_phase(GameSessionState.Phase.PLAYING) != OK:
		_cancel_playlist("无法开始小游戏，整场已取消。")
		return
	_broadcast_snapshot()
	var definition: MinigameDefinition = get_minigame_definition(game_session.current_game_id)
	if definition == null:
		return
	var duration_seconds: float = definition.time_limit_seconds + definition.result_grace_seconds
	var timer: SceneTreeTimer = get_tree().create_timer(duration_seconds)
	timer.timeout.connect(_on_round_time_expired.bind(game_session.round_id))


func _on_round_time_expired(expired_round_id: int) -> void:
	if (
		game_session.phase == GameSessionState.Phase.PLAYING
		and expired_round_id == game_session.round_id
	):
		round_time_expired.emit(expired_round_id)


func _on_intermission_timeout(intermission_round_id: int) -> void:
	if (
		game_session.phase == GameSessionState.Phase.INTERMISSION
		and intermission_round_id == game_session.round_id
		and not game_session.intermission_paused
	):
		_start_next_playlist_round()


func _cancel_playlist(reason: String) -> void:
	if connection_state != ConnectionState.HOSTING:
		return
	game_session.return_to_lobby()
	_loaded_peer_ids.clear()
	if _peer != null:
		_peer.refuse_new_connections = false
	_apply_round_cancel.rpc(game_session.create_snapshot(), reason.left(240))


func _emit_snapshot_events(
		previous_phase: int,
		previous_round_id: int,
		previous_paused: bool
) -> void:
	var current_phase: int = game_session.phase
	if current_phase == GameSessionState.Phase.LOBBY:
		if previous_phase != GameSessionState.Phase.LOBBY:
			lobby_returned.emit()
		return
	var definition: MinigameDefinition = get_minigame_definition(game_session.current_game_id)
	if (
		current_phase == GameSessionState.Phase.LOADING_GAME
		and game_session.round_id != previous_round_id
	):
		round_loading_started.emit(
			game_session.round_id,
			game_session.current_game_id,
			game_session.random_seed
		)
	round_progress_changed.emit(
		game_session.round_id,
		game_session.get_ranked_results_for_display()
	)
	if (
		current_phase == GameSessionState.Phase.COUNTDOWN
		and previous_phase != GameSessionState.Phase.COUNTDOWN
	):
		var countdown_seconds: float = definition.countdown_seconds if definition != null else 0.0
		round_countdown_started.emit(game_session.round_id, countdown_seconds)
	elif (
		current_phase == GameSessionState.Phase.PLAYING
		and previous_phase != GameSessionState.Phase.PLAYING
	):
		round_play_started.emit(game_session.round_id)
	elif current_phase == GameSessionState.Phase.INTERMISSION:
		if previous_phase != GameSessionState.Phase.INTERMISSION:
			round_results_ready.emit(
				game_session.round_id,
				game_session.get_ranked_results_for_display()
			)
			var next_game_id: StringName = game_session.playlist_game_ids[
				game_session.current_round_index + 1
			]
			intermission_started.emit(
				game_session.round_id,
				float(game_session.playlist_config.intermission_seconds),
				next_game_id
			)
		if (
			previous_phase != GameSessionState.Phase.INTERMISSION
			or previous_paused != game_session.intermission_paused
		):
			intermission_pause_changed.emit(
				game_session.round_id,
				game_session.intermission_paused
			)
	elif (
		current_phase == GameSessionState.Phase.SESSION_RESULTS
		and previous_phase != GameSessionState.Phase.SESSION_RESULTS
	):
		round_results_ready.emit(
			game_session.round_id,
			game_session.get_ranked_results_for_display()
		)
		session_results_ready.emit(game_session.get_sorted_standings())


func _broadcast_snapshot() -> void:
	if connection_state == ConnectionState.HOSTING:
		_apply_session_snapshot.rpc(game_session.create_snapshot())


func _reject_peer(peer_id: int, reason: String) -> void:
	_registration_rejected.rpc_id(peer_id, reason)
	var timer: SceneTreeTimer = get_tree().create_timer(0.2)
	timer.timeout.connect(_disconnect_rejected_peer.bind(peer_id))


func _disconnect_rejected_peer(peer_id: int) -> void:
	if _peer != null and connection_state == ConnectionState.HOSTING:
		if multiplayer.get_peers().has(peer_id):
			_peer.disconnect_peer(peer_id)


func _is_duplicate_display_name(display_name: String) -> bool:
	var normalized_candidate: String = display_name.to_lower()
	for player: SessionPlayer in game_session.get_sorted_players():
		if player.display_name.to_lower() == normalized_candidate:
			return true
	return false


func _current_definition_name() -> String:
	var definition: MinigameDefinition = get_minigame_definition(game_session.current_game_id)
	return definition.display_name if definition != null else String(game_session.current_game_id)


func _is_available_local_bind(bind_address: String) -> bool:
	if (
		bind_address == LobbyProtocol.DEFAULT_BIND_ADDRESS
		or bind_address == LobbyProtocol.IPV4_ANY_ADDRESS
		or bind_address == LobbyProtocol.IPV6_ANY_ADDRESS
	):
		return true
	for local_address: LocalNetworkAddress in get_local_connection_addresses():
		if local_address.address.to_lower() == bind_address.to_lower():
			return true
	return false


static func _sort_local_addresses(
		left: LocalNetworkAddress,
		right: LocalNetworkAddress
) -> bool:
	if left.is_loopback != right.is_loopback:
		return not left.is_loopback
	if left.ip_type != right.ip_type:
		return left.ip_type < right.ip_type
	return left.address.naturalnocasecmp_to(right.address) < 0


func _fail_and_reset(reason: String) -> void:
	_reset_connection()
	last_status_message = reason
	connection_failed.emit(reason)


func _reset_connection() -> void:
	_connection_attempt_id += 1
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_local_display_name = ""
	_has_joined_lobby = false
	current_bind_address = LobbyProtocol.DEFAULT_BIND_ADDRESS
	current_port = 0
	current_remote_address = ""
	_loaded_peer_ids.clear()
	_last_applied_phase = GameSessionState.Phase.OFFLINE
	_last_applied_round_id = 0
	_last_intermission_paused = false
	game_session.reset_session()
	_set_connection_state(ConnectionState.OFFLINE)


func _set_connection_state(next_state: int) -> void:
	if connection_state == next_state:
		return
	connection_state = next_state
	connection_state_changed.emit(connection_state)
