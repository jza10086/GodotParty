## Internal manifest catalog shared by source, installed packs and the real lobby.
extends RefCounted

const Paths = preload("res://core/config/party_paths.gd")
const External = preload("res://core/content/party_external_files.gd")
const Data = preload("res://core/runtime/party_data.gd")
const Schema = preload("res://core/config/party_schema.gd")
const Localization = preload("res://core/i18n/party_localization.gd")
var i18n: RefCounted = Localization.new()
const PlayerCounts = preload("res://core/config/party_player_counts.gd")
const Versions = preload("res://core/content/party_versions.gd")
const PackageHash = preload("res://core/content/party_package_hash.gd")
const KINDS: Array[String] = ["maingame", "minigame", "protocols", "avatars", "assets"]
var packages: Dictionary = {}
var _schemas: Dictionary = {}
var errors: Array[String] = []
var unavailable: Dictionary = {}
var artifacts: Dictionary = {}
var adapter_issues: Dictionary = {}

func scan() -> Error:
	packages.clear()
	_schemas.clear()
	errors.clear()
	for kind: String in ["protocols", "maingame", "minigame", "assets"]:
		var root: String = "res://games/" + kind
		if not DirAccess.dir_exists_absolute(root):
			continue
		for directory: String in DirAccess.get_directories_at(root):
			var path: String = root.path_join(directory).path_join("manifest.json")
			if "manifest.json" in DirAccess.get_files_at(path.get_base_dir()):
				register_manifest(path)
				if kind == "protocols":
					var avatars: String = path.get_base_dir().path_join("avatars")
					if not DirAccess.dir_exists_absolute(avatars):
						continue
					for avatar: String in DirAccess.get_directories_at(avatars):
						register_manifest(avatars.path_join(avatar).path_join("manifest.json"))
	_validate_config_directories()
	_cache_adapter_issues()
	return OK if errors.is_empty() else ERR_INVALID_DATA

## Asset identity comes from its directory, never a second author-maintained ID.
static func read_manifest(path: String) -> Dictionary:
	var manifest: Dictionary = Data.read_json(path)
	manifest["id"] = path.get_base_dir().get_file()
	if manifest.get("kind") == "avatars":
		manifest["owner_protocol"] = path.get_base_dir().get_base_dir().get_base_dir().get_file()
	return manifest

func register_manifest(path: String) -> Error:
	var manifest: Dictionary = read_manifest(path)
	var issue: String = validate_manifest(manifest)
	if not issue.is_empty():
		errors.append(path + ": " + issue)
		return ERR_INVALID_DATA
	var relative: String = Paths.package_relative(manifest)
	if not path.get_base_dir().ends_with("games/" + relative):
		errors.append("Package path must match its kind and owner: " + path)
		return ERR_INVALID_DATA
	var id: String = manifest.id
	if packages.has(id):
		errors.append("DUPLICATE_PACKAGE: " + id)
		return ERR_ALREADY_EXISTS
	manifest["_declaration"] = manifest.duplicate(true)
	manifest["_root"] = path.get_base_dir()
	var metadata: Dictionary = source_metadata(manifest)
	manifest.merge(metadata)
	packages[id] = manifest
	i18n.declare_package(id, manifest.localization, manifest._root)
	return OK

## Build tools extract content-owned definitions once. Installed catalogs use the hash-covered descriptor.
static func source_metadata(manifest: Dictionary) -> Dictionary:
	var root: String = manifest._root
	var result: Dictionary = {}
	if manifest.kind in ["maingame", "minigame"]:
		result.entry = "game.tscn"
		var scene: PackedScene = load(root.path_join(result.entry))
		var entry: Script = _entry_script(scene.get_state())
		result.merge(entry.party_definition())
	elif manifest.kind == "protocols":
		result.entry = "protocol.gd"
		var entry: Script = load(root.path_join(result.entry))
		result.merge(entry.party_definition())
	elif manifest.kind == "avatars":
		var entry: Script = load(root.path_join("appearance.gd"))
		result.appearance_resources = entry.choices()
	var conventions: Dictionary = {"config_schema": "settings.gd", "config_panel": "config_panel.tscn", "player_config_panel": "profile_panel.tscn", "config_validator": "config_validator.gd", "settings_runtime": "settings_runtime.gd", "room_scene": "room.tscn"}
	for key: String in conventions:
		if FileAccess.file_exists(root.path_join(conventions[key])):
			result[key] = conventions[key]
	for extension: String in ["png", "svg", "webp", "jpg"]:
		if FileAccess.file_exists(root.path_join("cover." + extension)):
			result.cover = "cover." + extension
			break
	result.localization = {"supported_locales": [], "fallback_locale": "zh_Hans", "translations": {}}
	for file: String in (DirAccess.get_files_at(root.path_join("i18n")) if DirAccess.dir_exists_absolute(root.path_join("i18n")) else PackedStringArray()):
		if file.ends_with(".po"):
			var locale: String = file.get_basename()
			result.localization.supported_locales.append(locale)
			result.localization.translations[locale] = "i18n/" + file
	if manifest.kind == "minigame":
		result.adapters = []
		for file: String in (DirAccess.get_files_at(root.path_join("adapters")) if DirAccess.dir_exists_absolute(root.path_join("adapters")) else PackedStringArray()):
			if file.ends_with(".gd"):
				var adapter_script: Script = load(root.path_join("adapters/" + file))
				var adapter: Dictionary = adapter_script.party_definition()
				adapter.protocol = {"id": file.get_basename()}
				adapter.entry = "adapters/" + file
				result.adapters.append(adapter)
		result.playable = not result.adapters.is_empty()
	return result

static func _entry_script(state: SceneState) -> Script:
	for index: int in state.get_node_property_count(0):
		if state.get_node_property_name(0, index) == &"script":
			return state.get_node_property_value(0, index)
	var inherited: PackedScene = state.get_node_instance(0)
	return _entry_script(inherited.get_state())

## Freeze validated descriptors once after startup mounting. No menu/join path rescans disk.
func use_installed(descriptions: Dictionary, roots: Dictionary, failures: Dictionary) -> Error:
	packages.clear()
	_schemas.clear()
	artifacts.clear()
	unavailable = failures.duplicate()
	for id: String in descriptions:
		if unavailable.has(id):
			continue
		var description: Dictionary = descriptions[id]
		var manifest: Dictionary = description.declaration.duplicate(true)
		manifest.id = id
		if description.kind == "avatars":
			manifest.owner_protocol = description.owner_protocol
		manifest["_declaration"] = manifest.duplicate(true)
		manifest["_root"] = "res://games/" + Paths.package_relative(description)
		manifest.package_hash = description.package_hash
		manifest.merge(description.content.duplicate(true))
		packages[id] = manifest
		var distribution_files: Array[Dictionary] = []
		var names: Array = ["content.pck", "content.pck.json"]
		names.append_array(description.external_files)
		for name: String in names:
			var file: FileAccess = FileAccess.open(str(roots[id]).path_join(name), FileAccess.READ)
			if file == null:
				errors.append("Cannot open distribution artifact: " + id + "/" + name)
				return FileAccess.get_open_error()
			distribution_files.append({"path": name, "size": file.get_length()})
			file.close()
		artifacts[id] = {"root": roots[id], "description": description.duplicate(true), "files": distribution_files}
		i18n.declare_package(id, manifest.localization, manifest._root)
	_cache_adapter_issues()
	return OK

func _cache_adapter_issues() -> void:
	adapter_issues.clear()
	for id: String in ids("minigame"):
		for item: Dictionary in packages[id].adapters:
			var issue: String = _dependencies(item.get("dependencies", {}), {}, {})
			if not protocol_matches(item.protocol):
				issue = "缺少协议：" + item.protocol.id
			if not issue.is_empty():
				adapter_issues[id + "/" + item.protocol.id] = issue

func validate_manifest(manifest: Dictionary) -> String:
	for key: String in ["name", "kind", "package_version", "framework_version", "remark"]:
		if not manifest.get(key) is String or (key != "remark" and manifest[key].is_empty()):
			return "Invalid declaration field: " + key
	for key: String in manifest:
		if key not in ["name", "kind", "package_version", "framework_version", "remark", "supported_languages", "dependencies", "id", "owner_protocol"]:
			return "Unsupported declaration field: " + key
	var languages: Variant = manifest.get("supported_languages")
	if not languages is Array or languages.is_empty():
		return "supported_languages must be a nonempty array"
	for language: Variant in languages:
		if not language is String or language.strip_edges().is_empty() or language != language.strip_edges() or languages.count(language) != 1:
			return "Invalid or duplicate supported language"
	if manifest.kind not in KINDS or Paths.package_relative(manifest).is_empty():
		return "Invalid package kind/directory"
	if Versions.parse(manifest.package_version).is_empty() or Versions.parse(manifest.framework_version).is_empty():
		return "Versions must be numeric major.minor.patch triples"
	if not manifest.get("dependencies", {}) is Dictionary:
		return "Dependencies must be an object"
	if manifest.kind == "assets" and not manifest.get("dependencies", {}).is_empty():
		return "Asset packs must be dependency-free"
	for dependency: Variant in manifest.get("dependencies", {}):
		if not dependency is String or not Data.identifier(dependency) or not Versions.valid_range(manifest.dependencies[dependency]):
			return "Invalid dependency/version range"
	return ""

func _protocol_reference(value: Variant) -> bool:
	return value is Dictionary and value.get("id") is String and Data.identifier(value.id)

func get_package(id: String) -> Dictionary:
	var result: Dictionary = packages.get(id, {}).duplicate(true)
	if not result.is_empty() and result.kind not in ["avatars", "assets"]:
		for key: String in ["name", "introduction"]:
			if result.get(key) is String and not result[key].is_empty() and result.localization.translations.has("zh_Hans") and i18n.has_message(id, result[key]):
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
	if not External.safe_path(relative):
		push_error("Invalid external path: " + id + "/" + relative)
		return ""
	return str(artifacts[id].root).path_join(relative)

func load_entry(id: String) -> Resource:
	var manifest: Dictionary = packages.get(id, {})
	return load(path(id, manifest.get("entry", ""))) if not manifest.is_empty() else null

func protocol_matches(reference: Dictionary) -> bool:
	return packages.get(reference.get("id", ""), {}).get("kind") == "protocols" and not unavailable.has(reference.id)

func adapter(mini: String, protocol_id: String) -> Dictionary:
	var manifest: Dictionary = packages.get(mini, {})
	if manifest.get("kind") != "minigame" or unavailable.has(mini):
		return {}
	for item: Dictionary in manifest.adapters:
		if item.protocol.id == protocol_id and not adapter_issues.has(mini + "/" + protocol_id):
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

## Advertise the resolved dependency set for the current join or start phase.
## Raw manifest names are stable across UI languages; IDs identify packages.
func connection_requirements(selected: Dictionary) -> Dictionary:
	var required: Dictionary = {}
	for id: String in selected:
		var manifest: Dictionary = packages[id]
		required[id] = {"version": manifest.package_version, "hash": manifest.package_hash}
	return {"framework": {"version": Data.VERSION}, "packages": required}

func requirements_issue(required: Variant) -> String:
	if not required is Dictionary or not required.get("framework") is Dictionary or not required.get("packages") is Dictionary or not required.framework.get("version") is String:
		return "房主未提供有效的框架与内容包清单"
	var issues: Array[String] = []
	if required.framework.version != Data.VERSION:
		issues.append("框架版本不同（当前版本：%s；所需版本：%s）" % [Data.VERSION, required.framework.version])
	for id: Variant in required.packages:
		var entry: Variant = required.packages[id]
		if not id is String or not Data.identifier(id) or not entry is Dictionary or Versions.parse(entry.get("version")).is_empty() or not PackageHash.valid(entry.get("hash")):
			return "房主内容包清单格式无效"
		if not packages.has(id):
			issues.append("缺少内容包 %s（所需版本：%s）" % [id, entry.version])
		elif packages[id].package_version != entry.version:
			issues.append("%s 版本不同（当前：%s；所需：%s）" % [id, packages[id].package_version, entry.version])
		elif packages[id].package_hash != entry.hash:
			issues.append("%s 内容不同（版本：%s）" % [id, entry.version])
	return "\n".join(issues)

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
			var present: bool = packages.has(ref.package_id) and Data.relative_path(ref.resource_path)
			if present:
				var target: String = path(ref.package_id, ref.resource_path)
				var index: Array = artifacts[ref.package_id].description.files
				present = index.has(target) or index.has(target + ".import")
			if not present:
				return Data.failure("RESOURCE_MISSING", "玩家形象资源不存在：%s/%s（内容包版本：%s）。请在协议资料中重新选择头像或形象。" % [ref.package_id, ref.resource_path, pack.get("package_version", "未安装")])
			error = _visit(ref["package_id"], selected, visiting)
			if not error.is_empty():
				return Data.failure("DEPENDENCY_MISSING", error)
	return {"ok": true, "packages": selected}

func _visit(id: String, selected: Dictionary, visiting: Dictionary) -> String:
	if visiting.has(id):
		return "Dependency cycle: " + id
	if selected.has(id):
		return ""
	if unavailable.has(id):
		return unavailable[id]
	if not packages.has(id):
		return "缺少内容包：" + id
	visiting[id] = true
	var manifest: Dictionary = packages[id]
	if manifest.framework_version != Data.VERSION:
		return id + " requires framework " + manifest.framework_version
	var issue: String = _dependencies(manifest.get("dependencies", {}), selected, visiting)
	if not issue.is_empty():
		return issue
	visiting.erase(id)
	selected[id] = {"version": manifest.package_version, "hash": manifest.get("package_hash", "")}
	return ""

func _dependencies(dependencies: Dictionary, selected: Dictionary, visiting: Dictionary) -> String:
	for id: String in dependencies:
		if not Versions.matches(packages.get(id, {}).get("package_version", ""), dependencies[id]):
			return "%s 依赖版本不符（当前版本：%s；所需版本：%s）" % [id, packages.get(id, {}).get("package_version", "未安装"), dependencies[id]]
		var error: String = _visit(id, selected, visiting)
		if not error.is_empty():
			return error
	return ""

func _collect_refs(value: Variant, output: Array) -> void:
	if value is Dictionary:
		if value.get("package_id") is String and value.get("resource_path") is String:
			output.append(value)
		for item: Variant in value.values():
			_collect_refs(item, output)
	elif value is Array:
		for item: Variant in value:
			_collect_refs(item, output)

func asset(ref: Dictionary, active: Dictionary) -> Resource:
	var id: String = ref.get("package_id", "")
	var relative: String = ref.get("resource_path", "")
	if not active.has(id) or not Data.relative_path(relative):
		return null
	return load(path(id, relative))

func _prepare_schema(id: String) -> String:
	var manifest: Dictionary = packages[id]
	if _schemas.has(id):
		return ""
	var configuration: Dictionary = Schema.empty()
	if manifest.has("config_schema"):
		var declaration: Script = load(path(id, manifest.config_schema))
		configuration = declaration.schema()
	var schema_issue: String = Schema.validate(configuration, manifest.kind)
	if schema_issue.is_empty():
		schema_issue = PlayerCounts.validate_fields(manifest, configuration)
	if not schema_issue.is_empty():
		return id + ": " + schema_issue
	_schemas[id] = configuration
	return ""

## Publishing validates the author declaration; Godot reports resource errors at actual load.
func publication_issue(id: String) -> String:
	return validate_manifest(packages[id]._declaration)

func schema(id: String) -> Dictionary:
	if not packages.has(id):
		return Schema.empty()
	var issue: String = _prepare_schema(id)
	if not issue.is_empty():
		push_error(issue)
		return {}
	return _schemas[id].duplicate(true) if packages[id].kind == "assets" else i18n.localize_schema(id, _schemas[id])

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

## Match Godot's ignored-directory boundary, including archived prototypes and their import remaps.
static func files(root: String) -> Array[String]:
	var result: Array[String] = []
	if FileAccess.file_exists(root.path_join(".gdignore")):
		return result
	for file: String in DirAccess.get_files_at(root):
		if file.begins_with(".") or file.contains("~") or file.get_extension().to_lower() in ["tmp", "bak", "pending"]:
			continue
		result.append(root.path_join(file))
	var package_root: bool = "manifest.json" in DirAccess.get_files_at(root)
	var protocol_root: bool = package_root and Data.read_json(root.path_join("manifest.json")).get("kind") == "protocols"
	for directory: String in DirAccess.get_directories_at(root):
		if not directory.begins_with(".") and not (directory == "config" and package_root) and not (protocol_root and directory == "avatars"):
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
