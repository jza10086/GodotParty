## Stable lobby protocol constants and boundary validation shared by networking and tests.
class_name LobbyProtocol
extends RefCounted

const PROTOCOL_VERSION: int = 1
const SERVER_PEER_ID: int = 1
const DEFAULT_ADDRESS: String = "127.0.0.1"
const DEFAULT_PORT: int = 7000
const MIN_PORT: int = 1024
const MAX_PORT: int = 65535
const MAX_PLAYERS: int = 8
const MAX_REMOTE_CLIENTS: int = MAX_PLAYERS - 1
const PLACEHOLDER_GAME_ID: String = "placeholder"

const KEY_PROTOCOL_VERSION: StringName = &"protocol_version"
const KEY_DISPLAY_NAME: StringName = &"display_name"
const KEY_PHASE: StringName = &"phase"
const KEY_PLAYERS: StringName = &"players"
const KEY_GAME_ID: StringName = &"game_id"
const KEY_RANDOM_SEED: StringName = &"random_seed"


static func validate_port(port: int) -> Error:
	if port < MIN_PORT or port > MAX_PORT:
		return ERR_INVALID_PARAMETER
	return OK


static func validate_address(address: String) -> Error:
	var normalized_address: String = address.strip_edges()
	if normalized_address.is_empty() or normalized_address.length() > 253:
		return ERR_INVALID_PARAMETER

	var index: int = 0
	while index < normalized_address.length():
		var codepoint: int = normalized_address.unicode_at(index)
		if codepoint < 32 or codepoint == 127:
			return ERR_INVALID_DATA
		index += 1

	return OK


static func make_registration_payload(display_name: String) -> Dictionary[StringName, Variant]:
	var payload: Dictionary[StringName, Variant] = {}
	payload[KEY_PROTOCOL_VERSION] = PROTOCOL_VERSION
	payload[KEY_DISPLAY_NAME] = SessionPlayer.normalize_display_name(display_name)
	return payload


static func validate_protocol_version(payload: Dictionary) -> Error:
	if not payload.has(KEY_PROTOCOL_VERSION):
		return ERR_INVALID_DATA
	var raw_version: Variant = payload[KEY_PROTOCOL_VERSION]
	if typeof(raw_version) != TYPE_INT:
		return ERR_INVALID_DATA
	if int(raw_version) != PROTOCOL_VERSION:
		return ERR_UNAVAILABLE
	return OK


static func validate_registration_payload(payload: Dictionary) -> Error:
	var version_error: Error = validate_protocol_version(payload)
	if version_error != OK:
		return version_error
	if not payload.has(KEY_DISPLAY_NAME):
		return ERR_INVALID_DATA
	var raw_display_name: Variant = payload[KEY_DISPLAY_NAME]
	if typeof(raw_display_name) != TYPE_STRING:
		return ERR_INVALID_DATA
	var display_name: String = String(raw_display_name)
	if display_name != SessionPlayer.normalize_display_name(display_name):
		return ERR_INVALID_DATA
	return SessionPlayer.validate_display_name(display_name)
