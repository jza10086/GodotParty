## Owns the ENet peer, connection lifecycle, and all authoritative lobby RPCs.
class_name NetworkManagerService
extends Node

signal connection_state_changed(state: int)
signal connection_failed(reason: String)
signal lobby_joined()
signal session_left(reason: String)
signal game_started()

enum ConnectionState {
	OFFLINE,
	STARTING_HOST,
	HOSTING,
	CONNECTING,
	CONNECTED,
}

var connection_state: int = ConnectionState.OFFLINE
var last_status_message: String = ""
var game_session: GameSessionState = null

var _peer: ENetMultiplayerPeer = null
var _local_display_name: String = ""
var _has_joined_lobby: bool = false


func _ready() -> void:
	if game_session == null:
		game_session = get_node_or_null("/root/GameSession") as GameSessionState
	assert(game_session != null, "NetworkManager requires the GameSession Autoload.")
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Starts a host-authoritative ENet lobby. The server occupies peer slot 1.
func host_session(display_name: String, port: int) -> Error:
	if connection_state != ConnectionState.OFFLINE:
		return ERR_ALREADY_IN_USE

	var normalized_name: String = SessionPlayer.normalize_display_name(display_name)
	var validation_error: Error = SessionPlayer.validate_display_name(normalized_name)
	if validation_error != OK:
		return validation_error
	validation_error = LobbyProtocol.validate_port(port)
	if validation_error != OK:
		return validation_error

	_set_connection_state(ConnectionState.STARTING_HOST)
	var next_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var create_error: Error = next_peer.create_server(port, LobbyProtocol.MAX_REMOTE_CLIENTS)
	if create_error != OK:
		_reset_connection()
		return create_error

	_peer = next_peer
	multiplayer.multiplayer_peer = _peer
	_local_display_name = normalized_name
	_has_joined_lobby = true
	game_session.begin_session(LobbyProtocol.SERVER_PEER_ID, true)
	game_session.upsert_player(
		SessionPlayer.new(LobbyProtocol.SERVER_PEER_ID, normalized_name, true, true)
	)
	last_status_message = "已创建大厅，等待其他玩家加入。"
	_set_connection_state(ConnectionState.HOSTING)
	lobby_joined.emit()
	return OK


## Connects to an ENet host and submits local identity after the handshake succeeds.
func join_session(display_name: String, address: String, port: int) -> Error:
	if connection_state != ConnectionState.OFFLINE:
		return ERR_ALREADY_IN_USE

	var normalized_name: String = SessionPlayer.normalize_display_name(display_name)
	var normalized_address: String = address.strip_edges()
	var validation_error: Error = SessionPlayer.validate_display_name(normalized_name)
	if validation_error != OK:
		return validation_error
	validation_error = LobbyProtocol.validate_address(normalized_address)
	if validation_error != OK:
		return validation_error
	validation_error = LobbyProtocol.validate_port(port)
	if validation_error != OK:
		return validation_error

	var next_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var create_error: Error = next_peer.create_client(normalized_address, port)
	if create_error != OK:
		return create_error

	_peer = next_peer
	multiplayer.multiplayer_peer = _peer
	_local_display_name = normalized_name
	_has_joined_lobby = false
	last_status_message = "正在连接 %s:%d……" % [normalized_address, port]
	_set_connection_state(ConnectionState.CONNECTING)
	return OK


## Closes the active peer and clears all session state.
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


func request_start_game() -> void:
	if connection_state != ConnectionState.HOSTING:
		return
	if not game_session.can_host_start():
		return

	game_session.set_starting_game()
	if _peer != null:
		_peer.refuse_new_connections = true
	var random_seed_value: int = randi_range(1, 2147483647)
	var payload: Dictionary[StringName, Variant] = game_session.create_game_snapshot(
		LobbyProtocol.PLACEHOLDER_GAME_ID,
		random_seed_value
	)
	_apply_session_snapshot.rpc(payload)


func _on_peer_connected(peer_id: int) -> void:
	if connection_state == ConnectionState.HOSTING:
		print("Peer %d connected and is awaiting registration." % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if connection_state != ConnectionState.HOSTING:
		return
	if not game_session.players_by_peer.has(peer_id):
		return
	game_session.remove_player(peer_id)
	_broadcast_snapshot()


func _on_connected_to_server() -> void:
	if connection_state != ConnectionState.CONNECTING:
		return
	var local_peer_id: int = multiplayer.get_unique_id()
	game_session.begin_session(local_peer_id, false)
	_set_connection_state(ConnectionState.CONNECTED)
	var registration: Dictionary[StringName, Variant] = LobbyProtocol.make_registration_payload(
		_local_display_name
	)
	_request_register.rpc_id(LobbyProtocol.SERVER_PEER_ID, registration)


func _on_connection_failed() -> void:
	_fail_and_reset("无法连接到房主，请检查地址、端口和房主状态。")


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
		push_warning("Ignored ready request outside the lobby from peer %d." % sender_id)
		return
	if not game_session.players_by_peer.has(sender_id):
		push_warning("Ignored ready request from unknown peer %d." % sender_id)
		return
	var ready_error: Error = game_session.set_player_ready(sender_id, is_ready)
	if ready_error != OK:
		push_warning("Ignored invalid ready request from peer %d." % sender_id)
		return
	_broadcast_snapshot()


@rpc("authority", "call_remote", "reliable")
func _registration_rejected(reason: String) -> void:
	if multiplayer.get_remote_sender_id() != LobbyProtocol.SERVER_PEER_ID:
		return
	_fail_and_reset(reason)


@rpc("authority", "call_local", "reliable")
func _apply_session_snapshot(payload: Dictionary) -> void:
	if not multiplayer.is_server() and multiplayer.get_remote_sender_id() != LobbyProtocol.SERVER_PEER_ID:
		return
	var previous_phase: int = game_session.phase
	var replace_error: Error = game_session.replace_from_snapshot(payload)
	if replace_error != OK:
		if multiplayer.is_server():
			push_error("Host generated an invalid session snapshot: %s" % error_string(replace_error))
		else:
			_fail_and_reset("收到无效的大厅数据，已主动断开以避免状态不同步。")
		return

	if not _has_joined_lobby:
		_has_joined_lobby = true
		last_status_message = "已加入大厅。"
		lobby_joined.emit()
	if previous_phase != GameSessionState.Phase.PLACEHOLDER_GAME \
			and game_session.phase == GameSessionState.Phase.PLACEHOLDER_GAME:
		last_status_message = "游戏已开始。"
		game_started.emit()


func _broadcast_snapshot() -> void:
	if connection_state != ConnectionState.HOSTING:
		return
	var snapshot: Dictionary[StringName, Variant] = game_session.create_snapshot()
	_apply_session_snapshot.rpc(snapshot)


func _reject_peer(peer_id: int, reason: String) -> void:
	_registration_rejected.rpc_id(peer_id, reason)
	var timer: SceneTreeTimer = get_tree().create_timer(0.2)
	timer.timeout.connect(_disconnect_rejected_peer.bind(peer_id))


func _disconnect_rejected_peer(peer_id: int) -> void:
	if _peer == null or connection_state != ConnectionState.HOSTING:
		return
	if multiplayer.get_peers().has(peer_id):
		_peer.disconnect_peer(peer_id)


func _is_duplicate_display_name(display_name: String) -> bool:
	var normalized_candidate: String = display_name.to_lower()
	var players: Array[SessionPlayer] = game_session.get_sorted_players()
	var index: int = 0
	while index < players.size():
		if players[index].display_name.to_lower() == normalized_candidate:
			return true
		index += 1
	return false


func _fail_and_reset(reason: String) -> void:
	_reset_connection()
	last_status_message = reason
	connection_failed.emit(reason)


func _reset_connection() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_local_display_name = ""
	_has_joined_lobby = false
	game_session.reset_session()
	_set_connection_state(ConnectionState.OFFLINE)


func _set_connection_state(next_state: int) -> void:
	if connection_state == next_state:
		return
	connection_state = next_state
	connection_state_changed.emit(connection_state)
