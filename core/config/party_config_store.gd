## Portable local preferences. Own settings and selected protocol overrides have separate files.
extends RefCounted
const JsonConfig = preload("res://core/config/party_json_config.gd")
signal changed(owner: String)
const Paths = preload("res://core/config/party_paths.gd")
const Schema = preload("res://core/config/party_schema.gd")
var root: String
var catalog: RefCounted
var last_error: String = ""
var _cache: Dictionary = {}
var _restart: Dictionary = {}

func _init(directory: String, content_catalog: RefCounted) -> void:
	root = directory
	catalog = content_catalog

func branch(protocol: String) -> String:
	return protocol

func owner(id: String) -> String:
	return "protocols/" + branch(id) if catalog.get_package(id).get("kind") == "protocols" else catalog.get_package(id).get("kind", "") + "/" + id

func read(id: String, protocol: String = "") -> Dictionary:
	if Paths.configuration(root, catalog, id).is_empty():
		last_error = "未知配置目标：" + id
		return {}
	var name_value: String = owner(id)
	if _cache.has(name_value):
		return _with_branch(id, protocol)
	var value: Dictionary = {"format": 2, "owner": name_value, "revision": 0, "settings_version": catalog.schema(id).settings_version, "own": {}, "common_overrides": {}}
	var own_file: Dictionary = _read_local(own_path(id), id)
	if own_file.is_empty():
		return {}
	value.own = own_file.values
	value.revision = own_file.revision
	var checked: Dictionary = Schema.values(catalog.schema(id), value.own, "local", false)
	if not checked.ok:
		last_error = name_value + ": " + checked.message
		return {}
	value.own = checked.value
	_cache[name_value] = value
	_restart[name_value] = value.duplicate(true)
	return _with_branch(id, protocol)

## Read only the selected protocol branch; a broken inactive branch cannot block another game.
func _with_branch(id: String, protocol: String) -> Dictionary:
	var name_value: String = owner(id)
	if not protocol.is_empty() and catalog.get_package(id).kind != "protocols":
		var key: String = branch(protocol)
		if not _cache[name_value].common_overrides.has(key):
			var directory: String = Paths.configuration(root, catalog, id, protocol)
			if directory.is_empty():
				last_error = "协议缺少有效配置目录：" + protocol
				return {}
			var record: Dictionary = _read_local(directory.path_join("overrides.json"), protocol, true)
			if record.is_empty():
				return {}
			var selected: Dictionary = {"settings_version": catalog.schema(protocol).settings_version, "values": record.values}
			_cache[name_value].common_overrides[key] = selected
			_restart[name_value].common_overrides[key] = selected.duplicate(true)
	return _cache[name_value].duplicate(true)

## Fixed-target edit session: expected revision prevents stale dialogs from overwriting changes.
func commit(id: String, protocol: String, revision: int, edits: Array) -> Error:
	var old: Dictionary = read(id, protocol)
	if old.is_empty():
		return ERR_INVALID_DATA
	if int(old.revision) != revision:
		last_error = "设置已被其他编辑更新，请重新打开"
		return ERR_BUSY
	var next: Dictionary = old.duplicate(true)
	var protocol_key: String = branch(protocol) if not protocol.is_empty() else ""
	for edit: Variant in edits:
		if not edit is Dictionary or edit.get("op") not in ["set", "unset"] or edit.get("target") not in ["own", "common"]:
			return ERR_INVALID_PARAMETER
		var common: bool = edit.target == "common"
		if common and (protocol.is_empty() or catalog.get_package(id).kind == "protocols"):
			return ERR_UNAUTHORIZED
		var schema_value: Dictionary = catalog.schema(protocol if common else id)
		var key: String = edit.get("key", "")
		var field: Dictionary = schema_value.fields.get(key, {})
		if field.is_empty() or field.audience != "local" or (common and not field.get("overridable", false)) or field.get("readonly", false):
			return ERR_UNAUTHORIZED
		var target: Dictionary = next.own
		if common:
			var existing: Dictionary = next.common_overrides.get(protocol_key, {"settings_version": schema_value.settings_version, "values": {}})
			if existing.get("settings_version") != schema_value.settings_version or not existing.get("values") is Dictionary:
				return ERR_INVALID_DATA
			next.common_overrides[protocol_key] = existing
			target = existing.values
		if edit.op == "unset":
			target.erase(key)
		else:
			var checked: Dictionary = Schema.normalize(field, edit.get("value"))
			if not checked.ok:
				last_error = key + ": " + checked.message
				return ERR_INVALID_PARAMETER
			target[key] = checked.value
	if next == old:
		return OK
	next.revision = int(old.revision) + 1
	# Own-only editing must preserve any protocol override files already on disk.
	var error: Error = write_configs({own_path(id): _encoded(id, int(next.revision), next.own)}) if protocol.is_empty() else _persist(id, protocol, next)
	if error != OK:
		last_error = "本机保存失败：" + error_string(error)
		return error
	_cache[owner(id)] = next
	changed.emit(owner(id))
	return OK

func local_layers(game: String, protocol: String) -> Dictionary:
	var protocol_data: Dictionary = read(protocol)
	var game_data: Dictionary = read(game, protocol) if not game.is_empty() else {"own": {}, "common_overrides": {}}
	if protocol_data.is_empty() or game_data.is_empty():
		return {}
	var selected: Dictionary = game_data.common_overrides.get(branch(protocol), {"settings_version": catalog.schema(protocol).settings_version, "values": {}})
	if selected.get("settings_version") != catalog.schema(protocol).settings_version or not selected.get("values") is Dictionary:
		last_error = "协议覆盖版本不受支持"
		return {}
	var checked: Dictionary = Schema.values(catalog.schema(protocol), selected.values, "local", false, true)
	if not checked.ok:
		last_error = checked.message
		return {}
	var result: Dictionary = {"protocol": protocol_data.own.duplicate(true), "own": game_data.own.duplicate(true), "overrides": checked.value}
	# Restart fields use the process-start profile image, even across scope activations.
	for pair: Array in [[protocol, "protocol"], [game, "own"]]:
		if String(pair[0]).is_empty():
			continue
		var schema_value: Dictionary = catalog.schema(pair[0])
		var initial: Dictionary = _restart[owner(pair[0])]
		for key: String in schema_value.fields:
			if schema_value.fields[key].audience == "local" and schema_value.fields[key].apply == "restart":
				result[pair[1]].erase(key)
				if initial.own.has(key):
					result[pair[1]][key] = initial.own[key]
				if pair[1] == "protocol" and not game.is_empty():
					result.overrides.erase(key)
					var initial_overrides: Dictionary = _restart[owner(game)].common_overrides.get(branch(protocol), {}).get("values", {})
					if initial_overrides.has(key):
						result.overrides[key] = initial_overrides[key]
	return result

## Explicit reset keeps the unreadable original as .bak; no migration or guessed conversion.
func reset(id: String) -> Error:
	if Paths.configuration(root, catalog, id).is_empty():
		return ERR_INVALID_PARAMETER
	var value: Dictionary = {"format": 2, "owner": owner(id), "revision": 0, "settings_version": catalog.schema(id).settings_version, "own": {}, "common_overrides": {}}
	var error: Error = _persist(id, "", value)
	if error == OK:
		_cache[owner(id)] = value
		if not _restart.has(owner(id)):
			_restart[owner(id)] = value.duplicate(true)
		changed.emit(owner(id))
	return error

func own_path(id: String) -> String:
	return Paths.configuration(root, catalog, id).path_join("preferences.json")

func _read_local(path: String, schema_id: String, override_only: bool = false) -> Dictionary:
	var file: JsonConfig = JsonConfig.new()
	var error: Error = file.load(path)
	if error == ERR_FILE_NOT_FOUND:
		return {"revision": 0, "values": {}}
	if error != OK or file.get_value("meta", "format", 0) != 2 or file.get_value("meta", "schema_id", "") != schema_id or file.get_value("meta", "settings_version", -1) != catalog.schema(schema_id).settings_version:
		last_error = "配置无效或版本不匹配：" + path
		return {}
	var revision_value: Variant = file.get_value("meta", "revision", 0)
	if not revision_value is int or revision_value < 0:
		last_error = "配置修订号无效：" + path
		return {}
	var values: Dictionary = {}
	if file.has_section("values"):
		for key: String in file.get_section_keys("values"):
			values[key] = file.get_value("values", key)
	var checked: Dictionary = Schema.values(catalog.schema(schema_id), values, "local", false, override_only)
	if not checked.ok:
		last_error = path + ": " + checked.message
		return {}
	return {"revision": revision_value, "values": checked.value}

func _encoded(schema_id: String, revision_value: int, values: Dictionary) -> String:
	var file: JsonConfig = JsonConfig.new()
	file.set_value("meta", "format", 2)
	file.set_value("meta", "schema_id", schema_id)
	file.set_value("meta", "settings_version", catalog.schema(schema_id).settings_version)
	file.set_value("meta", "revision", revision_value)
	for key: String in values:
		file.set_value("values", key, values[key])
	return file.encode_to_text()

## Stage every file before replacing either layer; restore prior bytes if a replacement fails.
func _persist(id: String, protocol: String, value: Dictionary) -> Error:
	var writes: Dictionary = {own_path(id): _encoded(id, int(value.revision), value.own)}
	if catalog.get_package(id).kind != "protocols":
		var protocols: Array[String] = []
		if protocol.is_empty():
			protocols.assign(catalog.ids("protocols"))
		else:
			protocols.append(protocol)
		for selected: String in protocols:
			var directory: String = Paths.configuration(root, catalog, id, selected)
			if directory.is_empty():
				return ERR_INVALID_DATA
			writes[directory.path_join("overrides.json")] = _encoded(selected, int(value.revision), value.common_overrides.get(branch(selected), {}).get("values", {}))
	return write_configs(writes)

static func write_configs(writes: Dictionary) -> Error:
	var previous: Dictionary = {}
	for path: String in writes:
		var error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		if error != OK:
			return error
		previous[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		var file: FileAccess = FileAccess.open(path + ".pending", FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		file.store_string(writes[path])
		file.flush()
		error = file.get_error()
		file.close()
		if error != OK:
			return error
	var done: Array[String] = []
	for path: String in writes:
		var error: Error = OK
		if previous[path] != null:
			error = DirAccess.copy_absolute(path, path + ".bak")
		if error == OK:
			error = DirAccess.rename_absolute(path + ".pending", path)
		if error != OK:
			for changed_path: String in done:
				if previous[changed_path] == null:
					DirAccess.remove_absolute(changed_path)
				else:
					DirAccess.copy_absolute(changed_path + ".bak", changed_path)
			return error
		done.append(path)
	return OK
