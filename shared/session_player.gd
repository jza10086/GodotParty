## Runtime player data shared by the lobby and later game scenes.
class_name SessionPlayer
extends RefCounted

const MIN_DISPLAY_NAME_LENGTH: int = 1
const MAX_DISPLAY_NAME_LENGTH: int = 20

const KEY_PEER_ID: StringName = &"peer_id"
const KEY_DISPLAY_NAME: StringName = &"display_name"
const KEY_IS_HOST: StringName = &"is_host"
const KEY_IS_READY: StringName = &"is_ready"

var peer_id: int = 0
var display_name: String = ""
var is_host: bool = false
var is_ready: bool = false


func _init(
		initial_peer_id: int = 0,
		initial_display_name: String = "",
		initial_is_host: bool = false,
		initial_is_ready: bool = false
) -> void:
	peer_id = initial_peer_id
	display_name = initial_display_name
	is_host = initial_is_host
	is_ready = initial_is_ready


static func normalize_display_name(value: String) -> String:
	return value.strip_edges()


## Validates a normalized display name before it enters session state or a network payload.
static func validate_display_name(value: String) -> Error:
	var normalized_name: String = normalize_display_name(value)
	if normalized_name.length() < MIN_DISPLAY_NAME_LENGTH:
		return ERR_INVALID_PARAMETER
	if normalized_name.length() > MAX_DISPLAY_NAME_LENGTH:
		return ERR_INVALID_PARAMETER

	var index: int = 0
	while index < normalized_name.length():
		var codepoint: int = normalized_name.unicode_at(index)
		if codepoint < 32 or codepoint == 127:
			return ERR_INVALID_DATA
		index += 1

	return OK


func to_payload() -> Dictionary[StringName, Variant]:
	var payload: Dictionary[StringName, Variant] = {}
	payload[KEY_PEER_ID] = peer_id
	payload[KEY_DISPLAY_NAME] = display_name
	payload[KEY_IS_HOST] = is_host
	payload[KEY_IS_READY] = is_ready
	return payload


## Creates runtime data only from a complete and valid network-safe dictionary.
static func from_payload(payload: Dictionary) -> SessionPlayer:
	if not payload.has(KEY_PEER_ID):
		return null
	if not payload.has(KEY_DISPLAY_NAME):
		return null
	if not payload.has(KEY_IS_HOST):
		return null
	if not payload.has(KEY_IS_READY):
		return null

	var raw_peer_id: Variant = payload[KEY_PEER_ID]
	var raw_display_name: Variant = payload[KEY_DISPLAY_NAME]
	var raw_is_host: Variant = payload[KEY_IS_HOST]
	var raw_is_ready: Variant = payload[KEY_IS_READY]
	if typeof(raw_peer_id) != TYPE_INT:
		return null
	if typeof(raw_display_name) != TYPE_STRING:
		return null
	if typeof(raw_is_host) != TYPE_BOOL:
		return null
	if typeof(raw_is_ready) != TYPE_BOOL:
		return null

	var parsed_peer_id: int = int(raw_peer_id)
	var parsed_display_name: String = String(raw_display_name)
	if parsed_peer_id <= 0:
		return null
	if parsed_display_name != normalize_display_name(parsed_display_name):
		return null
	if validate_display_name(parsed_display_name) != OK:
		return null

	return SessionPlayer.new(
		parsed_peer_id,
		parsed_display_name,
		bool(raw_is_host),
		bool(raw_is_ready)
	)
