## Owns the ENet peer, connection lifecycle, and all authoritative session RPCs.
class_name NetworkManagerService
extends Node

signal connection_state_changed(state: int)
signal connection_failed(reason: String)
signal lobby_joined()
signal session_left(reason: String)
signal round_loading_started(round_id: int, game_id: StringName, random_seed: int)
signal round_countdown_started(round_id: int, duration_seconds: float)
signal round_play_started(round_id: int)
signal round_progress_changed(round_id: int, results: Array[MinigamePlayerResult])
signal round_results_ready(round_id: int, results: Array[MinigamePlayerResult])
signal round_cancelled(reason: String)
signal lobby_returned()
signal minigame_action_received(
	peer_id: int,
	round_id: int,
	action_id: StringName,
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

var connection_state: int = ConnectionState.OFFLINE
var last_status_message: String = ""
var game_session: GameSessionState = null

var _peer: ENetMultiplayerPeer = null
var _local_display_name: String = ""
var _has_joined_lobby: bool = false
var _definitions_by_id: Dictionary[StringName, MinigameDefinition] = {}
var _loaded_peer_ids: Dictionary[int, bool] = {}
var _last_applied_phase: int = GameSessionState.Phase.OFFLINE
var _last_applied_round_id: int = 0


func _ready() -> void:
	if game_session == null:
		game_session = get_node_or_null("/root/GameSession") as GameSessionState
	assert(game_session != null, "NetworkManager requires the GameSession Autoload.")
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func register_minigames(definitions: Array[MinigameDefinition]) -> Error:
	var replacement: Dictionary[StringName, MinigameDefinition] = {}
	for definition: MinigameDefinition in definitions:
		if definition == null or definition.validate() != OK:
			return ERR_INVALID_DATA
		if replacement.has(definition.game_id):
			return ERR_ALREADY_EXISTS
		replacement[definition.game_id] = definition
	if replacement.is_empty():
		return ERR_DOES_NOT_EXIST
	_definitions_by_id = replacement
	return OK


func get_minigame_definition(game_id: StringName) -> MinigameDefinition:
	return _definitions_by_id.get(game_id) as MinigameDefinition


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
	_last_applied_phase = GameSessionState.Phase.LOBBY
	_last_applied_round_id = 0
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


func request_start_game(game_id: StringName = LobbyProtocol.TARGET_CLICK_GAME_ID) -> void:
	if connection_state != ConnectionState.HOSTING:
		return
	if not game_session.can_host_start():
		return
	_start_round(game_id)


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


func publish_minigame_progress(
		progress_round_id: int,
		results: Array[MinigamePlayerResult],
		finish_requested: bool
) -> void:
	if connection_state != ConnectionState.HOSTING:
		return
	if game_session.phase != GameSessionState.Phase.PLAYING:
		return
	if progress_round_id != game_session.round_id:
		push_warning("Ignored progress for stale round %d." % progress_round_id)
		return
	var update_error: Error = game_session.set_round_results(results)
	if update_error != OK:
		push_warning("Ignored invalid authoritative minigame progress.")
		return
	if finish_requested or game_session.are_all_active_results_complete():
		game_session.finalize_round_results()
	_broadcast_snapshot()


func request_replay_round() -> void:
	if connection_state != ConnectionState.HOSTING:
		return
	if game_session.phase != GameSessionState.Phase.RESULTS:
		return
	var replay_game_id: StringName = game_session.current_game_id
	_start_round(replay_game_id)


func request_return_to_lobby() -> void:
	if connection_state != ConnectionState.HOSTING:
		return
	if game_session.phase != GameSessionState.Phase.RESULTS:
		return
	game_session.return_to_lobby()
	_loaded_peer_ids.clear()
	if _peer != null:
		_peer.refuse_new_connections = false
	last_status_message = "已返回大厅，请重新准备。"
	_apply_lobby_return.rpc(game_session.create_snapshot(), last_status_message)


func _start_round(game_id: StringName) -> void:
	var definition: MinigameDefinition = get_minigame_definition(game_id)
	if definition == null:
		push_warning("Cannot start unknown minigame '%s'." % String(game_id))
		return

	var next_round_id: int = game_session.round_id + 1
	var random_seed_value: int = randi_range(1, 2147483647)
	var begin_error: Error = game_session.begin_round(
		next_round_id,
		game_id,
		random_seed_value
	)
	if begin_error != OK:
		push_error("Could not begin minigame round: %s" % error_string(begin_error))
		return

	_loaded_peer_ids.clear()
	if _peer != null:
		_peer.refuse_new_connections = true
	last_status_message = "正在加载%s……" % definition.display_name
	_apply_session_snapshot.rpc(game_session.create_snapshot())
	var timer: SceneTreeTimer = get_tree().create_timer(definition.load_timeout_seconds)
	timer.timeout.connect(_on_load_timeout.bind(next_round_id))


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
		_cancel_round("%s 在加载阶段离开，本局已取消。" % disconnected_name)
		return
	if (
		game_session.phase == GameSessionState.Phase.COUNTDOWN
		or game_session.phase == GameSessionState.Phase.PLAYING
	):
		game_session.mark_player_withdrawn(peer_id)
		game_session.remove_player(peer_id)
		if game_session.are_all_active_results_complete():
			game_session.finalize_round_results()
		_broadcast_snapshot()
		return
	if game_session.phase == GameSessionState.Phase.RESULTS:
		game_session.remove_player(peer_id)
		_broadcast_snapshot()
		return

	game_session.remove_player(peer_id)
	_broadcast_snapshot()


func _on_connected_to_server() -> void:
	if connection_state != ConnectionState.CONNECTING:
		return
	var local_peer_id: int = multiplayer.get_unique_id()
	game_session.begin_session(local_peer_id, false)
	_last_applied_phase = GameSessionState.Phase.LOBBY
	_last_applied_round_id = 0
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


@rpc("any_peer", "call_remote", "reliable")
func _request_round_loaded(
		report_round_id: int,
		game_id: String,
		success: bool,
		reason: String
) -> void:
	if connection_state != ConnectionState.HOSTING:
		return
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
	if connection_state != ConnectionState.HOSTING:
		return
	_handle_minigame_action(
		multiplayer.get_remote_sender_id(),
		action_round_id,
		StringName(action_id),
		payload
	)


@rpc("authority", "call_remote", "reliable")
func _registration_rejected(reason: String) -> void:
	if multiplayer.get_remote_sender_id() != LobbyProtocol.SERVER_PEER_ID:
		return
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
	var replace_error: Error = game_session.replace_from_snapshot(payload)
	if replace_error != OK:
		if multiplayer.is_server():
			push_error("Host generated an invalid session snapshot: %s" % error_string(replace_error))
		else:
			_fail_and_reset("收到无效的会话数据，已主动断开以避免状态不同步。")
		return

	_last_applied_phase = game_session.phase
	_last_applied_round_id = game_session.round_id
	if not _has_joined_lobby:
		_has_joined_lobby = true
		last_status_message = "已加入大厅。"
		lobby_joined.emit()
	_emit_snapshot_events(previous_phase, previous_round_id)


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


func _handle_round_loaded(
		sender_id: int,
		report_round_id: int,
		game_id: StringName,
		success: bool,
		reason: String
) -> void:
	if game_session.phase != GameSessionState.Phase.LOADING_GAME:
		push_warning("Ignored load report outside loading phase from peer %d." % sender_id)
		return
	if report_round_id != game_session.round_id or game_id != game_session.current_game_id:
		push_warning("Ignored stale load report from peer %d." % sender_id)
		return
	if not game_session.players_by_peer.has(sender_id):
		push_warning("Ignored load report from unknown peer %d." % sender_id)
		return
	if not success:
		var player: SessionPlayer = game_session.players_by_peer[sender_id]
		var safe_reason: String = reason.strip_edges().left(200)
		if safe_reason.is_empty():
			safe_reason = "未知加载错误"
		_cancel_round("%s 加载失败：%s" % [player.display_name, safe_reason])
		return
	if _loaded_peer_ids.has(sender_id):
		return

	_loaded_peer_ids[sender_id] = true
	for peer_id: int in game_session.players_by_peer:
		if not _loaded_peer_ids.has(peer_id):
			return

	var phase_error: Error = game_session.set_round_phase(GameSessionState.Phase.COUNTDOWN)
	if phase_error != OK:
		_cancel_round("无法进入倒计时，本局已取消。")
		return
	_broadcast_snapshot()
	var definition: MinigameDefinition = get_minigame_definition(game_session.current_game_id)
	if definition == null:
		_cancel_round("小游戏定义丢失，本局已取消。")
		return
	var timer: SceneTreeTimer = get_tree().create_timer(definition.countdown_seconds)
	timer.timeout.connect(_on_countdown_finished.bind(game_session.round_id))


func _handle_minigame_action(
		sender_id: int,
		action_round_id: int,
		action_id: StringName,
		payload: Dictionary
) -> void:
	if game_session.phase != GameSessionState.Phase.PLAYING:
		push_warning("Ignored minigame action outside playing phase from peer %d." % sender_id)
		return
	if action_round_id != game_session.round_id:
		push_warning("Ignored minigame action for stale round %d." % action_round_id)
		return
	if not game_session.players_by_peer.has(sender_id):
		push_warning("Ignored minigame action from unknown peer %d." % sender_id)
		return
	if LobbyProtocol.validate_action_envelope(action_id, payload) != OK:
		push_warning("Ignored malformed minigame action from peer %d." % sender_id)
		return
	minigame_action_received.emit(
		sender_id,
		action_round_id,
		action_id,
		payload.duplicate(true)
	)


func _on_load_timeout(timeout_round_id: int) -> void:
	if game_session.phase != GameSessionState.Phase.LOADING_GAME:
		return
	if timeout_round_id != game_session.round_id:
		return
	_cancel_round("等待玩家加载超时，本局已取消。")


func _on_countdown_finished(countdown_round_id: int) -> void:
	if game_session.phase != GameSessionState.Phase.COUNTDOWN:
		return
	if countdown_round_id != game_session.round_id:
		return
	if game_session.set_round_phase(GameSessionState.Phase.PLAYING) != OK:
		_cancel_round("无法开始小游戏，本局已取消。")
		return
	_broadcast_snapshot()
	var definition: MinigameDefinition = get_minigame_definition(game_session.current_game_id)
	if definition == null:
		return
	var duration_seconds: float = (
		definition.time_limit_seconds + LobbyProtocol.RESULT_GRACE_SECONDS
	)
	var timer: SceneTreeTimer = get_tree().create_timer(duration_seconds)
	timer.timeout.connect(_on_round_time_expired.bind(game_session.round_id))


func _on_round_time_expired(expired_round_id: int) -> void:
	if game_session.phase != GameSessionState.Phase.PLAYING:
		return
	if expired_round_id != game_session.round_id:
		return
	round_time_expired.emit(expired_round_id)


func _cancel_round(reason: String) -> void:
	if connection_state != ConnectionState.HOSTING:
		return
	game_session.return_to_lobby()
	_loaded_peer_ids.clear()
	if _peer != null:
		_peer.refuse_new_connections = false
	_apply_round_cancel.rpc(game_session.create_snapshot(), reason.left(240))


func _emit_snapshot_events(previous_phase: int, previous_round_id: int) -> void:
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
		game_session.get_sorted_results()
	)
	if (
		current_phase == GameSessionState.Phase.COUNTDOWN
		and previous_phase != GameSessionState.Phase.COUNTDOWN
	):
		var countdown_seconds: float = 0.0
		if definition != null:
			countdown_seconds = definition.countdown_seconds
		round_countdown_started.emit(game_session.round_id, countdown_seconds)
	elif (
		current_phase == GameSessionState.Phase.PLAYING
		and previous_phase != GameSessionState.Phase.PLAYING
	):
		round_play_started.emit(game_session.round_id)
	elif (
		current_phase == GameSessionState.Phase.RESULTS
		and previous_phase != GameSessionState.Phase.RESULTS
	):
		round_results_ready.emit(
			game_session.round_id,
			game_session.get_sorted_results()
		)


func _broadcast_snapshot() -> void:
	if connection_state != ConnectionState.HOSTING:
		return
	_apply_session_snapshot.rpc(game_session.create_snapshot())


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
	for player: SessionPlayer in game_session.get_sorted_players():
		if player.display_name.to_lower() == normalized_candidate:
			return true
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
	_loaded_peer_ids.clear()
	_last_applied_phase = GameSessionState.Phase.OFFLINE
	_last_applied_round_id = 0
	game_session.reset_session()
	_set_connection_state(ConnectionState.OFFLINE)


func _set_connection_state(next_state: int) -> void:
	if connection_state == next_state:
		return
	connection_state = next_state
	connection_state_changed.emit(connection_state)
