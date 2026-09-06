## Network-safe per-player progress and final result for one minigame round.
class_name MinigamePlayerResult
extends RefCounted

const MAX_SAFE_SCORE: int = 1000000
const MAX_SAFE_ELAPSED_MS: int = 3600000

const KEY_PEER_ID: StringName = &"peer_id"
const KEY_DISPLAY_NAME: StringName = &"display_name"
const KEY_SCORE: StringName = &"score"
const KEY_ELAPSED_MS: StringName = &"elapsed_ms"
const KEY_IS_COMPLETE: StringName = &"is_complete"
const KEY_IS_WITHDRAWN: StringName = &"is_withdrawn"
const KEY_RANK: StringName = &"rank"

var peer_id: int = 0
var display_name: String = ""
var score: int = 0
var elapsed_ms: int = 0
var is_complete: bool = false
var is_withdrawn: bool = false
var rank: int = 0


func _init(
		initial_peer_id: int = 0,
		initial_display_name: String = "",
		initial_score: int = 0,
		initial_elapsed_ms: int = 0,
		initial_is_complete: bool = false,
		initial_is_withdrawn: bool = false,
		initial_rank: int = 0
) -> void:
	peer_id = initial_peer_id
	display_name = initial_display_name
	score = initial_score
	elapsed_ms = initial_elapsed_ms
	is_complete = initial_is_complete
	is_withdrawn = initial_is_withdrawn
	rank = initial_rank


func duplicate_result() -> MinigamePlayerResult:
	return MinigamePlayerResult.new(
		peer_id,
		display_name,
		score,
		elapsed_ms,
		is_complete,
		is_withdrawn,
		rank
	)


func to_payload() -> Dictionary[StringName, Variant]:
	var payload: Dictionary[StringName, Variant] = {}
	payload[KEY_PEER_ID] = peer_id
	payload[KEY_DISPLAY_NAME] = display_name
	payload[KEY_SCORE] = score
	payload[KEY_ELAPSED_MS] = elapsed_ms
	payload[KEY_IS_COMPLETE] = is_complete
	payload[KEY_IS_WITHDRAWN] = is_withdrawn
	payload[KEY_RANK] = rank
	return payload


## Parses a complete result payload without applying game-specific score rules.
static func from_payload(payload: Dictionary) -> MinigamePlayerResult:
	var required_keys: Array[StringName] = [
		KEY_PEER_ID,
		KEY_DISPLAY_NAME,
		KEY_SCORE,
		KEY_ELAPSED_MS,
		KEY_IS_COMPLETE,
		KEY_IS_WITHDRAWN,
		KEY_RANK,
	]
	for key: StringName in required_keys:
		if not payload.has(key):
			return null

	var raw_peer_id: Variant = payload[KEY_PEER_ID]
	var raw_display_name: Variant = payload[KEY_DISPLAY_NAME]
	var raw_score: Variant = payload[KEY_SCORE]
	var raw_elapsed_ms: Variant = payload[KEY_ELAPSED_MS]
	var raw_is_complete: Variant = payload[KEY_IS_COMPLETE]
	var raw_is_withdrawn: Variant = payload[KEY_IS_WITHDRAWN]
	var raw_rank: Variant = payload[KEY_RANK]
	if typeof(raw_peer_id) != TYPE_INT:
		return null
	if typeof(raw_display_name) != TYPE_STRING:
		return null
	if typeof(raw_score) != TYPE_INT or typeof(raw_elapsed_ms) != TYPE_INT:
		return null
	if typeof(raw_is_complete) != TYPE_BOOL or typeof(raw_is_withdrawn) != TYPE_BOOL:
		return null
	if typeof(raw_rank) != TYPE_INT:
		return null

	var parsed_peer_id: int = int(raw_peer_id)
	var parsed_display_name: String = String(raw_display_name)
	var parsed_score: int = int(raw_score)
	var parsed_elapsed_ms: int = int(raw_elapsed_ms)
	var parsed_rank: int = int(raw_rank)
	if parsed_peer_id <= 0:
		return null
	if parsed_display_name != SessionPlayer.normalize_display_name(parsed_display_name):
		return null
	if SessionPlayer.validate_display_name(parsed_display_name) != OK:
		return null
	if parsed_score < 0 or parsed_score > MAX_SAFE_SCORE:
		return null
	if parsed_elapsed_ms < 0 or parsed_elapsed_ms > MAX_SAFE_ELAPSED_MS:
		return null
	if parsed_rank < 0 or parsed_rank > LobbyProtocol.MAX_PLAYERS:
		return null
	if bool(raw_is_complete) and bool(raw_is_withdrawn):
		return null

	return MinigamePlayerResult.new(
		parsed_peer_id,
		parsed_display_name,
		parsed_score,
		parsed_elapsed_ms,
		bool(raw_is_complete),
		bool(raw_is_withdrawn),
		parsed_rank
	)


## Deterministic result order used by the host and every client.
static func is_before(left: MinigamePlayerResult, right: MinigamePlayerResult) -> bool:
	if left.is_withdrawn != right.is_withdrawn:
		return not left.is_withdrawn
	if left.is_complete != right.is_complete:
		return left.is_complete
	if left.is_complete and left.elapsed_ms != right.elapsed_ms:
		return left.elapsed_ms < right.elapsed_ms
	if not left.is_complete and left.score != right.score:
		return left.score > right.score
	if left.elapsed_ms != right.elapsed_ms:
		return left.elapsed_ms < right.elapsed_ms
	return left.peer_id < right.peer_id
