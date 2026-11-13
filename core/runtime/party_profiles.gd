## Persistent core identity and protocol profiles. Invalid existing files never become defaults.
extends RefCounted
const JsonConfig = preload("res://core/config/party_json_config.gd")
const Data = preload("res://core/runtime/party_data.gd")
var settings: PartyInput
var last_error: String = ""
var _records: Dictionary = {}

func _init(local_settings: PartyInput) -> void:
	settings = local_settings

## Persist first-use identity before it can be advertised to another peer.
func initialize() -> Error:
	last_error = ""
	if settings.config.has_section_key("profile", "player_id"):
		var value: Variant = settings.config.get_value("profile", "player_id")
		if not value is String or value.is_empty():
			_failure("本机 player_id 无效：" + settings.settings_path)
			return ERR_INVALID_DATA
		return OK
	settings.config.set_value("profile", "player_id", Data.token())
	var error: Error = settings.save_settings()
	if error != OK:
		settings.config.erase_section_key("profile", "player_id")
		_failure("无法保存本机身份：" + settings.settings_path + " · " + error_string(error))
	return error

func identity() -> Dictionary:
	var id: String = settings.config.get_value("profile", "player_id")
	return {"player_id": id, "name": "玩家" + id.left(6), "system": Data.SYSTEM}

## Read name and appearance together. Only an absent file uses first-use defaults.
## Returns {ok, name, profile} or {ok:false, message}; callers must stop on failure.
func read(protocol_id: String, protocol: RefCounted) -> Dictionary:
	var record: Dictionary = read_record(protocol_id)
	if not record.ok:
		return record
	if not record.exists:
		record.profile = protocol.default_player_config().duplicate(true)
	var report: Dictionary = protocol.validate_player_config(record.profile)
	if not report.ok:
		return _failure("协议资料无效：" + _path(protocol_id) + " · " + report.message)
	return record

## Menu identity is local JSON; displaying a name must not load the protocol implementation.
func read_record(protocol_id: String) -> Dictionary:
	last_error = ""
	if _records.has(protocol_id):
		return _records[protocol_id].duplicate(true)
	var file: JsonConfig = JsonConfig.new()
	var path: String = _path(protocol_id)
	var error: Error = file.load(path)
	if error == ERR_FILE_NOT_FOUND:
		_records[protocol_id] = {"ok": true, "exists": false, "name": identity().name, "profile": {}}
		return _records[protocol_id].duplicate(true)
	if error != OK:
		return _failure("无法读取协议资料：" + path + " · " + error_string(error))
	if file.get_value("profile", "format", 0) != 1:
		return _failure("协议资料格式无效：" + path)
	var name_value: Variant = file.get_value("profile", "display_name")
	var value: Variant = file.get_value("profile", "value")
	if not name_value is String or not validate_name(name_value) or not value is Dictionary:
		return _failure("协议资料字段无效：" + path)
	_records[protocol_id] = {"ok": true, "exists": true, "name": name_value, "profile": value}
	return _records[protocol_id].duplicate(true)

func _failure(message: String) -> Dictionary:
	last_error = message
	push_error(message)
	return {"ok": false, "message": message}

func save(name_value: String, protocol_id: String, value: Dictionary) -> Error:
	if not validate_name(name_value) or not preload("res://core/config/party_paths.gd").folder(protocol_id):
		return ERR_INVALID_PARAMETER
	var path: String = _path(protocol_id)
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error != OK:
		return error
	var file: JsonConfig = JsonConfig.new()
	file.set_value("profile", "format", 1)
	file.set_value("profile", "display_name", name_value)
	file.set_value("profile", "value", value.duplicate(true))
	error = preload("res://core/config/party_config_store.gd").write_configs({path: file.encode_to_text()})
	if error == OK:
		_records.erase(protocol_id)
	return error

func _path(id: String) -> String:
	return settings.storage_directory().path_join("protocols").path_join(id).path_join("config/profile.json")

static func validate_name(value: String) -> bool:
	if value != value.strip_edges() or value.is_empty() or value.length() > 16:
		return false
	for character: String in value:
		if character.unicode_at(0) < 32 or character.unicode_at(0) == 127 or character in "\n\r\t":
			return false
	return true
