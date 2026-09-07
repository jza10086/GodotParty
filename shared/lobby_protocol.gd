## Stable session protocol constants and boundary validation shared by networking and tests.
class_name LobbyProtocol
extends RefCounted

const PROTOCOL_VERSION: int = 3
const SERVER_PEER_ID: int = 1
const DEFAULT_ADDRESS: String = "127.0.0.1"
const DEFAULT_BIND_ADDRESS: String = "*"
const IPV4_ANY_ADDRESS: String = "0.0.0.0"
const IPV6_ANY_ADDRESS: String = "::"
const DEFAULT_PORT: int = 7000
const MIN_PORT: int = 1024
const MAX_PORT: int = 65535
const MAX_PLAYERS: int = 8
const MAX_REMOTE_CLIENTS: int = MAX_PLAYERS - 1
const MAX_ACTION_ID_LENGTH: int = 64
const MAX_ACTION_PAYLOAD_FIELDS: int = 16
const TARGET_CLICK_GAME_ID: StringName = &"target_click"
const TARGET_RACE_GAME_ID: StringName = &"target_race"
const TARGET_HIT_ACTION: StringName = &"target_hit"

const KEY_PROTOCOL_VERSION: StringName = &"protocol_version"
const KEY_DISPLAY_NAME: StringName = &"display_name"
const KEY_PHASE: StringName = &"phase"
const KEY_PLAYERS: StringName = &"players"
const KEY_GAME_ID: StringName = &"game_id"
const KEY_RANDOM_SEED: StringName = &"random_seed"
const KEY_ROUND_ID: StringName = &"round_id"
const KEY_RESULTS: StringName = &"results"
const KEY_PLAYLIST_CONFIG: StringName = &"playlist_config"
const KEY_PLAYLIST_GAMES: StringName = &"playlist_games"
const KEY_CURRENT_ROUND_INDEX: StringName = &"current_round_index"
const KEY_STANDINGS: StringName = &"standings"
const KEY_INTERMISSION_PAUSED: StringName = &"intermission_paused"
const KEY_HIT_INDEX: StringName = &"hit_index"
const KEY_ELAPSED_MS: StringName = &"elapsed_ms"


static func validate_port(port: int) -> Error:
	if port < MIN_PORT or port > MAX_PORT:
		return ERR_INVALID_PARAMETER
	return OK


## Removes whitespace around an address and one valid pair of IPv6 brackets.
static func normalize_connection_address(address: String) -> String:
	var normalized_address: String = address.strip_edges()
	if normalized_address.begins_with("[") and normalized_address.ends_with("]"):
		if normalized_address.count("[") == 1 and normalized_address.count("]") == 1:
			return normalized_address.substr(1, normalized_address.length() - 2)
	return normalized_address


## Accepts connectable IPv4, public IPv6, ::1, localhost, and ordinary DNS names.
static func validate_address(address: String) -> Error:
	var normalized_address: String = normalize_connection_address(address)
	if normalized_address.is_empty() or normalized_address.length() > 253:
		return ERR_INVALID_PARAMETER
	if _contains_control_or_whitespace(normalized_address):
		return ERR_INVALID_DATA
	if (
		normalized_address.contains("://")
		or normalized_address.contains("/")
		or normalized_address.contains("\\")
		or normalized_address.contains("[")
		or normalized_address.contains("]")
	):
		return ERR_INVALID_DATA
	if normalized_address.is_valid_ip_address():
		if normalized_address.contains(":"):
			return (
				OK
				if is_supported_ipv6_address(normalized_address)
				else ERR_UNAVAILABLE
			)
		return (
			OK
			if is_supported_ipv4_address(normalized_address)
			else ERR_UNAVAILABLE
		)
	if normalized_address.contains(":"):
		return ERR_INVALID_DATA
	return OK if _is_valid_hostname(normalized_address) else ERR_INVALID_DATA


## Accepts ENet wildcard binds plus exact local addresses in the supported ranges.
static func validate_bind_address(bind_address: String) -> Error:
	var normalized_address: String = normalize_connection_address(bind_address)
	if normalized_address == DEFAULT_BIND_ADDRESS:
		return OK
	if normalized_address == IPV4_ANY_ADDRESS or normalized_address == IPV6_ANY_ADDRESS:
		return OK
	if not normalized_address.is_valid_ip_address():
		return ERR_INVALID_DATA
	if normalized_address.contains(":"):
		return (
			OK
			if is_supported_ipv6_address(normalized_address)
			else ERR_UNAVAILABLE
		)
	return (
		OK
		if is_supported_ipv4_address(normalized_address)
		else ERR_UNAVAILABLE
	)


static func is_supported_ipv4_address(address: String) -> bool:
	if not address.is_valid_ip_address() or address.contains(":"):
		return false
	var octets: PackedStringArray = address.split(".")
	if octets.size() != 4:
		return false
	var first: int = int(octets[0])
	var second: int = int(octets[1])
	if first == 0 or first >= 224:
		return false
	if first == 169 and second == 254:
		return false
	return true


## The first release permits global unicast IPv6 plus ::1 for local testing.
static func is_supported_ipv6_address(address: String) -> bool:
	var normalized_address: String = normalize_connection_address(address).to_lower()
	if not normalized_address.is_valid_ip_address() or not normalized_address.contains(":"):
		return false
	if normalized_address == "::1":
		return true
	return normalized_address.begins_with("2") or normalized_address.begins_with("3")


## Returns whether an IPv4 address is a globally routable sharing candidate.
static func is_public_ipv4_address(address: String) -> bool:
	if not is_supported_ipv4_address(address):
		return false
	var octets: PackedStringArray = address.split(".")
	var first: int = int(octets[0])
	var second: int = int(octets[1])
	var third: int = int(octets[2])
	if first == 10 or first == 127:
		return false
	if first == 100 and second >= 64 and second <= 127:
		return false
	if first == 172 and second >= 16 and second <= 31:
		return false
	if first == 192 and second == 168:
		return false
	if first == 192 and second == 0 and third == 0:
		return false
	if first == 192 and second == 0 and third == 2:
		return false
	if first == 192 and second == 88 and third == 99:
		return false
	if first == 198 and (second == 18 or second == 19):
		return false
	if first == 198 and second == 51 and third == 100:
		return false
	if first == 203 and second == 0 and third == 113:
		return false
	return true


## Returns whether an IPv6 address is a public global-unicast sharing candidate.
static func is_public_ipv6_address(address: String) -> bool:
	var normalized_address: String = normalize_connection_address(address).to_lower()
	if not is_supported_ipv6_address(normalized_address):
		return false
	if (
		normalized_address.begins_with("2001:db8:")
		or normalized_address.begins_with("2001:0db8:")
	):
		return false
	return true


static func format_endpoint(address: String, port: int) -> String:
	var normalized_address: String = normalize_connection_address(address)
	if normalized_address.contains(":"):
		return "[%s]:%d" % [normalized_address, port]
	return "%s:%d" % [normalized_address, port]


static func validate_action_envelope(action_id: StringName, payload: Dictionary) -> Error:
	if action_id.is_empty() or String(action_id).length() > MAX_ACTION_ID_LENGTH:
		return ERR_INVALID_PARAMETER
	if payload.size() > MAX_ACTION_PAYLOAD_FIELDS:
		return ERR_INVALID_DATA
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


static func _contains_control_or_whitespace(value: String) -> bool:
	var index: int = 0
	while index < value.length():
		var codepoint: int = value.unicode_at(index)
		if codepoint <= 32 or codepoint == 127:
			return true
		index += 1
	return false


static func _is_valid_hostname(hostname: String) -> bool:
	if hostname.to_lower() == "localhost":
		return true
	if hostname.begins_with(".") or hostname.ends_with("."):
		return false
	var labels: PackedStringArray = hostname.split(".")
	if labels.size() < 2:
		return false
	for label: String in labels:
		if label.is_empty() or label.length() > 63:
			return false
		if label.begins_with("-") or label.ends_with("-"):
			return false
		for index: int in range(label.length()):
			var codepoint: int = label.unicode_at(index)
			var is_digit: bool = codepoint >= 48 and codepoint <= 57
			var is_upper: bool = codepoint >= 65 and codepoint <= 90
			var is_lower: bool = codepoint >= 97 and codepoint <= 122
			if not is_digit and not is_upper and not is_lower and codepoint != 45:
				return false
	return true
