## Serializable host-owned rules for one continuous minigame session.
class_name PartyPlaylistConfig
extends RefCounted

enum OrderMode {
	RANDOM,
	SEQUENTIAL,
}

enum RepeatPolicy {
	NO_CONSECUTIVE,
	ONCE_ONLY,
}

const MIN_ROUNDS: int = 1
const MAX_ROUNDS: int = 99
const MIN_INTERMISSION_SECONDS: int = 1
const MAX_INTERMISSION_SECONDS: int = 60

const KEY_TOTAL_ROUNDS: StringName = &"total_rounds"
const KEY_INTERMISSION_SECONDS: StringName = &"intermission_seconds"
const KEY_ORDER_MODE: StringName = &"order_mode"
const KEY_REPEAT_POLICY: StringName = &"repeat_policy"
const KEY_SELECTED_GAME_IDS: StringName = &"selected_game_ids"

var total_rounds: int = 5
var intermission_seconds: int = 5
var order_mode: int = OrderMode.RANDOM
var repeat_policy: int = RepeatPolicy.NO_CONSECUTIVE
var selected_game_ids: Array[StringName] = []


func duplicate_config() -> PartyPlaylistConfig:
	var copy: PartyPlaylistConfig = PartyPlaylistConfig.new()
	copy.total_rounds = total_rounds
	copy.intermission_seconds = intermission_seconds
	copy.order_mode = order_mode
	copy.repeat_policy = repeat_policy
	copy.selected_game_ids = selected_game_ids.duplicate()
	return copy


func normalize() -> void:
	total_rounds = clampi(total_rounds, MIN_ROUNDS, MAX_ROUNDS)
	intermission_seconds = clampi(
		intermission_seconds,
		MIN_INTERMISSION_SECONDS,
		MAX_INTERMISSION_SECONDS
	)
	if repeat_policy == RepeatPolicy.ONCE_ONLY and total_rounds > selected_game_ids.size():
		repeat_policy = RepeatPolicy.NO_CONSECUTIVE


func validate(available_game_ids: Array[StringName]) -> Error:
	if total_rounds < MIN_ROUNDS or total_rounds > MAX_ROUNDS:
		return ERR_INVALID_PARAMETER
	if (
		intermission_seconds < MIN_INTERMISSION_SECONDS
		or intermission_seconds > MAX_INTERMISSION_SECONDS
	):
		return ERR_INVALID_PARAMETER
	if order_mode < OrderMode.RANDOM or order_mode > OrderMode.SEQUENTIAL:
		return ERR_INVALID_PARAMETER
	if repeat_policy < RepeatPolicy.NO_CONSECUTIVE or repeat_policy > RepeatPolicy.ONCE_ONLY:
		return ERR_INVALID_PARAMETER
	if selected_game_ids.is_empty():
		return ERR_DOES_NOT_EXIST
	var seen_ids: Dictionary[StringName, bool] = {}
	for game_id: StringName in selected_game_ids:
		if game_id.is_empty() or not available_game_ids.has(game_id) or seen_ids.has(game_id):
			return ERR_INVALID_DATA
		seen_ids[game_id] = true
	if repeat_policy == RepeatPolicy.ONCE_ONLY and total_rounds > selected_game_ids.size():
		return ERR_INVALID_PARAMETER
	return OK


func validate_for_start(available_game_ids: Array[StringName]) -> Error:
	var validation_error: Error = validate(available_game_ids)
	if validation_error != OK:
		return validation_error
	if (
		repeat_policy == RepeatPolicy.NO_CONSECUTIVE
		and total_rounds > 1
		and selected_game_ids.size() == 1
	):
		return ERR_INVALID_PARAMETER
	return OK


func build_schedule(random_seed_value: int) -> Array[StringName]:
	var schedule: Array[StringName] = []
	if random_seed_value <= 0 or selected_game_ids.is_empty():
		return schedule
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = random_seed_value
	if repeat_policy == RepeatPolicy.ONCE_ONLY:
		var candidates: Array[StringName] = selected_game_ids.duplicate()
		if order_mode == OrderMode.RANDOM:
			_shuffle(candidates, random)
		for index: int in range(total_rounds):
			schedule.append(candidates[index])
		return schedule
	if order_mode == OrderMode.SEQUENTIAL:
		for index: int in range(total_rounds):
			schedule.append(selected_game_ids[index % selected_game_ids.size()])
		return schedule
	var previous_id: StringName = &""
	for _round_index: int in range(total_rounds):
		var choices: Array[StringName] = []
		for game_id: StringName in selected_game_ids:
			if game_id != previous_id:
				choices.append(game_id)
		var selected_index: int = random.randi_range(0, choices.size() - 1)
		previous_id = choices[selected_index]
		schedule.append(previous_id)
	return schedule


func to_payload() -> Dictionary[StringName, Variant]:
	var game_ids: Array[String] = []
	for game_id: StringName in selected_game_ids:
		game_ids.append(String(game_id))
	var payload: Dictionary[StringName, Variant] = {}
	payload[KEY_TOTAL_ROUNDS] = total_rounds
	payload[KEY_INTERMISSION_SECONDS] = intermission_seconds
	payload[KEY_ORDER_MODE] = order_mode
	payload[KEY_REPEAT_POLICY] = repeat_policy
	payload[KEY_SELECTED_GAME_IDS] = game_ids
	return payload


static func from_payload(payload: Dictionary) -> PartyPlaylistConfig:
	var required_keys: Array[StringName] = [
		KEY_TOTAL_ROUNDS,
		KEY_INTERMISSION_SECONDS,
		KEY_ORDER_MODE,
		KEY_REPEAT_POLICY,
		KEY_SELECTED_GAME_IDS,
	]
	for key: StringName in required_keys:
		if not payload.has(key):
			return null
	if (
		typeof(payload[KEY_TOTAL_ROUNDS]) != TYPE_INT
		or typeof(payload[KEY_INTERMISSION_SECONDS]) != TYPE_INT
		or typeof(payload[KEY_ORDER_MODE]) != TYPE_INT
		or typeof(payload[KEY_REPEAT_POLICY]) != TYPE_INT
		or typeof(payload[KEY_SELECTED_GAME_IDS]) != TYPE_ARRAY
	):
		return null
	var config: PartyPlaylistConfig = PartyPlaylistConfig.new()
	config.total_rounds = int(payload[KEY_TOTAL_ROUNDS])
	config.intermission_seconds = int(payload[KEY_INTERMISSION_SECONDS])
	config.order_mode = int(payload[KEY_ORDER_MODE])
	config.repeat_policy = int(payload[KEY_REPEAT_POLICY])
	var raw_ids: Array = payload[KEY_SELECTED_GAME_IDS] as Array
	for raw_id: Variant in raw_ids:
		if typeof(raw_id) != TYPE_STRING:
			return null
		config.selected_game_ids.append(StringName(String(raw_id)))
	return config


static func _shuffle(values: Array[StringName], random: RandomNumberGenerator) -> void:
	var index: int = values.size() - 1
	while index > 0:
		var swap_index: int = random.randi_range(0, index)
		var temporary: StringName = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary
		index -= 1
