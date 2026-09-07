## Loads and saves local-only direct-connection preferences in settings.cfg.
class_name ConnectionPreferences
extends RefCounted

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "connection"
const IP_MODE_DUAL: String = "dual"
const IP_MODE_IPV4: String = "ipv4"
const IP_MODE_IPV6: String = "ipv6"

const LEGACY_BIND_MODE_AUTO: String = "auto"
const LEGACY_BIND_MODE_SPECIFIC: String = "specific"

var display_name: String = ""
var join_address: String = LobbyProtocol.DEFAULT_ADDRESS
var port: int = LobbyProtocol.DEFAULT_PORT
var ip_mode: String = IP_MODE_DUAL
var specific_bind_address: String = ""


static func load_from_file(path: String = SETTINGS_PATH) -> ConnectionPreferences:
	var preferences: ConnectionPreferences = ConnectionPreferences.new()
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		return preferences

	var has_saved_name: bool = (
		load_error == OK
		and config.has_section_key(SECTION, "display_name")
	)
	if has_saved_name:
		var raw_name: Variant = config.get_value(SECTION, "display_name", "")
		if typeof(raw_name) == TYPE_STRING:
			var normalized_name: String = SessionPlayer.normalize_display_name(
				String(raw_name)
			)
			if SessionPlayer.validate_display_name(normalized_name) == OK:
				preferences.display_name = normalized_name
	if preferences.display_name.is_empty():
		preferences.display_name = (
			"玩家"
			if has_saved_name
			else "玩家-%04d" % randi_range(0, 9999)
	)

	var raw_address: Variant = config.get_value(
		SECTION,
		"join_address",
		LobbyProtocol.DEFAULT_ADDRESS
	)
	if typeof(raw_address) == TYPE_STRING:
		var normalized_address: String = LobbyProtocol.normalize_connection_address(
			String(raw_address)
		)
		if LobbyProtocol.validate_address(normalized_address) == OK:
			preferences.join_address = normalized_address

	var raw_port: Variant = config.get_value(
		SECTION,
		"port",
		LobbyProtocol.DEFAULT_PORT
	)
	if typeof(raw_port) == TYPE_INT and LobbyProtocol.validate_port(int(raw_port)) == OK:
		preferences.port = int(raw_port)

	preferences._load_network_selection(config)
	return preferences


func save_to_file(path: String = SETTINGS_PATH) -> Error:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		return load_error
	config.set_value(SECTION, "display_name", display_name)
	config.set_value(SECTION, "join_address", join_address)
	config.set_value(SECTION, "port", port)
	config.set_value(SECTION, "ip_mode", ip_mode)
	config.set_value(
		SECTION,
		"specific_bind_address",
		specific_bind_address
	)
	if config.has_section_key(SECTION, "bind_mode"):
		config.erase_section_key(SECTION, "bind_mode")
	if config.has_section_key(SECTION, "bind_address"):
		config.erase_section_key(SECTION, "bind_address")
	return config.save(path)


func get_default_bind_address() -> String:
	match ip_mode:
		IP_MODE_IPV4:
			return LobbyProtocol.IPV4_ANY_ADDRESS
		IP_MODE_IPV6:
			return LobbyProtocol.IPV6_ANY_ADDRESS
		_:
			return LobbyProtocol.DEFAULT_BIND_ADDRESS


func get_effective_bind_address() -> String:
	if not specific_bind_address.is_empty():
		return specific_bind_address
	return get_default_bind_address()


func _load_network_selection(config: ConfigFile) -> void:
	var raw_ip_mode: Variant = config.get_value(SECTION, "ip_mode", "")
	if typeof(raw_ip_mode) == TYPE_STRING:
		var loaded_mode: String = String(raw_ip_mode)
		if _is_valid_ip_mode(loaded_mode):
			ip_mode = loaded_mode

	var raw_specific: Variant = config.get_value(
		SECTION,
		"specific_bind_address",
		""
	)
	if typeof(raw_specific) == TYPE_STRING:
		var normalized_specific: String = LobbyProtocol.normalize_connection_address(
			String(raw_specific)
		)
		if _is_valid_specific_bind(normalized_specific):
			specific_bind_address = normalized_specific

	if config.has_section_key(SECTION, "ip_mode"):
		return
	var legacy_mode: String = String(
		config.get_value(SECTION, "bind_mode", LEGACY_BIND_MODE_AUTO)
	)
	var legacy_address: String = LobbyProtocol.normalize_connection_address(
		String(
			config.get_value(
				SECTION,
				"bind_address",
				LobbyProtocol.DEFAULT_BIND_ADDRESS
			)
		)
	)
	match legacy_mode:
		IP_MODE_IPV4:
			ip_mode = IP_MODE_IPV4
		IP_MODE_IPV6:
			ip_mode = IP_MODE_IPV6
		LEGACY_BIND_MODE_SPECIFIC:
			if _is_valid_specific_bind(legacy_address):
				specific_bind_address = legacy_address
				ip_mode = (
					IP_MODE_IPV6
					if legacy_address.contains(":")
					else IP_MODE_IPV4
				)


static func _is_valid_ip_mode(value: String) -> bool:
	return value == IP_MODE_DUAL or value == IP_MODE_IPV4 or value == IP_MODE_IPV6


static func _is_valid_specific_bind(value: String) -> bool:
	return (
		not value.is_empty()
		and value != LobbyProtocol.DEFAULT_BIND_ADDRESS
		and value != LobbyProtocol.IPV4_ANY_ADDRESS
		and value != LobbyProtocol.IPV6_ANY_ADDRESS
		and LobbyProtocol.validate_bind_address(value) == OK
	)
