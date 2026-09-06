## Network-safe cumulative score for one participant in a playlist session.
class_name PartyStanding
extends RefCounted

const KEY_PEER_ID: StringName = &"peer_id"
const KEY_DISPLAY_NAME: StringName = &"display_name"
const KEY_POINTS: StringName = &"points"
const KEY_IS_WITHDRAWN: StringName = &"is_withdrawn"
const KEY_RANK: StringName = &"rank"

var peer_id: int = 0
var display_name: String = ""
var points: int = 0
var is_withdrawn: bool = false
var rank: int = 0


func _init(
		initial_peer_id: int = 0,
		initial_display_name: String = "",
		initial_points: int = 0,
		initial_is_withdrawn: bool = false,
		initial_rank: int = 0
) -> void:
	peer_id = initial_peer_id
	display_name = initial_display_name
	points = initial_points
	is_withdrawn = initial_is_withdrawn
	rank = initial_rank


func duplicate_standing() -> PartyStanding:
	return PartyStanding.new(peer_id, display_name, points, is_withdrawn, rank)


func to_payload() -> Dictionary[StringName, Variant]:
	var payload: Dictionary[StringName, Variant] = {}
	payload[KEY_PEER_ID] = peer_id
	payload[KEY_DISPLAY_NAME] = display_name
	payload[KEY_POINTS] = points
	payload[KEY_IS_WITHDRAWN] = is_withdrawn
	payload[KEY_RANK] = rank
	return payload


static func from_payload(payload: Dictionary) -> PartyStanding:
	var required_keys: Array[StringName] = [
		KEY_PEER_ID,
		KEY_DISPLAY_NAME,
		KEY_POINTS,
		KEY_IS_WITHDRAWN,
		KEY_RANK,
	]
	for key: StringName in required_keys:
		if not payload.has(key):
			return null
	if (
		typeof(payload[KEY_PEER_ID]) != TYPE_INT
		or typeof(payload[KEY_DISPLAY_NAME]) != TYPE_STRING
		or typeof(payload[KEY_POINTS]) != TYPE_INT
		or typeof(payload[KEY_IS_WITHDRAWN]) != TYPE_BOOL
		or typeof(payload[KEY_RANK]) != TYPE_INT
	):
		return null
	var parsed: PartyStanding = PartyStanding.new(
		int(payload[KEY_PEER_ID]),
		String(payload[KEY_DISPLAY_NAME]),
		int(payload[KEY_POINTS]),
		bool(payload[KEY_IS_WITHDRAWN]),
		int(payload[KEY_RANK])
	)
	if parsed.peer_id <= 0 or parsed.points < 0 or parsed.rank < 0:
		return null
	if SessionPlayer.validate_display_name(parsed.display_name) != OK:
		return null
	return parsed


static func is_before(left: PartyStanding, right: PartyStanding) -> bool:
	if left.is_withdrawn != right.is_withdrawn:
		return not left.is_withdrawn
	if left.points != right.points:
		return left.points > right.points
	return left.peer_id < right.peer_id
