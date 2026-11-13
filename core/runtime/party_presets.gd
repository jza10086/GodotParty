## Named, portable JsonConfig presets. Filenames are names; loading never applies settings.
extends RefCounted
const JsonConfig = preload("res://core/config/party_json_config.gd")
const Paths = preload("res://core/config/party_paths.gd")
const Schema = preload("res://core/config/party_schema.gd")
const Store = preload("res://core/config/party_config_store.gd")
const DOMAINS: Array[String] = ["room_own", "room_common"]
var store: RefCounted
var catalog: RefCounted
var last_error: String = ""

func _init(config_store: RefCounted) -> void:
	store = config_store
	catalog = store.catalog

func directory(id: String, protocol: String) -> String:
	var base: String = Paths.configuration(store.root, catalog, id, protocol)
	return base.path_join("presets") if not base.is_empty() else ""

func names(id: String, protocol: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var path: String = directory(id, protocol)
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return result
	for name_value: String in DirAccess.get_files_at(path):
		if name_value.ends_with(".json") and valid_name(name_value.trim_suffix(".json")):
			result.append(name_value.trim_suffix(".json"))
	result.sort()
	return result

static func valid_name(value: String) -> bool:
	if value.is_empty() or value != value.strip_edges() or value.length() > 80 or not value.is_valid_filename() or value.ends_with("."):
		return false
	var stem: String = value.get_slice(".", 0).to_lower()
	if stem in ["con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5", "com6", "com7", "com8", "com9", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7", "lpt8", "lpt9", "默认预设", "临时预设"]:
		return false
	for character: String in value:
		if character.unicode_at(0) < 32 or character.unicode_at(0) == 127:
			return false
	return true

func _meta(id: String, protocol: String) -> Dictionary:
	var package: Dictionary = catalog.get_package(id)
	var selected: Dictionary = catalog.get_package(protocol)
	if package.get("kind") not in ["protocols", "maingame", "minigame"] or selected.get("kind") != "protocols":
		return {}
	if package.kind == "protocols" and id != protocol:
		return {}
	if package.kind == "maingame" and package.get("protocol", {}).get("id") != protocol:
		return {}
	if package.kind == "minigame" and not package.get("adapters", []).any(func(adapter: Dictionary) -> bool: return adapter.get("protocol", {}).get("id") == protocol):
		return {}
	return {"format": 3, "kind": package.kind, "package_id": id, "package_version": package.package_version, "protocol_id": protocol, "settings_version": catalog.schema(id).settings_version, "protocol_settings_version": catalog.schema(protocol).settings_version}

func validate(id: String, protocol: String, value: Dictionary) -> Dictionary:
	last_error = ""
	if _meta(id, protocol).is_empty() or value.size() != DOMAINS.size() + (1 if catalog.get_package(id).kind == "maingame" else 0):
		last_error = "预设目标或数据分区无效"
		return {}
	var checked: Dictionary = {}
	for domain: String in DOMAINS:
		if not value.get(domain) is Dictionary:
			last_error = "预设缺少分区：" + domain
			return {}
		var common: bool = domain.ends_with("common")
		if common and id == protocol and not value[domain].is_empty():
			last_error = "协议预设不能覆盖其他协议"
			return {}
		var report: Dictionary = Schema.values(catalog.schema(protocol if common else id), value[domain], "room", false, common)
		if not report.ok:
			last_error = domain + ": " + report.message
			return {}
		checked[domain] = report.value
	var rules: Dictionary = catalog.validate_settings(id, checked.room_own)
	if not rules.get("ok", false):
		last_error = rules.get("message", "房间规则无效")
		return {}
	if catalog.get_package(id).kind == "maingame":
		if not value.get("room") is Dictionary or not _validate_room(id, protocol, value.room):
			if last_error.is_empty():
				last_error = "缺少整场房间配置"
			return {}
		checked.room = value.room.duplicate(true)
	return checked

## 只捕获房主规则；大游戏还保存协议规则、小游戏池及各小游戏规则。
func snapshot(id: String, protocol: String, room_own: Dictionary = {}, room_common: Dictionary = {}, room: Dictionary = {}) -> Dictionary:
	var value: Dictionary = {"room_own": room_own.duplicate(true), "room_common": room_common.duplicate(true)}
	if catalog.get_package(id).kind == "maingame":
		var versions: Dictionary = {}
		for child: String in room.children:
			versions[child] = _meta(child, protocol)
		value.room = {"common": room.common.duplicate(true), "children": room.children.duplicate(true), "pools": room.pools.duplicate(true), "common_overrides": room.common_overrides.duplicate(true), "versions": versions}
		value.room.common_overrides[id] = room_common.duplicate(true)
	return value

## 文件输入边界：整场预设中的所有小游戏及规则必须一起通过检查。
func _validate_room(id: String, protocol: String, room: Dictionary) -> bool:
	if room.size() != 5:
		last_error = "整场预设分区无效"
		return false
	for key: String in ["common", "children", "pools", "common_overrides", "versions"]:
		if not room.get(key) is Dictionary:
			last_error = "整场预设缺少：" + key
			return false
	var resolution: Dictionary = catalog.resolve(id, room.pools)
	if not resolution.ok:
		last_error = resolution.message
		return false
	var base: Dictionary = Schema.values(catalog.schema(protocol), room.common, "room", false, false)
	if not base.ok:
		last_error = base.message
		return false
	var selected: Dictionary = {}
	for pool: Array in room.pools.values():
		for child: String in pool:
			selected[child] = true
	if selected.size() != room.children.size() or selected.size() != room.versions.size():
		last_error = "小游戏池、配置与版本集合不一致"
		return false
	for child: String in selected:
		if not room.children.get(child) is Dictionary or room.versions.get(child) != _meta(child, protocol):
			last_error = "小游戏配置缺失或版本不匹配：" + child
			return false
		var rules: Dictionary = catalog.validate_settings(child, room.children[child])
		if not rules.ok:
			last_error = rules.message
			return false
	for game: String in room.common_overrides:
		if game != id and not selected.has(game):
			last_error = "覆盖引用了池外游戏：" + game
			return false
		if not room.common_overrides[game] is Dictionary:
			last_error = "规则覆盖必须为字典"
			return false
		var override_report: Dictionary = Schema.values(catalog.schema(protocol), room.common_overrides[game], "room", false, true)
		if not override_report.ok:
			last_error = override_report.message
			return false
	return true

func save(id: String, protocol: String, name_value: String, value: Dictionary, overwrite: bool = false) -> Error:
	if not valid_name(name_value) or directory(id, protocol).is_empty():
		last_error = "名称需为有效文件名（1–80 字符），不能使用保留名称"
		return ERR_INVALID_PARAMETER
	var checked: Dictionary = validate(id, protocol, value)
	if checked.is_empty():
		return ERR_INVALID_DATA
	var exists: bool = name_value in names(id, protocol)
	for item: String in names(id, protocol):
		if item.to_lower() == name_value.to_lower() and item != name_value:
			last_error = "已存在仅大小写不同的名称"
			return ERR_ALREADY_EXISTS
	if exists and not overwrite:
		last_error = "预设已存在，请明确选择覆盖"
		return ERR_ALREADY_EXISTS
	if overwrite and not exists:
		last_error = "预设已被删除，请刷新后另存"
		return ERR_FILE_NOT_FOUND
	var file: JsonConfig = JsonConfig.new()
	var meta: Dictionary = _meta(id, protocol)
	for key: String in meta:
		file.set_value("meta", key, meta[key])
	for domain: String in checked:
		for key: String in checked[domain]:
			file.set_value(domain, key, checked[domain][key])
	var error: Error = Store.write_configs({directory(id, protocol).path_join(name_value + ".json"): file.encode_to_text()})
	last_error = "" if error == OK else error_string(error)
	return error

func read(id: String, protocol: String, name_value: String) -> Dictionary:
	last_error = ""
	if not valid_name(name_value) or directory(id, protocol).is_empty():
		last_error = "无效的预设路径"
		return {}
	var file: JsonConfig = JsonConfig.new()
	if file.load(directory(id, protocol).path_join(name_value + ".json")) != OK:
		last_error = "无法读取预设，请刷新列表"
		return {}
	var meta: Dictionary = _meta(id, protocol)
	if meta.is_empty() or not file.has_section("meta") or file.get_section_keys("meta").size() != meta.size():
		last_error = "预设目标或版本无效"
		return {}
	for key: String in meta:
		if file.get_value("meta", key) != meta[key]:
			last_error = "预设不兼容：" + key
			return {}
	for section: String in file.get_sections():
		if section != "meta" and section not in DOMAINS and not (section == "room" and meta.kind == "maingame"):
			last_error = "未知预设分区：" + section
			return {}
	var value: Dictionary = {}
	for domain: String in DOMAINS:
		value[domain] = {}
		if file.has_section(domain):
			for key: String in file.get_section_keys(domain):
				value[domain][key] = file.get_value(domain, key)
	if meta.kind == "maingame":
		value.room = {}
		if file.has_section("room"):
			for key: String in file.get_section_keys("room"):
				value.room[key] = file.get_value("room", key)
	return validate(id, protocol, value)

func rename(id: String, protocol: String, old_name: String, new_name: String) -> Error:
	if not valid_name(old_name) or not valid_name(new_name):
		return ERR_INVALID_PARAMETER
	for item: String in names(id, protocol):
		if item.to_lower() == new_name.to_lower():
			return ERR_ALREADY_EXISTS
	var base: String = directory(id, protocol)
	if base.is_empty():
		return ERR_INVALID_PARAMETER
	return DirAccess.rename_absolute(base.path_join(old_name + ".json"), base.path_join(new_name + ".json"))

func remove(id: String, protocol: String, name_value: String) -> Error:
	if not valid_name(name_value) or directory(id, protocol).is_empty():
		return ERR_INVALID_PARAMETER
	return DirAccess.remove_absolute(directory(id, protocol).path_join(name_value + ".json"))
