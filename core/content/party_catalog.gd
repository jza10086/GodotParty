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
const Selection = preload("res://core/content/party_content_selection.gd")
const KINDS: Array[String] = ["maingame", "minigame", "protocols", "avatars", "assets"]
var source_mode: bool = false
var last_error: String = ""
var package_store: RefCounted
var _covers: Dictionary = {}

var packages: Dictionary = {}
var _schemas: Dictionary = {}
var _schema_labels: Dictionary = {}
var errors: Array[String] = []
var unavailable: Dictionary = {}
var artifacts: Dictionary = {}
var adapter_issues: Dictionary = {}

func _init() -> void:
	i18n.content_catalog = weakref(self)

func scan() -> Error:
	source_mode = true
	artifacts.clear()
	unavailable.clear()
	packages.clear()
	_schemas.clear()
	_schema_labels.clear()
	_covers.clear()
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
	unavailable = Selection.unavailable_packages(packages)
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

## Build tools extract lightweight definitions once; installed catalogs read only descriptors.
static func source_metadata(manifest: Dictionary) -> Dictionary:
	var root: String = manifest._root
	var result: Dictionary = {}
	if manifest.kind in ["maingame", "minigame", "protocols"]:
		result.entry = "protocol.gd" if manifest.kind == "protocols" else "game.tscn"
		var definition: Script = load(root.path_join("definition.gd"))
		result.merge(definition.party_definition())
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

## Freeze descriptors without mounting content. No menu/join path rescans disk.
func use_installed(store: RefCounted) -> Error:
	source_mode = false
	package_store = store
	packages.clear()
	_schemas.clear()
	_schema_labels.clear()
	_covers.clear()
	errors.clear()
	artifacts.clear()
	unavailable = store.unavailable
	for id: String in store.installed:
		if unavailable.has(id):
			continue
		var description: Dictionary = store.installed[id]
		var manifest: Dictionary = description.declaration.duplicate(true)
		manifest.id = id
		if description.kind == "avatars":
			manifest.owner_protocol = description.owner_protocol
		manifest["_declaration"] = manifest.duplicate(true)
		manifest["_root"] = "res://games/" + Paths.package_relative(description)
		manifest.build_id = description.build_id
		manifest.merge(description.content.duplicate(true))
		packages[id] = manifest
		artifacts[id] = {"root": store.roots[id], "description": description}
		i18n.declare_package(id, manifest.localization, manifest._root)
	_cache_adapter_issues()
	return OK

## Only a requested transfer opens distribution files; catalog discovery never reads PCK bytes.
func distribution_files(id: String) -> Array[Dictionary]:
	var artifact: Dictionary = artifacts[id]
	var result: Array[Dictionary] = []
	var names: Array = ["content.pck.json"]
	names.append_array(artifact.description.payload_files)
	for name: String in names:
		var file: FileAccess = FileAccess.open(String(artifact.root).path_join(name), FileAccess.READ)
		if file == null:
			push_error("Cannot read distribution file: " + id + "/" + name)
			return []
		result.append({"path": name, "size": file.get_length()})
	return result

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
		if key not in ["name", "kind", "package_version", "framework_version", "remark", "supported_languages", "dependencies", "special_type", "songs", "id", "owner_protocol"]:
			return "Unsupported declaration field: " + key
	if manifest.has("special_type"):
		if manifest.kind != "assets" or not manifest.special_type is String or not Data.identifier(manifest.special_type):
			return "special_type must identify an asset package type"
	if manifest.has("songs"):
		if manifest.get("special_type") != "rhythm_library" or not manifest.songs is Array or manifest.songs.is_empty():
			return "songs requires a nonempty rhythm_library resource list"
		for song: Variant in manifest.songs:
			if not song is String or not Data.relative_path(song) or song != song.simplify_path() or song.get_extension() not in ["tres", "res"] or manifest.songs.count(song) != 1:
				return "Invalid or duplicate song resource path"
	elif manifest.get("special_type") == "rhythm_library":
		return "Rhythm library requires songs"
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

## Discover metadata only. The room closure freezes the host's candidate libraries.
func asset_libraries(special_type: String, active: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in ids("assets"):
		if (not active.is_empty() and not active.has(id)) or unavailable.has(id):
			continue
		var manifest: Dictionary = packages[id]
		if manifest.get("special_type", "") == special_type:
			result.append({"id": id, "name": manifest.name, "version": manifest.package_version, "songs": manifest.get("songs", []).duplicate()})
	return result

## Only metadata is added to the room; activation still waits for resource use.
func library_dependencies(id: String, selected: Dictionary, library_scope: Dictionary = {}) -> String:
	for type_name: String in packages[id].get("asset_types", []):
		var libraries: Array[Dictionary] = asset_libraries(type_name, library_scope)
		if libraries.is_empty():
			return "缺少资产包类型：" + type_name + "（" + packages[id].name + "）"
		for library: Dictionary in libraries:
			var issue: String = _visit(library.id, selected, {})
			if not issue.is_empty():
				return issue
	return ""

func _protocol_reference(value: Variant) -> bool:
	return value is Dictionary and value.get("id") is String and Data.identifier(value.id)

## Display names are catalog data, never a reason to activate translations or gameplay.
func get_package(id: String) -> Dictionary:
	return packages.get(id, {}).duplicate(true)

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
	return ProjectSettings.globalize_path(path(id, relative)) if source_mode else str(artifacts[id].root).path_join(relative)

## Resolve only the requested package and dependencies. Pool membership never activates content.
func activate(id: String, protocol_id: String = "") -> Error:
	last_error = ""
	var selected: Dictionary = {}
	var issue: String = _visit(id, selected, {})
	if issue.is_empty() and not protocol_id.is_empty() and packages[id].kind == "minigame":
		var binding: Dictionary = adapter(id, protocol_id)
		if binding.is_empty():
			issue = "Missing adapter: " + id + "/" + protocol_id
		else:
			issue = _dependencies(binding.get("dependencies", {}), selected, {})
	if not issue.is_empty():
		last_error = issue
		return ERR_INVALID_DATA
	if source_mode:
		return OK
	var error: Error = package_store.activate(selected.keys())
	last_error = package_store.last_error if error != OK else ""
	return error

func resource(id: String, relative: String) -> Resource:
	if activate(id) != OK:
		push_error(last_error)
		return null
	return load(path(id, relative))

func load_entry(id: String) -> Resource:
	return resource(id, packages[id].entry) if packages.has(id) else null

## Preview images are loose metadata, not runtime PCK resources. Keep a bounded UI cache.
func cover(id: String) -> Texture2D:
	if _covers.has(id):
		var cached: Texture2D = _covers[id]
		_covers.erase(id)
		_covers[id] = cached
		return cached
	var image_path: String = ""
	if source_mode:
		if packages[id].has("cover"):
			image_path = ProjectSettings.globalize_path(path(id, packages[id].cover))
	elif artifacts[id].description.has("preview"):
		image_path = String(artifacts[id].root).path_join(artifacts[id].description.preview)
	if image_path.is_empty():
		return preload("res://core/ui/components/assets/godot_icon.svg")
	var image: Image = Image.load_from_file(image_path)
	if image == null:
		return null
	if maxi(image.get_width(), image.get_height()) > 256:
		var ratio: float = 256.0 / maxi(image.get_width(), image.get_height())
		image.resize(maxi(1, roundi(image.get_width() * ratio)), maxi(1, roundi(image.get_height() * ratio)))
	var texture: Texture2D = ImageTexture.create_from_image(image)
	if _covers.size() >= 32:
		_covers.erase(_covers.keys()[0])
	_covers[id] = texture
	return texture

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
		required[id] = {"version": manifest.package_version}
		if not source_mode:
			required[id].build_id = manifest.build_id
	return {"mode": "source" if source_mode else "pck", "framework": {"version": Data.VERSION}, "packages": required}

func requirements_issue(required: Variant) -> String:
	if not required is Dictionary or not required.get("framework") is Dictionary or not required.get("packages") is Dictionary or not required.framework.get("version") is String:
		return "房主未提供有效的框架与内容包清单"
	if required.get("mode") not in ["source", "pck"]:
		return "房主未声明有效的内容运行模式"
	if (required.mode == "source") != source_mode:
		return "编辑器源码测试与发布版不能互联"
	var issues: Array[String] = []
	if required.framework.version != Data.VERSION:
		issues.append("框架版本不同（当前版本：%s；所需版本：%s）" % [Data.VERSION, required.framework.version])
	for id: Variant in required.packages:
		var entry: Variant = required.packages[id]
		if not id is String or not Data.identifier(id) or not entry is Dictionary or Versions.parse(entry.get("version")).is_empty() or (not source_mode and (not entry.get("build_id") is String or entry.build_id.length() != 32 or not entry.build_id.is_valid_hex_number(false))) or (source_mode and entry.has("build_id")):
			return "房主内容包清单格式无效"
		if not packages.has(id):
			issues.append("缺少内容包 %s（所需版本：%s）" % [id, entry.version])
		elif unavailable.has(id):
			issues.append(id + " 不可用：" + str(unavailable[id]))
		elif packages[id].package_version != entry.version:
			issues.append("%s 版本不同（当前：%s；所需：%s）" % [id, packages[id].package_version, entry.version])
		elif not source_mode and packages[id].build_id != entry.build_id:
			issues.append("%s 内容不同（版本：%s）" % [id, entry.version])
	return "\n".join(issues)

func resolve(main_id: String, pools: Dictionary, appearances: Array = [], library_scope: Dictionary = {}) -> Dictionary:
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
				error = library_dependencies(id, selected, library_scope)
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
				if source_mode:
					present = ResourceLoader.exists(target)
				else:
					present = pack.get("appearance_resources", {}).has(ref.resource_path)
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
	selected[id] = {"version": manifest.package_version}
	if not source_mode:
		selected[id].build_id = manifest.build_id
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
	return resource(id, relative)

func _prepare_schema(id: String) -> String:
	var manifest: Dictionary = packages[id]
	if _schemas.has(id):
		return ""
	var configuration: Dictionary = Schema.empty()
	if not source_mode:
		var artifact: Dictionary = artifacts[id]
		var metadata: Dictionary = Data.read_json(String(artifact.root).path_join(artifact.description.settings))
		if not metadata.get("schema") is Dictionary or not metadata.get("localized") is Dictionary:
			return "Invalid settings metadata: " + id
		configuration = metadata.schema
		for locale: String in manifest.localization.supported_locales:
			if not metadata.localized.get(locale) is Dictionary:
				return "Missing settings language: " + id + "/" + locale
		_schema_labels[id] = metadata.localized
	elif manifest.has("config_schema"):
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
	return _schemas[id].duplicate(true)

func localized_schema(id: String) -> Dictionary:
	var value: Dictionary = schema(id)
	if packages[id].kind == "assets" or packages[id].localization.supported_locales.is_empty():
		return value
	if not source_mode:
		return _schema_labels[id][i18n.effective_locale(id)].duplicate(true)
	return i18n.localize_schema(id, value)

func fields(id: String, audience: String = "room") -> Array:
	return Schema.fields(localized_schema(id), audience)

func defaults(id: String) -> Dictionary:
	return Schema.defaults(schema(id), "room")

## Catalog/rule snapshots validate data only. Explicit settings edits and activity entry may run package code.
func validate_settings(id: String, value: Dictionary, run_custom: bool = false) -> Dictionary:
	if not packages.has(id):
		return Data.failure("PACKAGE_MISSING", id)
	var issue: String = _prepare_schema(id)
	if not issue.is_empty():
		return Data.failure("INVALID_SCHEMA", issue)
	var report: Dictionary = Schema.values(_schemas[id], value, "room")
	if not report.ok:
		return report
	var manifest: Dictionary = packages.get(id, {})
	if run_custom and manifest.has("config_validator"):
		var script: Script = resource(id, manifest.config_validator)
		var checked: Dictionary = script.new().validate(report.value.duplicate(true))
		if not checked.get("ok", false):
			return checked
	return report

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


## Background resource loading keeps audio decoding off the menu/game thread.
func asset_async(ref: Dictionary, active: Dictionary) -> Resource:
	var id: String = ref.get("package_id", "")
	var relative: String = ref.get("resource_path", "")
	if not active.has(id) or not Data.relative_path(relative):
		return null
	if activate(id) != OK:
		push_error(last_error)
		return null
	var target: String = path(id, relative)
	var error: Error = ResourceLoader.load_threaded_request(target)
	if error != OK:
		push_error("Cannot request asset: " + target + " · " + error_string(error))
		return null
	while ResourceLoader.load_threaded_get_status(target) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await Engine.get_main_loop().process_frame
	if ResourceLoader.load_threaded_get_status(target) != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("Cannot load asset: " + target)
		return null
	return ResourceLoader.load_threaded_get(target)
