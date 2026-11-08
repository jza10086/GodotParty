## Internal manifest catalog shared by source, installed packs and the real lobby.
extends RefCounted

const Paths = preload("res://core/config/party_paths.gd")
const External = preload("res://core/content/party_external_files.gd")
const Data = preload("res://core/runtime/party_data.gd")
const Schema = preload("res://core/config/party_schema.gd")
const Localization = preload("res://core/i18n/party_localization.gd")
var i18n: RefCounted = Localization.new()
const PlayerCounts = preload("res://core/config/party_player_counts.gd")
const KINDS: Array[String] = ["maingame", "minigame", "protocols", "avatars"]
var packages: Dictionary = {}
var _schemas: Dictionary = {}
var errors: Array[String] = []
var channels: Dictionary = {}
var channel_count: int = 3

func scan() -> Error:
	packages.clear()
	_schemas.clear()
	errors.clear()
	for kind: String in ["protocols", "maingame", "minigame"]:
		var root: String = "res://games/" + kind
		if not DirAccess.dir_exists_absolute(root):
			continue
		for directory: String in DirAccess.get_directories_at(root):
			var path: String = root.path_join(directory).path_join("manifest.json")
			if FileAccess.file_exists(path):
				register_manifest(path)
				if kind == "protocols":
					var avatars: String = path.get_base_dir().path_join("avatars")
					if not DirAccess.dir_exists_absolute(avatars):
						continue
					for avatar: String in DirAccess.get_directories_at(avatars):
						register_manifest(avatars.path_join(avatar).path_join("manifest.json"))
	_validate_config_directories()
	_build_channels()
	return OK if errors.is_empty() else ERR_INVALID_DATA

func register_manifest(path: String) -> Error:
	var manifest: Dictionary = Data.read_json(path)
	var relative: String = Paths.package_relative(manifest)
	if relative.is_empty() or not path.get_base_dir().ends_with("games/" + relative):
		errors.append("Package path must match its declared owner: " + path)
		return ERR_INVALID_DATA
	var id: String = manifest.id
	if manifest.get("manifest_version") != 2 or manifest.get("core_api_major") != Data.API_VERSION:
		errors.append(id + ": unsupported manifest/API")
		return ERR_INVALID_DATA
	if packages.has(id):
		errors.append("DUPLICATE_PACKAGE: " + id)
		return ERR_ALREADY_EXISTS
	var native_count: Variant = manifest.get("native_channels", 0)
	if not manifest.get("streams", {}) is Dictionary or not native_count is int or native_count < 0 or native_count > 80:
		errors.append(id + ": invalid channel declaration")
		return ERR_INVALID_DATA
	if manifest.kind == "protocols" and not manifest.get("config_directories") is Dictionary:
		errors.append(id + ": missing config_directories")
		return ERR_INVALID_DATA
	if manifest.kind != "avatars":
		var issue: String = Localization.validate_declaration(manifest.get("localization"))
		if not issue.is_empty():
			errors.append(id + ": " + issue)
			return ERR_INVALID_DATA
		i18n.declare_package(id, manifest.localization, path.get_base_dir())
	manifest["_root"] = path.get_base_dir()
	packages[id] = manifest
	return OK

func validate_manifest(manifest: Dictionary) -> String:
	var external_issue: String = External.validate(manifest.get("external_files", []))
	if not external_issue.is_empty():
		return external_issue
	for obsolete: String in ["fields", "defaults", "input_actions"]:
		if manifest.has(obsolete):
			return "Superseded configuration declaration: " + obsolete
	if manifest.get("manifest_version") != 2 or manifest.get("core_api_major") != Data.API_VERSION:
		return "Unsupported manifest/API; only current format is accepted"
	if not manifest.get("id") is String or not Data.identifier(manifest["id"]):
		return "Invalid package ID"
	if manifest.get("kind") not in KINDS or not manifest.get("package_version") is String or manifest["package_version"].is_empty():
		return "Missing package kind/version"
	if manifest["kind"] != "avatars" and (not manifest.get("entry") is String or not Data.relative_path(manifest["entry"])):
		return "Missing entry relative to package root"
	if manifest.kind != "avatars":
		var localization_issue: String = Localization.validate_declaration(manifest.get("localization"))
		if not localization_issue.is_empty():
			return localization_issue
	for key: String in ["name", "introduction"]:
		if manifest.has(key) and not manifest[key] is String:
			return key + " must be a translation message string"
	for key: String in ["pools", "tags", "player_fields"]:
		if not manifest.get(key, []) is Array:
			return key + " must be an array"
	for key: String in ["controls"]:
		if not manifest.get(key, {}) is Dictionary:
			return key + " must be an object"
	for key: String in ["room_scene", "config_panel", "player_config_panel", "config_validator", "cover", "config_schema", "settings_runtime"]:
		if manifest.has(key) and (not manifest[key] is String or not Data.relative_path(manifest[key])):
			return "Invalid path: " + key
	for pool: Variant in manifest.get("pools", []):
		if not pool is String or pool.is_empty() or manifest["pools"].count(pool) != 1:
			return "Invalid or duplicate pool"
	var player_count_issue: String = PlayerCounts.validate(manifest)
	if not player_count_issue.is_empty():
		return player_count_issue
	for key: String in ["native_channels"]:
		if manifest.has(key) and (not manifest[key] is int or manifest[key] < 0 or manifest[key] > 80):
			return "Invalid count: " + key
	for field: Variant in manifest.get("player_fields", []):
		if not field is Dictionary or not field.get("key") is String or field.get("type") not in ["bool", "int", "float", "string", "enum"]:
			return "Invalid field declaration"
		if field.get("type") == "enum" and not field.get("options") is Array:
			return "Enum options must be an array"
	if not manifest.get("dependencies", {}) is Dictionary or not manifest.get("resources", {}) is Dictionary:
		return "Dependencies/resources must be dictionaries"
	for dependency: Variant in manifest.get("dependencies", {}):
		if not dependency is String or not Data.identifier(dependency) or not manifest["dependencies"][dependency] is String:
			return "Invalid dependency"
	for path: Variant in manifest.get("resources", {}).values():
		if not path is String or not Data.relative_path(path):
			return "Invalid public resource path"
	if manifest["kind"] == "maingame":
		if not _protocol_reference(manifest.get("protocol")):
			return "Main game requires one protocol"
		if not manifest.get("room_scene") is String or not Data.relative_path(manifest.room_scene):
			return "Main game requires a room_scene"
		if not manifest.get("minigames", []) is Array:
			return "Main game minigames must be an array"
		for mini: Variant in manifest.get("minigames", []):
			if not mini is String or not Data.identifier(mini):
				return "Invalid main-game minigame ID"
	if Paths.package_relative(manifest).is_empty():
		return "Invalid installation directory or avatar owner_protocol"
	if manifest["kind"] == "protocols":
		var directories: Variant = manifest.get("config_directories")
		if not directories is Dictionary or directories.size() != 2 or not Paths.folder(directories.get("maingame")) or not Paths.folder(directories.get("minigame")):
			return "Protocol requires safe maingame/minigame config_directories"

		var contract: Variant = manifest.get("contract")
		if not contract is Dictionary or typeof(contract.get("api_major")) != TYPE_INT or typeof(contract.get("api_minor")) != TYPE_INT:
			return "Invalid protocol contract"
	if manifest["kind"] == "minigame":
		if not manifest.get("playable", true) is bool or not manifest.get("adapters") is Array:
			return "Invalid minigame availability or adapters"
		if manifest.get("playable", true) == manifest.adapters.is_empty():
			return "Playable minigames require adapters; disabled prototypes must declare none"
		var ids: Dictionary = {}
		for adapter: Variant in manifest["adapters"]:
			if not adapter is Dictionary or not _protocol_reference(adapter.get("protocol")):
				return "Invalid adapter"
			var protocol_id: String = adapter["protocol"]["id"]
			if ids.has(protocol_id):
				return "One adapter per protocol is required"
			ids[protocol_id] = true
			if not adapter.get("dependencies", {}) is Dictionary:
				return "Adapter dependencies must be an object"
			for dependency: Variant in adapter.get("dependencies", {}):
				if not dependency is String or not Data.identifier(dependency) or not adapter["dependencies"][dependency] is String:
					return "Invalid adapter dependency"
			if adapter.has("entry") and (not adapter["entry"] is String or not Data.relative_path(adapter["entry"])):
				return "Invalid adapter entry"
	var streams: Variant = manifest.get("streams", {})
	if not streams is Dictionary:
		return "Invalid streams"
	for id: Variant in streams:
		var stream: Variant = streams[id]
		if not stream is Dictionary or stream.get("mode", "reliable") not in ["reliable", "unreliable", "ordered"] or stream.get("audience", "participants") not in ["participants", "spectators", "instance"]:
			return "Invalid stream " + str(id)
	return ""

func _protocol_reference(value: Variant) -> bool:
	return value is Dictionary and value.get("id") is String and Data.identifier(value["id"]) and typeof(value.get("api_major")) == TYPE_INT and typeof(value.get("min_api_minor", 0)) == TYPE_INT

func get_package(id: String) -> Dictionary:
	var result: Dictionary = packages.get(id, {}).duplicate(true)
	if not result.is_empty() and result.kind != "avatars":
		for key: String in ["name", "introduction"]:
			if result.get(key) is String and not result[key].is_empty():
				result[key] = i18n.text(id, result[key])
	return result

func ids(kind: String = "") -> Array[String]:
	var result: Array[String] = []
	for id: String in packages:
		if kind.is_empty() or packages[id]["kind"] == kind:
			result.append(id)
	result.sort()
	return result

func path(id: String, relative: String) -> String:
	if not packages.has(id) or not Data.relative_path(relative):
		return ""
	return String(packages[id]["_root"]).path_join(relative)

## Loose data resolves beside source packages in-editor and installed PCKs in releases.
func external_path(id: String, relative: String) -> String:
	var manifest: Dictionary = packages[id]
	if not External.safe_path(relative) or not External.contains(manifest.get("external_files", []), relative):
		push_error("Undeclared external path: " + id + "/" + relative)
		return ""
	var source: String = ProjectSettings.globalize_path(manifest._root)
	if OS.has_feature("editor") and source.is_absolute_path() and FileAccess.file_exists(source.path_join("manifest.json")):
		return source.path_join(relative)
	var installation: String = Paths.application_root()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--party-pack-dir="):
			installation = argument.trim_prefix("--party-pack-dir=")
	return installation.path_join(Paths.package_relative(manifest)).path_join(relative)

func load_entry(id: String) -> Resource:
	var manifest: Dictionary = packages.get(id, {})
	return load(path(id, manifest.get("entry", ""))) if not manifest.is_empty() else null

func protocol_matches(reference: Dictionary) -> bool:
	var manifest: Dictionary = packages.get(reference.get("id", ""), {})
	var contract: Variant = manifest.get("contract")
	return manifest.get("kind") == "protocols" and contract is Dictionary and contract.get("api_major") == reference.get("api_major") and int(contract.get("api_minor", -1)) >= int(reference.get("min_api_minor", 0))

func adapter(mini: String, protocol_id: String) -> Dictionary:
	var manifest: Dictionary = packages.get(mini, {})
	if manifest.get("kind") != "minigame" or manifest.get("playable", true) != true or not manifest.get("adapters") is Array:
		return {}
	for item: Variant in manifest.adapters:
		if item is Dictionary and _protocol_reference(item.get("protocol")) and item.protocol.id == protocol_id and protocol_matches(item.protocol):
			return item.duplicate(true)
	return {}

func compatible_minis(main_id: String) -> Array[String]:
	var result: Array[String] = []
	var main: Dictionary = packages.get(main_id, {})
	if not _protocol_reference(main.get("protocol")) or not main.get("minigames", []) is Array:
		return result
	for id: String in ids("minigame"):
		if not _pool_adapter(main, id).is_empty():
			result.append(id)
	return result

func _pool_adapter(main: Dictionary, id: String) -> Dictionary:
	if main.has("minigames") and id not in main.minigames:
		return {}
	return adapter(id, main.protocol.id)

## Compare the host's declared package versions before loading room settings or scenes.
## The requirement list is network input; no file fingerprints are computed.
func requirements_issue(required: Variant) -> String:
	if not required is Dictionary or required.is_empty():
		return "房主未提供有效的内容包清单"
	var issues: Array[String] = []
	for id: Variant in required:
		if not id is String or not Data.identifier(id) or not required[id] is Dictionary or not required[id].get("version") is String or required[id].version.is_empty():
			return "房主内容包清单格式无效"
		var needed: String = required[id].version
		if not packages.has(id):
			issues.append("缺少内容包 %s（当前版本：未安装；所需版本：%s）" % [id, needed])
			continue
		var manifest: Dictionary = packages[id]
		var label: String = "%s（%s）" % [manifest.get("name", id), id]
		if not manifest.get("package_version") is String:
			issues.append("%s 版本声明无效（当前值：%s；所需版本：%s）" % [label, str(manifest.get("package_version")), needed])
		elif manifest.package_version != needed:
			issues.append("%s 版本不同（当前版本：%s；所需版本：%s）" % [label, manifest.package_version, needed])
	return "\n".join(issues)

## Resolves only the selected adapter dependencies, never all advertised protocols.
func resolve(main_id: String, pools: Dictionary, appearances: Array = []) -> Dictionary:
	var main: Dictionary = packages.get(main_id, {})
	if main.get("kind") != "maingame" or not _protocol_reference(main.get("protocol")) or not protocol_matches(main.protocol):
		return Data.failure("PROTOCOL_NOT_SUPPORTED", "Main game protocol is unavailable")
	var selected: Dictionary = {}
	var visiting: Dictionary = {}
	var error: String = _visit(main_id, selected, visiting)
	if not error.is_empty():
		return Data.failure("DEPENDENCY_MISSING", error)
	error = _visit(main["protocol"]["id"], selected, visiting)
	if not error.is_empty():
		return Data.failure("DEPENDENCY_MISSING", error)
	for name: String in pools:
		if name not in main.get("pools", []) or not pools[name] is Array:
			return Data.failure("INVALID_POOL", name)
		for id: Variant in pools[name]:
			if not id is String:
				return Data.failure("INVALID_POOL", "小游戏池 %s 含有无效的包 ID" % name)
			var chosen: Dictionary = _pool_adapter(main, id)
			if chosen.is_empty():
				return Data.failure("INVALID_POOL", "小游戏 %s 不适配本房间协议 %s，或不在大游戏允许列表中" % [id, main.protocol.id])
			error = _visit(id, selected, visiting)
			if error.is_empty():
				error = _dependencies(chosen.get("dependencies", {}), selected, visiting)
			if not error.is_empty():
				return Data.failure("DEPENDENCY_MISSING", error)
	for appearance: Variant in appearances:
		var references: Array = []
		_collect_refs(appearance, references)
		for ref: Dictionary in references:
			var pack: Dictionary = packages.get(ref["package_id"], {})
			if not pack.get("resources", {}).has(ref["resource_key"]):
				return Data.failure("RESOURCE_MISSING", str(ref))
			error = _visit(ref["package_id"], selected, visiting)
			if not error.is_empty():
				return Data.failure("DEPENDENCY_MISSING", error)
	return {"ok": true, "packages": selected}

func _visit(id: String, selected: Dictionary, visiting: Dictionary) -> String:
	if visiting.has(id):
		return "Dependency cycle: " + id
	if selected.has(id):
		return ""
	if not packages.has(id):
		return "缺少内容包：" + id
	visiting[id] = true
	var manifest: Dictionary = packages[id]
	var issue: String = _prepare_schema(id)
	if not issue.is_empty():
		return issue
	var required: Array = manifest.get("resources", {}).values()
	if manifest.has("entry"):
		required.append(manifest["entry"])
	for relative: String in required:
		if not ResourceLoader.exists(path(id, relative)):
			return "缺少已声明的资源：" + id + "/" + relative
	var error: String = _dependencies(manifest.get("dependencies", {}), selected, visiting)
	if not error.is_empty():
		return error
	visiting.erase(id)
	selected[id] = {"version": manifest["package_version"]}
	return ""

func _dependencies(dependencies: Dictionary, selected: Dictionary, visiting: Dictionary) -> String:
	for id: String in dependencies:
		if packages.get(id, {}).get("package_version") != dependencies[id]:
			return "%s 依赖版本不符（当前版本：%s；所需版本：%s）" % [id, packages.get(id, {}).get("package_version", "未安装"), dependencies[id]]
		var error: String = _visit(id, selected, visiting)
		if not error.is_empty():
			return error
	return ""

func _collect_refs(value: Variant, output: Array) -> void:
	if value is Dictionary:
		if value.get("package_id") is String and value.get("resource_key") is String:
			output.append(value)
		for item: Variant in value.values():
			_collect_refs(item, output)
	elif value is Array:
		for item: Variant in value:
			_collect_refs(item, output)

func asset(ref: Dictionary, active: Dictionary) -> Resource:
	var id: String = ref.get("package_id", "")
	var key: String = ref.get("resource_key", "")
	if not active.has(id):
		return null
	var relative: String = packages.get(id, {}).get("resources", {}).get(key, "")
	return load(path(id, relative)) if not relative.is_empty() else null

## A schema is shared by its consumers and loaded once, when settings are first needed.
func _prepare_schema(id: String) -> String:
	var manifest: Dictionary = packages[id]
	if _schemas.has(id):
		return ""
	var manifest_issue: String = validate_manifest(manifest)
	if not manifest_issue.is_empty():
		return id + ": " + manifest_issue
	var configuration: Dictionary = Schema.empty()
	if manifest.has("config_schema"):
		var declaration: Resource = load(path(id, manifest.config_schema))
		if not declaration is Script or not declaration.has_method("schema"):
			return id + ": config_schema must name a script exposing static schema()"
		configuration = declaration.schema()
	var schema_issue: String = Schema.validate(configuration, manifest.kind)
	if schema_issue.is_empty():
		schema_issue = PlayerCounts.validate_fields(manifest, configuration)
	if not schema_issue.is_empty():
		return id + ": " + schema_issue
	_schemas[id] = configuration
	return ""

## Publishing checks the full declaration, schema and translations for the requested package.
func publication_issue(id: String) -> String:
	var manifest: Dictionary = packages[id]
	var issue: String = _prepare_schema(id)
	if not issue.is_empty() or manifest.kind == "avatars":
		return issue
	if i18n.register_package(id, manifest.localization, manifest._root) != OK:
		return i18n.last_error
	if i18n.validate_messages(id, manifest, _schemas[id]) != OK:
		return i18n.last_error
	return ""

func schema(id: String) -> Dictionary:
	if not packages.has(id):
		return Schema.empty()
	var issue: String = _prepare_schema(id)
	if not issue.is_empty():
		push_error(issue)
		return {}
	return i18n.localize_schema(id, _schemas[id])

func fields(id: String, audience: String = "room") -> Array:
	return Schema.fields(schema(id), audience)

func defaults(id: String) -> Dictionary:
	return Schema.defaults(schema(id), "room")

func validate_settings(id: String, value: Dictionary) -> Dictionary:
	if not packages.has(id):
		return Data.failure("PACKAGE_MISSING", id)
	var issue: String = _prepare_schema(id)
	if not issue.is_empty():
		return Data.failure("INVALID_SCHEMA", issue)
	var report: Dictionary = Schema.values(_schemas[id], value, "room")
	if not report.ok:
		return report
	var manifest: Dictionary = packages.get(id, {})
	if manifest.has("config_validator"):
		var script: Script = load(path(id, manifest.config_validator))
		var checked: Dictionary = script.new().validate(report.value.duplicate(true))
		if not checked.get("ok", false):
			return checked
	return report

func _build_channels() -> void:
	channels.clear()
	channel_count = 3
	for id: String in ids():
		var streams: Array = packages[id].get("streams", {}).keys()
		streams.sort()
		for stream: String in streams:
			channels[id + ":" + stream] = channel_count
			channel_count += 1
		var native_count: int = int(packages[id].get("native_channels", 0))
		channels[id + ":native"] = channel_count
		channel_count += native_count
	if channel_count > 80:
		errors.append("CHANNEL_CAPACITY: more than 80 logical channels")

## Match Godot's ignored-directory boundary, including archived prototypes and their import remaps.
static func files(root: String) -> Array[String]:
	var result: Array[String] = []
	if FileAccess.file_exists(root.path_join(".gdignore")):
		return result
	for file: String in DirAccess.get_files_at(root):
		if file.begins_with(".") or file.contains("~") or file.get_extension().to_lower() in ["tmp", "bak", "pending"]:
			continue
		result.append(root.path_join(file))
	var protocol_root: bool = FileAccess.file_exists(root.path_join("manifest.json")) and Data.read_json(root.path_join("manifest.json")).get("kind") == "protocols"
	for directory: String in DirAccess.get_directories_at(root):
		if not directory.begins_with(".") and not (directory == "config" and FileAccess.file_exists(root.path_join("manifest.json"))) and not (protocol_root and directory == "avatars"):
			result.append_array(files(root.path_join(directory)))
	result.sort()
	return result

func _validate_config_directories() -> void:
	for kind: String in ["maingame", "minigame"]:
		var used: Dictionary = {}
		for id: String in ids("protocols"):
			var value: Variant = packages[id].config_directories.get(kind)
			if not Paths.folder(value):
				errors.append(id + ": invalid config_directories." + kind)
				continue
			var directory: String = value.to_lower()
			if used.has(directory):
				errors.append("Protocol config directory collision: " + id + " / " + used[directory])
			used[directory] = id
