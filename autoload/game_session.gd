## Holds mutable cross-scene session state. NetworkManager is its only authoritative writer.
class_name GameSessionState
extends Node

signal players_changed(players: Array[SessionPlayer])
signal phase_changed(phase: int)
signal results_changed(results: Array[MinigamePlayerResult])
signal playlist_changed()
signal standings_changed(standings: Array[PartyStanding])

enum Phase {
	OFFLINE,
	LOBBY,
	LOADING_GAME,
	COUNTDOWN,
	PLAYING,
	INTERMISSION,
	SESSION_RESULTS,
}

var players_by_peer: Dictionary[int, SessionPlayer] = {}
var round_results_by_peer: Dictionary[int, MinigamePlayerResult] = {}
var standings_by_peer: Dictionary[int, PartyStanding] = {}
var playlist_config: PartyPlaylistConfig = PartyPlaylistConfig.new()
var playlist_game_ids: Array[StringName] = []
var current_round_index: int = -1
var intermission_paused: bool = false
var local_peer_id: int = 0
var local_is_host: bool = false
var phase: int = Phase.OFFLINE
var current_game_id: StringName = &""
var random_seed: int = 0
var round_id: int = 0


func begin_session(peer_id: int, is_host: bool) -> void:
	players_by_peer.clear()
	round_results_by_peer.clear()
	standings_by_peer.clear()
	playlist_config = PartyPlaylistConfig.new()
	playlist_game_ids.clear()
	current_round_index = -1
	intermission_paused = false
	local_peer_id = peer_id
	local_is_host = is_host
	current_game_id = &""
	random_seed = 0
	round_id = 0
	_set_phase(Phase.LOBBY)
	_emit_all_changed()


func reset_session() -> void:
	players_by_peer.clear()
	round_results_by_peer.clear()
	standings_by_peer.clear()
	playlist_config = PartyPlaylistConfig.new()
	playlist_game_ids.clear()
	current_round_index = -1
	intermission_paused = false
	local_peer_id = 0
	local_is_host = false
	current_game_id = &""
	random_seed = 0
	round_id = 0
	_set_phase(Phase.OFFLINE)
	_emit_all_changed()


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


func set_playlist_config(config: PartyPlaylistConfig) -> Error:
	if config == null:
		return ERR_INVALID_PARAMETER
	playlist_config = config.duplicate_config()
	playlist_changed.emit()
	return OK


func begin_playlist(schedule: Array[StringName]) -> Error:
	if phase != Phase.LOBBY or schedule.size() != playlist_config.total_rounds:
		return ERR_INVALID_PARAMETER
	for game_id: StringName in schedule:
		if not playlist_config.selected_game_ids.has(game_id):
			return ERR_INVALID_DATA
	playlist_game_ids = schedule.duplicate()
	current_round_index = -1
	standings_by_peer.clear()
	for player: SessionPlayer in get_sorted_players():
		standings_by_peer[player.peer_id] = PartyStanding.new(player.peer_id, player.display_name)
	intermission_paused = false
	playlist_changed.emit()
	standings_changed.emit(get_sorted_standings())
	return OK


func begin_next_round(random_seed_value: int) -> Error:
	var next_index: int = current_round_index + 1
	if next_index < 0 or next_index >= playlist_game_ids.size() or random_seed_value <= 0:
		return ERR_INVALID_PARAMETER
	current_round_index = next_index
	round_id += 1
	current_game_id = playlist_game_ids[current_round_index]
	random_seed = random_seed_value
	intermission_paused = false
	round_results_by_peer.clear()
	for player: SessionPlayer in get_sorted_players():
		round_results_by_peer[player.peer_id] = MinigamePlayerResult.new(
			player.peer_id,
			player.display_name
		)
	_set_phase(Phase.LOADING_GAME)
	results_changed.emit(get_sorted_results())
	playlist_changed.emit()
	return OK


func set_round_phase(next_phase: int) -> Error:
	if next_phase < Phase.LOADING_GAME or next_phase > Phase.PLAYING:
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
	if result != null:
		result.is_withdrawn = true
		result.rank = 0
		results_changed.emit(get_sorted_results())
	var standing: PartyStanding = standings_by_peer.get(peer_id) as PartyStanding
	if standing != null:
		standing.is_withdrawn = true
		_update_standing_ranks()


func are_all_active_results_complete() -> bool:
	var has_active_player: bool = false
	for result: MinigamePlayerResult in get_sorted_results():
		if result.is_withdrawn:
			continue
		has_active_player = true
		if not result.is_complete:
			return false
	return has_active_player


func finalize_round_results(ranking_mode: int) -> Error:
	if phase != Phase.PLAYING:
		return ERR_INVALID_DATA
	var sorted_results: Array[MinigamePlayerResult] = get_sorted_results()
	if ranking_mode == MinigameDefinition.RankingMode.COMPETITION_SCORE:
		sorted_results.sort_custom(Callable(self, "_is_competition_result_before"))
		_assign_competition_result_ranks(sorted_results)
	else:
		sorted_results.sort_custom(Callable(MinigamePlayerResult, "is_before"))
		for index: int in range(sorted_results.size()):
			sorted_results[index].rank = index + 1
	for result: MinigamePlayerResult in sorted_results:
		round_results_by_peer[result.peer_id] = result.duplicate_result()
		var standing: PartyStanding = standings_by_peer.get(result.peer_id) as PartyStanding
		if standing != null:
			standing.points += _points_for_rank(result.rank)
	_update_standing_ranks()
	if current_round_index + 1 >= playlist_game_ids.size():
		_set_phase(Phase.SESSION_RESULTS)
	else:
		_set_phase(Phase.INTERMISSION)
	results_changed.emit(get_sorted_results())
	playlist_changed.emit()
	return OK


func set_intermission_paused(paused: bool) -> Error:
	if phase != Phase.INTERMISSION:
		return ERR_INVALID_DATA
	intermission_paused = paused
	playlist_changed.emit()
	return OK


func return_to_lobby() -> void:
	for player: SessionPlayer in get_sorted_players():
		if not player.is_host:
			player.is_ready = false
	round_results_by_peer.clear()
	standings_by_peer.clear()
	playlist_game_ids.clear()
	current_round_index = -1
	intermission_paused = false
	current_game_id = &""
	random_seed = 0
	_set_phase(Phase.LOBBY)
	_emit_all_changed()


func get_local_player() -> SessionPlayer:
	return players_by_peer.get(local_peer_id) as SessionPlayer


func get_round_result(peer_id: int) -> MinigamePlayerResult:
	return round_results_by_peer.get(peer_id) as MinigamePlayerResult


func get_sorted_players() -> Array[SessionPlayer]:
	var players: Array[SessionPlayer] = []
	for value: Variant in players_by_peer.values():
		var player: SessionPlayer = value as SessionPlayer
		if player != null:
			players.append(player)
	players.sort_custom(Callable(self, "_is_player_before"))
	return players


func get_sorted_results() -> Array[MinigamePlayerResult]:
	var results: Array[MinigamePlayerResult] = []
	for value: Variant in round_results_by_peer.values():
		var result: MinigamePlayerResult = value as MinigamePlayerResult
		if result != null:
			results.append(result.duplicate_result())
	results.sort_custom(Callable(MinigamePlayerResult, "is_before"))
	return results


func get_sorted_standings() -> Array[PartyStanding]:
	var standings: Array[PartyStanding] = []
	for value: Variant in standings_by_peer.values():
		var standing: PartyStanding = value as PartyStanding
		if standing != null:
			standings.append(standing.duplicate_standing())
	standings.sort_custom(Callable(PartyStanding, "is_before"))
	return standings


func can_host_start() -> bool:
	if not local_is_host or phase != Phase.LOBBY or players_by_peer.size() < 2:
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
	for result: MinigamePlayerResult in get_ranked_results_for_display():
		result_payloads.append(result.to_payload())
	var standing_payloads: Array[Dictionary] = []
	for standing: PartyStanding in get_sorted_standings():
		standing_payloads.append(standing.to_payload())
	var schedule_payload: Array[String] = []
	for game_id: StringName in playlist_game_ids:
		schedule_payload.append(String(game_id))
	var snapshot: Dictionary[StringName, Variant] = {}
	snapshot[LobbyProtocol.KEY_PROTOCOL_VERSION] = LobbyProtocol.PROTOCOL_VERSION
	snapshot[LobbyProtocol.KEY_PHASE] = phase
	snapshot[LobbyProtocol.KEY_PLAYERS] = player_payloads
	snapshot[LobbyProtocol.KEY_GAME_ID] = String(current_game_id)
	snapshot[LobbyProtocol.KEY_RANDOM_SEED] = random_seed
	snapshot[LobbyProtocol.KEY_ROUND_ID] = round_id
	snapshot[LobbyProtocol.KEY_RESULTS] = result_payloads
	snapshot[LobbyProtocol.KEY_PLAYLIST_CONFIG] = playlist_config.to_payload()
	snapshot[LobbyProtocol.KEY_PLAYLIST_GAMES] = schedule_payload
	snapshot[LobbyProtocol.KEY_CURRENT_ROUND_INDEX] = current_round_index
	snapshot[LobbyProtocol.KEY_STANDINGS] = standing_payloads
	snapshot[LobbyProtocol.KEY_INTERMISSION_PAUSED] = intermission_paused
	return snapshot


func get_ranked_results_for_display() -> Array[MinigamePlayerResult]:
	var results: Array[MinigamePlayerResult] = get_sorted_results()
	if phase == Phase.INTERMISSION or phase == Phase.SESSION_RESULTS:
		results.sort_custom(Callable(self, "_is_ranked_result_before"))
	return results


## Replaces state atomically after validating the complete authoritative snapshot.
func replace_from_snapshot(payload: Dictionary) -> Error:
	if LobbyProtocol.validate_protocol_version(payload) != OK:
		return ERR_UNAVAILABLE
	var keys: Array[StringName] = [
		LobbyProtocol.KEY_PHASE, LobbyProtocol.KEY_PLAYERS, LobbyProtocol.KEY_GAME_ID,
		LobbyProtocol.KEY_RANDOM_SEED, LobbyProtocol.KEY_ROUND_ID, LobbyProtocol.KEY_RESULTS,
		LobbyProtocol.KEY_PLAYLIST_CONFIG, LobbyProtocol.KEY_PLAYLIST_GAMES,
		LobbyProtocol.KEY_CURRENT_ROUND_INDEX, LobbyProtocol.KEY_STANDINGS,
		LobbyProtocol.KEY_INTERMISSION_PAUSED,
	]
	for key: StringName in keys:
		if not payload.has(key):
			return ERR_INVALID_DATA
	if (
		typeof(payload[LobbyProtocol.KEY_PHASE]) != TYPE_INT
		or typeof(payload[LobbyProtocol.KEY_PLAYERS]) != TYPE_ARRAY
		or typeof(payload[LobbyProtocol.KEY_GAME_ID]) != TYPE_STRING
		or typeof(payload[LobbyProtocol.KEY_RANDOM_SEED]) != TYPE_INT
		or typeof(payload[LobbyProtocol.KEY_ROUND_ID]) != TYPE_INT
		or typeof(payload[LobbyProtocol.KEY_RESULTS]) != TYPE_ARRAY
		or typeof(payload[LobbyProtocol.KEY_PLAYLIST_CONFIG]) != TYPE_DICTIONARY
		or typeof(payload[LobbyProtocol.KEY_PLAYLIST_GAMES]) != TYPE_ARRAY
		or typeof(payload[LobbyProtocol.KEY_CURRENT_ROUND_INDEX]) != TYPE_INT
		or typeof(payload[LobbyProtocol.KEY_STANDINGS]) != TYPE_ARRAY
		or typeof(payload[LobbyProtocol.KEY_INTERMISSION_PAUSED]) != TYPE_BOOL
	):
		return ERR_INVALID_DATA
	var parsed_phase: int = int(payload[LobbyProtocol.KEY_PHASE])
	var parsed_round_id: int = int(payload[LobbyProtocol.KEY_ROUND_ID])
	if parsed_phase < Phase.LOBBY or parsed_phase > Phase.SESSION_RESULTS:
		return ERR_INVALID_DATA
	if parsed_round_id < round_id:
		return ERR_INVALID_DATA
	var parsed_config: PartyPlaylistConfig = PartyPlaylistConfig.from_payload(
		payload[LobbyProtocol.KEY_PLAYLIST_CONFIG] as Dictionary
	)
	if parsed_config == null:
		return ERR_INVALID_DATA
	var config_ids: Array[StringName] = parsed_config.selected_game_ids.duplicate()
	if parsed_config.validate(config_ids) != OK:
		return ERR_INVALID_DATA
	var parsed_players: Dictionary[int, SessionPlayer] = {}
	var host_count: int = 0
	for raw_player: Variant in payload[LobbyProtocol.KEY_PLAYERS] as Array:
		if typeof(raw_player) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var player: SessionPlayer = SessionPlayer.from_payload(raw_player as Dictionary)
		if player == null or parsed_players.has(player.peer_id):
			return ERR_INVALID_DATA
		if player.is_host:
			host_count += 1
		parsed_players[player.peer_id] = player
	if host_count != 1 or parsed_players.is_empty() or parsed_players.size() > LobbyProtocol.MAX_PLAYERS:
		return ERR_INVALID_DATA
	if local_peer_id > 0 and not parsed_players.has(local_peer_id):
		return ERR_INVALID_DATA
	var parsed_schedule: Array[StringName] = []
	for raw_game_id: Variant in payload[LobbyProtocol.KEY_PLAYLIST_GAMES] as Array:
		if typeof(raw_game_id) != TYPE_STRING:
			return ERR_INVALID_DATA
		parsed_schedule.append(StringName(String(raw_game_id)))
	var parsed_index: int = int(payload[LobbyProtocol.KEY_CURRENT_ROUND_INDEX])
	var parsed_game_id: StringName = StringName(String(payload[LobbyProtocol.KEY_GAME_ID]))
	var parsed_seed: int = int(payload[LobbyProtocol.KEY_RANDOM_SEED])
	if parsed_phase == Phase.LOBBY:
		if not parsed_schedule.is_empty() or parsed_index != -1 or not parsed_game_id.is_empty() or parsed_seed != 0:
			return ERR_INVALID_DATA
	else:
		if (
			parsed_schedule.size() != parsed_config.total_rounds
			or parsed_index < 0
			or parsed_index >= parsed_schedule.size()
			or parsed_schedule[parsed_index] != parsed_game_id
			or parsed_seed <= 0
			or parsed_round_id <= 0
		):
			return ERR_INVALID_DATA
	var parsed_results: Dictionary[int, MinigamePlayerResult] = {}
	for raw_result: Variant in payload[LobbyProtocol.KEY_RESULTS] as Array:
		if typeof(raw_result) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var result: MinigamePlayerResult = MinigamePlayerResult.from_payload(raw_result as Dictionary)
		if result == null or parsed_results.has(result.peer_id):
			return ERR_INVALID_DATA
		parsed_results[result.peer_id] = result
	var parsed_standings: Dictionary[int, PartyStanding] = {}
	for raw_standing: Variant in payload[LobbyProtocol.KEY_STANDINGS] as Array:
		if typeof(raw_standing) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var standing: PartyStanding = PartyStanding.from_payload(raw_standing as Dictionary)
		if standing == null or parsed_standings.has(standing.peer_id):
			return ERR_INVALID_DATA
		parsed_standings[standing.peer_id] = standing
	if parsed_phase == Phase.LOBBY:
		if not parsed_results.is_empty() or not parsed_standings.is_empty():
			return ERR_INVALID_DATA
	else:
		if parsed_results.is_empty() or parsed_standings.is_empty():
			return ERR_INVALID_DATA
	players_by_peer = parsed_players
	round_results_by_peer = parsed_results
	standings_by_peer = parsed_standings
	playlist_config = parsed_config
	playlist_game_ids = parsed_schedule
	current_round_index = parsed_index
	current_game_id = parsed_game_id
	random_seed = parsed_seed
	round_id = parsed_round_id
	intermission_paused = bool(payload[LobbyProtocol.KEY_INTERMISSION_PAUSED])
	_set_phase(parsed_phase)
	_emit_all_changed()
	return OK


func _assign_competition_result_ranks(results: Array[MinigamePlayerResult]) -> void:
	var previous: MinigamePlayerResult = null
	for index: int in range(results.size()):
		var result: MinigamePlayerResult = results[index]
		if (
			previous != null
			and previous.is_withdrawn == result.is_withdrawn
			and previous.score == result.score
		):
			result.rank = previous.rank
		else:
			result.rank = index + 1
		previous = result


func _update_standing_ranks() -> void:
	var standings: Array[PartyStanding] = get_sorted_standings()
	var previous: PartyStanding = null
	for index: int in range(standings.size()):
		var standing: PartyStanding = standings[index]
		if (
			previous != null
			and previous.points == standing.points
			and previous.is_withdrawn == standing.is_withdrawn
		):
			standing.rank = previous.rank
		else:
			standing.rank = index + 1
		standings_by_peer[standing.peer_id] = standing
		previous = standing
	standings_changed.emit(get_sorted_standings())


func _points_for_rank(rank: int) -> int:
	if rank == 1:
		return 3
	if rank == 2:
		return 2
	if rank == 3:
		return 1
	return 0


func _is_ranked_result_before(left: MinigamePlayerResult, right: MinigamePlayerResult) -> bool:
	if left.rank != right.rank:
		return left.rank < right.rank
	return left.peer_id < right.peer_id


func _is_competition_result_before(
		left: MinigamePlayerResult,
		right: MinigamePlayerResult
) -> bool:
	if left.is_withdrawn != right.is_withdrawn:
		return not left.is_withdrawn
	if left.score != right.score:
		return left.score > right.score
	return left.peer_id < right.peer_id


func _is_player_before(left: SessionPlayer, right: SessionPlayer) -> bool:
	if left.is_host != right.is_host:
		return left.is_host
	return left.peer_id < right.peer_id


func _emit_all_changed() -> void:
	players_changed.emit(get_sorted_players())
	results_changed.emit(get_ranked_results_for_display())
	playlist_changed.emit()
	standings_changed.emit(get_sorted_standings())


func _set_phase(next_phase: int) -> void:
	if phase == next_phase:
		return
	phase = next_phase
	phase_changed.emit(phase)
