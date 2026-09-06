## Holds mutable cross-scene session state. NetworkManager is its only authoritative writer.
class_name GameSessionState
extends Node

signal players_changed(players: Array[SessionPlayer])
signal phase_changed(phase: int)
signal results_changed(results: Array[MinigamePlayerResult])

enum Phase {
	OFFLINE,
	LOBBY,
	LOADING_GAME,
	COUNTDOWN,
	PLAYING,
	RESULTS,
}

var players_by_peer: Dictionary[int, SessionPlayer] = {}
var round_results_by_peer: Dictionary[int, MinigamePlayerResult] = {}
var local_peer_id: int = 0
var local_is_host: bool = false
var phase: int = Phase.OFFLINE
var current_game_id: StringName = &""
var random_seed: int = 0
var round_id: int = 0


func begin_session(peer_id: int, is_host: bool) -> void:
	players_by_peer.clear()
	round_results_by_peer.clear()
	local_peer_id = peer_id
	local_is_host = is_host
	current_game_id = &""
	random_seed = 0
	round_id = 0
	_set_phase(Phase.LOBBY)
	players_changed.emit(get_sorted_players())
	results_changed.emit(get_sorted_results())


func reset_session() -> void:
	players_by_peer.clear()
	round_results_by_peer.clear()
	local_peer_id = 0
	local_is_host = false
	current_game_id = &""
	random_seed = 0
	round_id = 0
	_set_phase(Phase.OFFLINE)
	players_changed.emit(get_sorted_players())
	results_changed.emit(get_sorted_results())


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


func begin_round(next_round_id: int, game_id: StringName, random_seed_value: int) -> Error:
	if next_round_id <= round_id or game_id.is_empty() or random_seed_value <= 0:
		return ERR_INVALID_PARAMETER
	if players_by_peer.is_empty():
		return ERR_DOES_NOT_EXIST

	round_id = next_round_id
	current_game_id = game_id
	random_seed = random_seed_value
	round_results_by_peer.clear()
	for player: SessionPlayer in get_sorted_players():
		round_results_by_peer[player.peer_id] = MinigamePlayerResult.new(
			player.peer_id,
			player.display_name
		)
	_set_phase(Phase.LOADING_GAME)
	results_changed.emit(get_sorted_results())
	return OK


func set_round_phase(next_phase: int) -> Error:
	if next_phase < Phase.LOADING_GAME or next_phase > Phase.RESULTS:
		return ERR_INVALID_PARAMETER
	if current_game_id.is_empty() or round_id <= 0 or random_seed <= 0:
		return ERR_INVALID_DATA
	_set_phase(next_phase)
	return OK


func set_round_results(results: Array[MinigamePlayerResult]) -> Error:
	var replacement: Dictionary[int, MinigamePlayerResult] = {}
	for result: MinigamePlayerResult in results:
		if result == null or replacement.has(result.peer_id):
			return ERR_INVALID_DATA
		replacement[result.peer_id] = result.duplicate_result()
	if replacement.is_empty() or replacement.size() > LobbyProtocol.MAX_PLAYERS:
		return ERR_INVALID_DATA
	round_results_by_peer = replacement
	results_changed.emit(get_sorted_results())
	return OK


func mark_player_withdrawn(peer_id: int) -> void:
	var result: MinigamePlayerResult = round_results_by_peer.get(peer_id) as MinigamePlayerResult
	if result == null or result.is_complete:
		return
	result.is_withdrawn = true
	result.rank = 0
	results_changed.emit(get_sorted_results())


func are_all_active_results_complete() -> bool:
	var has_active_player: bool = false
	for result: MinigamePlayerResult in get_sorted_results():
		if result.is_withdrawn:
			continue
		has_active_player = true
		if not result.is_complete:
			return false
	return has_active_player


func finalize_round_results() -> Array[MinigamePlayerResult]:
	var sorted_results: Array[MinigamePlayerResult] = get_sorted_results()
	var index: int = 0
	while index < sorted_results.size():
		sorted_results[index].rank = index + 1
		round_results_by_peer[sorted_results[index].peer_id] = sorted_results[index]
		index += 1
	_set_phase(Phase.RESULTS)
	results_changed.emit(get_sorted_results())
	return get_sorted_results()


func return_to_lobby() -> void:
	for player: SessionPlayer in get_sorted_players():
		if not player.is_host:
			player.is_ready = false
	round_results_by_peer.clear()
	current_game_id = &""
	random_seed = 0
	_set_phase(Phase.LOBBY)
	players_changed.emit(get_sorted_players())
	results_changed.emit(get_sorted_results())


func get_local_player() -> SessionPlayer:
	return players_by_peer.get(local_peer_id) as SessionPlayer


func get_round_result(peer_id: int) -> MinigamePlayerResult:
	return round_results_by_peer.get(peer_id) as MinigamePlayerResult


func get_sorted_players() -> Array[SessionPlayer]:
	var players: Array[SessionPlayer] = []
	var values: Array = players_by_peer.values()
	for value: Variant in values:
		var player: SessionPlayer = value as SessionPlayer
		if player != null:
			players.append(player)
	players.sort_custom(Callable(self, "_is_player_before"))
	return players


func get_sorted_results() -> Array[MinigamePlayerResult]:
	var results: Array[MinigamePlayerResult] = []
	var values: Array = round_results_by_peer.values()
	for value: Variant in values:
		var result: MinigamePlayerResult = value as MinigamePlayerResult
		if result != null:
			results.append(result.duplicate_result())
	results.sort_custom(Callable(MinigamePlayerResult, "is_before"))
	return results


func can_host_start() -> bool:
	if not local_is_host or phase != Phase.LOBBY:
		return false
	if players_by_peer.size() < 2:
		return false
	for player: SessionPlayer in get_sorted_players():
		if not player.is_host and not player.is_ready:
			return false
	return true


func create_snapshot() -> Dictionary[StringName, Variant]:
	var player_payloads: Array[Dictionary] = []
	for player: SessionPlayer in get_sorted_players():
		player_payloads.append(player.to_payload())

	var result_payloads: Array[Dictionary] = []
	for result: MinigamePlayerResult in get_sorted_results():
		result_payloads.append(result.to_payload())

	var snapshot: Dictionary[StringName, Variant] = {}
	snapshot[LobbyProtocol.KEY_PROTOCOL_VERSION] = LobbyProtocol.PROTOCOL_VERSION
	snapshot[LobbyProtocol.KEY_PHASE] = phase
	snapshot[LobbyProtocol.KEY_PLAYERS] = player_payloads
	snapshot[LobbyProtocol.KEY_GAME_ID] = String(current_game_id)
	snapshot[LobbyProtocol.KEY_RANDOM_SEED] = random_seed
	snapshot[LobbyProtocol.KEY_ROUND_ID] = round_id
	snapshot[LobbyProtocol.KEY_RESULTS] = result_payloads
	return snapshot


## Replaces state atomically after validating the complete authoritative snapshot.
func replace_from_snapshot(payload: Dictionary) -> Error:
	var version_error: Error = LobbyProtocol.validate_protocol_version(payload)
	if version_error != OK:
		return version_error
	var required_keys: Array[StringName] = [
		LobbyProtocol.KEY_PHASE,
		LobbyProtocol.KEY_PLAYERS,
		LobbyProtocol.KEY_GAME_ID,
		LobbyProtocol.KEY_RANDOM_SEED,
		LobbyProtocol.KEY_ROUND_ID,
		LobbyProtocol.KEY_RESULTS,
	]
	for key: StringName in required_keys:
		if not payload.has(key):
			return ERR_INVALID_DATA

	var raw_phase: Variant = payload[LobbyProtocol.KEY_PHASE]
	var raw_players: Variant = payload[LobbyProtocol.KEY_PLAYERS]
	var raw_game_id: Variant = payload[LobbyProtocol.KEY_GAME_ID]
	var raw_random_seed: Variant = payload[LobbyProtocol.KEY_RANDOM_SEED]
	var raw_round_id: Variant = payload[LobbyProtocol.KEY_ROUND_ID]
	var raw_results: Variant = payload[LobbyProtocol.KEY_RESULTS]
	if typeof(raw_phase) != TYPE_INT or typeof(raw_players) != TYPE_ARRAY:
		return ERR_INVALID_DATA
	if typeof(raw_game_id) != TYPE_STRING or typeof(raw_random_seed) != TYPE_INT:
		return ERR_INVALID_DATA
	if typeof(raw_round_id) != TYPE_INT or typeof(raw_results) != TYPE_ARRAY:
		return ERR_INVALID_DATA

	var parsed_phase: int = int(raw_phase)
	if parsed_phase < Phase.LOBBY or parsed_phase > Phase.RESULTS:
		return ERR_INVALID_DATA
	var parsed_game_id: StringName = StringName(String(raw_game_id))
	var parsed_random_seed: int = int(raw_random_seed)
	var parsed_round_id: int = int(raw_round_id)
	if parsed_round_id < round_id:
		return ERR_INVALID_DATA
	if parsed_phase == Phase.LOBBY:
		if not parsed_game_id.is_empty() or parsed_random_seed != 0:
			return ERR_INVALID_DATA
	else:
		if parsed_game_id.is_empty() or parsed_random_seed <= 0 or parsed_round_id <= 0:
			return ERR_INVALID_DATA

	var replacement_players: Dictionary[int, SessionPlayer] = {}
	var host_count: int = 0
	var raw_player_array: Array = raw_players as Array
	if raw_player_array.is_empty() or raw_player_array.size() > LobbyProtocol.MAX_PLAYERS:
		return ERR_INVALID_DATA
	for raw_player: Variant in raw_player_array:
		if typeof(raw_player) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var player: SessionPlayer = SessionPlayer.from_payload(raw_player as Dictionary)
		if player == null or replacement_players.has(player.peer_id):
			return ERR_INVALID_DATA
		if player.is_host:
			host_count += 1
			if player.peer_id != LobbyProtocol.SERVER_PEER_ID or not player.is_ready:
				return ERR_INVALID_DATA
		elif player.peer_id == LobbyProtocol.SERVER_PEER_ID:
			return ERR_INVALID_DATA
		replacement_players[player.peer_id] = player
	if host_count != 1:
		return ERR_INVALID_DATA
	if local_peer_id > 0 and not replacement_players.has(local_peer_id):
		return ERR_INVALID_DATA

	var replacement_results: Dictionary[int, MinigamePlayerResult] = {}
	var raw_result_array: Array = raw_results as Array
	if raw_result_array.size() > LobbyProtocol.MAX_PLAYERS:
		return ERR_INVALID_DATA
	for raw_result: Variant in raw_result_array:
		if typeof(raw_result) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var result: MinigamePlayerResult = MinigamePlayerResult.from_payload(
			raw_result as Dictionary
		)
		if result == null or replacement_results.has(result.peer_id):
			return ERR_INVALID_DATA
		var matching_player: SessionPlayer = replacement_players.get(result.peer_id) as SessionPlayer
		if matching_player != null and matching_player.display_name != result.display_name:
			return ERR_INVALID_DATA
		replacement_results[result.peer_id] = result

	if parsed_phase == Phase.LOBBY and not replacement_results.is_empty():
		return ERR_INVALID_DATA
	if parsed_phase != Phase.LOBBY:
		if replacement_results.is_empty():
			return ERR_INVALID_DATA
		for player_id: int in replacement_players:
			if not replacement_results.has(player_id):
				return ERR_INVALID_DATA
	if parsed_phase == Phase.RESULTS:
		var ranked_results: Array[MinigamePlayerResult] = []
		for value: MinigamePlayerResult in replacement_results.values():
			ranked_results.append(value)
		ranked_results.sort_custom(Callable(MinigamePlayerResult, "is_before"))
		var rank_index: int = 0
		while rank_index < ranked_results.size():
			if ranked_results[rank_index].rank != rank_index + 1:
				return ERR_INVALID_DATA
			rank_index += 1
	else:
		for value: MinigamePlayerResult in replacement_results.values():
			if value.rank != 0:
				return ERR_INVALID_DATA

	players_by_peer = replacement_players
	round_results_by_peer = replacement_results
	current_game_id = parsed_game_id
	random_seed = parsed_random_seed
	round_id = parsed_round_id
	_set_phase(parsed_phase)
	players_changed.emit(get_sorted_players())
	results_changed.emit(get_sorted_results())
	return OK


func _set_phase(next_phase: int) -> void:
	if phase == next_phase:
		return
	phase = next_phase
	phase_changed.emit(phase)


func _is_player_before(left: SessionPlayer, right: SessionPlayer) -> bool:
	if left.is_host != right.is_host:
		return left.is_host
	return left.peer_id < right.peer_id
