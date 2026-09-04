## Holds mutable cross-scene session state. NetworkManager is its only authoritative writer.
class_name GameSessionState
extends Node

signal players_changed(players: Array[SessionPlayer])
signal phase_changed(phase: int)

enum Phase {
	OFFLINE,
	LOBBY,
	STARTING_GAME,
	PLACEHOLDER_GAME,
}

var players_by_peer: Dictionary[int, SessionPlayer] = {}
var local_peer_id: int = 0
var local_is_host: bool = false
var phase: int = Phase.OFFLINE
var current_game_id: String = ""
var random_seed: int = 0


func begin_session(peer_id: int, is_host: bool) -> void:
	players_by_peer.clear()
	local_peer_id = peer_id
	local_is_host = is_host
	current_game_id = ""
	random_seed = 0
	_set_phase(Phase.LOBBY)
	players_changed.emit(get_sorted_players())


func reset_session() -> void:
	players_by_peer.clear()
	local_peer_id = 0
	local_is_host = false
	current_game_id = ""
	random_seed = 0
	_set_phase(Phase.OFFLINE)
	players_changed.emit(get_sorted_players())


func upsert_player(player: SessionPlayer) -> void:
	assert(player != null)
	players_by_peer[player.peer_id] = player
	players_changed.emit(get_sorted_players())


func remove_player(peer_id: int) -> void:
	if not players_by_peer.erase(peer_id):
		return
	players_changed.emit(get_sorted_players())


func set_player_ready(peer_id: int, is_ready: bool) -> Error:
	if not players_by_peer.has(peer_id):
		return ERR_DOES_NOT_EXIST
	var player: SessionPlayer = players_by_peer[peer_id]
	if player.is_host:
		return ERR_UNAUTHORIZED
	player.is_ready = is_ready
	players_changed.emit(get_sorted_players())
	return OK


func set_starting_game() -> void:
	_set_phase(Phase.STARTING_GAME)


func get_local_player() -> SessionPlayer:
	return players_by_peer.get(local_peer_id) as SessionPlayer


func get_sorted_players() -> Array[SessionPlayer]:
	var players: Array[SessionPlayer] = []
	var values: Array = players_by_peer.values()
	var index: int = 0
	while index < values.size():
		var player: SessionPlayer = values[index] as SessionPlayer
		if player != null:
			players.append(player)
		index += 1
	players.sort_custom(Callable(self, "_is_player_before"))
	return players


func can_host_start() -> bool:
	if not local_is_host or phase != Phase.LOBBY:
		return false
	if players_by_peer.size() < 2:
		return false

	var players: Array[SessionPlayer] = get_sorted_players()
	var index: int = 0
	while index < players.size():
		var player: SessionPlayer = players[index]
		if not player.is_host and not player.is_ready:
			return false
		index += 1
	return true


func create_snapshot() -> Dictionary[StringName, Variant]:
	return _build_snapshot(phase, current_game_id, random_seed)


func create_game_snapshot(game_id: String, seed: int) -> Dictionary[StringName, Variant]:
	return _build_snapshot(Phase.PLACEHOLDER_GAME, game_id, seed)


## Replaces state atomically after validating the complete authoritative snapshot.
func replace_from_snapshot(payload: Dictionary) -> Error:
	var version_error: Error = LobbyProtocol.validate_protocol_version(payload)
	if version_error != OK:
		return version_error
	if not payload.has(LobbyProtocol.KEY_PHASE):
		return ERR_INVALID_DATA
	if not payload.has(LobbyProtocol.KEY_PLAYERS):
		return ERR_INVALID_DATA
	if not payload.has(LobbyProtocol.KEY_GAME_ID):
		return ERR_INVALID_DATA
	if not payload.has(LobbyProtocol.KEY_RANDOM_SEED):
		return ERR_INVALID_DATA

	var raw_phase: Variant = payload[LobbyProtocol.KEY_PHASE]
	var raw_players: Variant = payload[LobbyProtocol.KEY_PLAYERS]
	var raw_game_id: Variant = payload[LobbyProtocol.KEY_GAME_ID]
	var raw_random_seed: Variant = payload[LobbyProtocol.KEY_RANDOM_SEED]
	if typeof(raw_phase) != TYPE_INT:
		return ERR_INVALID_DATA
	if typeof(raw_players) != TYPE_ARRAY:
		return ERR_INVALID_DATA
	if typeof(raw_game_id) != TYPE_STRING:
		return ERR_INVALID_DATA
	if typeof(raw_random_seed) != TYPE_INT:
		return ERR_INVALID_DATA

	var parsed_phase: int = int(raw_phase)
	if (
			parsed_phase != Phase.LOBBY
			and parsed_phase != Phase.STARTING_GAME
			and parsed_phase != Phase.PLACEHOLDER_GAME
	):
		return ERR_INVALID_DATA

	var parsed_game_id: String = String(raw_game_id)
	var parsed_random_seed: int = int(raw_random_seed)
	if parsed_phase == Phase.PLACEHOLDER_GAME:
		if parsed_game_id.is_empty() or parsed_random_seed <= 0:
			return ERR_INVALID_DATA
	elif not parsed_game_id.is_empty() or parsed_random_seed != 0:
		return ERR_INVALID_DATA

	var raw_player_array: Array = raw_players as Array
	if raw_player_array.is_empty() or raw_player_array.size() > LobbyProtocol.MAX_PLAYERS:
		return ERR_INVALID_DATA

	var replacement: Dictionary[int, SessionPlayer] = {}
	var host_count: int = 0
	var index: int = 0
	while index < raw_player_array.size():
		var raw_player: Variant = raw_player_array[index]
		if typeof(raw_player) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var player_payload: Dictionary = raw_player as Dictionary
		var player: SessionPlayer = SessionPlayer.from_payload(player_payload)
		if player == null or replacement.has(player.peer_id):
			return ERR_INVALID_DATA
		if player.is_host:
			host_count += 1
			if player.peer_id != LobbyProtocol.SERVER_PEER_ID or not player.is_ready:
				return ERR_INVALID_DATA
		elif player.peer_id == LobbyProtocol.SERVER_PEER_ID:
			return ERR_INVALID_DATA
		replacement[player.peer_id] = player
		index += 1

	if host_count != 1:
		return ERR_INVALID_DATA
	if local_peer_id > 0 and not replacement.has(local_peer_id):
		return ERR_INVALID_DATA

	players_by_peer = replacement
	current_game_id = parsed_game_id
	random_seed = parsed_random_seed
	_set_phase(parsed_phase)
	players_changed.emit(get_sorted_players())
	return OK


func _build_snapshot(
		snapshot_phase: int,
		game_id: String,
		seed: int
) -> Dictionary[StringName, Variant]:
	var player_payloads: Array[Dictionary] = []
	var players: Array[SessionPlayer] = get_sorted_players()
	var index: int = 0
	while index < players.size():
		player_payloads.append(players[index].to_payload())
		index += 1

	var snapshot: Dictionary[StringName, Variant] = {}
	snapshot[LobbyProtocol.KEY_PROTOCOL_VERSION] = LobbyProtocol.PROTOCOL_VERSION
	snapshot[LobbyProtocol.KEY_PHASE] = snapshot_phase
	snapshot[LobbyProtocol.KEY_PLAYERS] = player_payloads
	snapshot[LobbyProtocol.KEY_GAME_ID] = game_id
	snapshot[LobbyProtocol.KEY_RANDOM_SEED] = seed
	return snapshot


func _set_phase(next_phase: int) -> void:
	if phase == next_phase:
		return
	phase = next_phase
	phase_changed.emit(phase)


func _is_player_before(left: SessionPlayer, right: SessionPlayer) -> bool:
	if left.is_host != right.is_host:
		return left.is_host
	return left.peer_id < right.peer_id
