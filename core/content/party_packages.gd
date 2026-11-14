## Source and PCK packaging share manifests. Mounting never replaces framework files.
extends RefCounted
const Paths = preload("res://core/config/party_paths.gd")
const External = preload("res://core/content/party_external_files.gd")
const ScriptClasses = preload("res://core/content/party_script_classes.gd")
const Versions = preload("res://core/content/party_versions.gd")
const Selection = preload("res://core/content/party_content_selection.gd")
const Data = preload("res://core/runtime/party_data.gd")
const Catalog = preload("res://core/content/party_catalog.gd")
const ExportFiles = preload("res://core/content/party_export_files.gd")
var last_error: String = ""
var mounted: Dictionary = {}
var installed: Dictionary = {}
var unavailable: Dictionary = {}
var roots: Dictionary = {}
var _directory: String = ""

func export_source(catalog: RefCounted, id: String, output: String) -> Error:
	if output.get_file().get_basename() != id:
		return _error("Source ZIP filename must match package ID")
	if not catalog.packages.has(id):
		return ERR_DOES_NOT_EXIST
	var issue: String = catalog.publication_issue(id)
	if not issue.is_empty():
		return _error(issue)
	var manifest: Dictionary = catalog.packages[id]
	var root: String = manifest["_root"]
	var payload: Dictionary = External.inventory(root)
	if not payload.ok:
		return _error(payload.error)
	var collected: Dictionary = ExportFiles.collect(root)
	if not collected.ok:
		return _error(collected.error)
	var writer: ZIPPacker = ZIPPacker.new()
	var error: Error = writer.open(output)
	if error != OK:
		return error
	for directory: String in payload.directories:
		error = writer.start_file(directory + "/")
		if error == OK:
			error = writer.close_file()
		if error != OK:
			writer.close()
			return error
	for path: String in collected.files:
		error = writer.start_file(path.trim_prefix(root + "/"))
		if error == OK:
			error = writer.write_file(FileAccess.get_file_as_bytes(path))
		if error == OK:
			error = writer.close_file()
		if error != OK:
			writer.close()
			return error
	return writer.close()

## A folder is recognized by its descriptor or bundle index; physical category names are optional.
static func descriptors(directory: String) -> Array[String]:
	var result: Array[String] = []
	if FileAccess.file_exists(directory.path_join("content.pck.json")):
		result.append(directory.path_join("content.pck.json"))
		# The existing protocol layout may contain independently installed avatars.
		var avatars: String = directory.path_join("avatars")
		if DirAccess.dir_exists_absolute(avatars):
			result.append_array(descriptors(avatars))
		return result
	for child: String in DirAccess.get_directories_at(directory):
		if child.begins_with(".") or child in ["core", "tmp", "config", "external"]:
			continue
		result.append_array(descriptors(directory.path_join(child)))
	result.sort()
	return result

## Distribution paths are relative to one package folder; personal config never belongs to payload.
static func safe_payload_path(value: Variant) -> bool:
	return value is String and Data.relative_path(value) and value == value.simplify_path() and value.get_slice("/", 0).to_lower() not in ["config", "tmp", "core"] and not value.begins_with(".")

static func valid_build_id(value: Variant) -> bool:
	return value is String and value.length() == 32 and value.is_valid_hex_number(false)

static func payload_files(description: Dictionary) -> Array:
	var result: Array = ["content.pck.json"]
	result.append_array(description.payload_files)
	return result

func validate_descriptor(description: Dictionary) -> String:
	if not description.get("declaration") is Dictionary or not description.get("content") is Dictionary:
		return "Missing package declaration/content definition"
	var declaration: Dictionary = description.declaration.duplicate(true)
	declaration.id = description.get("id")
	if description.get("kind") == "avatars":
		declaration.owner_protocol = description.get("owner_protocol")
	var issue: String = Catalog.new().validate_manifest(declaration)
	if not issue.is_empty():
		return issue
	if description.get("name") != declaration.name or description.get("kind") != declaration.kind or description.get("version") != declaration.package_version or description.get("framework_version") != declaration.framework_version or description.get("dependencies") != declaration.get("dependencies", {}):
		return "Descriptor identity differs from declaration"
	if not valid_build_id(description.get("build_id")) or not description.get("packs") is Array or description.packs.is_empty():
		return "Missing build identity/PCK list; re-export this package"
	if not description.get("payload_files") is Array or not description.get("external_files") is Array or not description.get("external_directories") is Array:
		return "Missing distribution payload index"
	var seen: Dictionary = {"content.pck.json": true}
	for path: Variant in description.payload_files:
		if not safe_payload_path(path) or seen.has(path.to_lower()):
			return "Invalid/conflicting distribution path"
		seen[path.to_lower()] = true
	for path: Variant in description.packs:
		if not path is String or not path.ends_with(".pck") or description.packs.count(path) != 1 or not seen.has(path.to_lower()):
			return "Invalid PCK path"
	for key: String in ["resource_index", "settings"]:
		if not description.get(key) is String or not seen.has(description[key].to_lower()):
			return "Missing " + key
	if description.has("preview") and (not description.preview is String or not seen.has(description.preview.to_lower())):
		return "Missing preview"
	for path: Variant in description.external_files:
		if not External.safe_path(path) or not seen.has(path.to_lower()):
			return "Invalid external payload"
	for path: Variant in description.external_directories:
		if not External.safe_path(path):
			return "Invalid external directory"
	return ""

func _validate_index(description: Dictionary) -> String:
	if not description.get("files") is Array or description.files.is_empty() or not description.get("uids") is Dictionary:
		return "Missing package file/UID index"
	var root: String = "res://games/" + Paths.package_relative(description)
	var seen: Dictionary = {}
	for path: Variant in description.files:
		if not path is String or not Data.relative_path(path.trim_prefix("res://")) or (not path.begins_with(root + "/") and not path.begins_with("res://.godot/imported/")) or seen.has(path):
			return "Invalid/conflicting package file path"
		if description.kind == "protocols" and path.begins_with(root + "/avatars/"):
			return "Avatar packs must be published separately"
		seen[path] = true
	if not seen.has(root.path_join("manifest.json")):
		return "Package index omits manifest.json"
	for uid_text: Variant in description.uids:
		var path: Variant = description.uids[uid_text]
		if not uid_text is String or ResourceUID.text_to_id(uid_text) == ResourceUID.INVALID_ID or not path is String or (not seen.has(path) and not seen.has(path + ".import")) or not path.begins_with(root + "/"):
			return "Invalid resource UID index"
	return ScriptClasses.validate(description.get("script_classes"), root, description.files)

## Discovery reads small descriptors only. PCKs, resource indices and payload bytes stay untouched.
func prepare(directory: String, replacements: Dictionary = {}, required: Array = []) -> Error:
	last_error = ""
	installed.clear()
	roots.clear()
	unavailable.clear()
	_directory = directory
	var candidates: Dictionary = {}
	for descriptor_path: String in descriptors(directory):
		var description: Dictionary = Data.read_json(descriptor_path)
		var id: String = str(description.get("id", descriptor_path.get_base_dir().get_file()))
		if candidates.has(id):
			return _error("Duplicate package ID: " + id)
		candidates[id] = {"description": description, "root": descriptor_path.get_base_dir()}
	for id: String in replacements:
		var root: String = replacements[id]
		candidates[id] = {"description": Data.read_json(root.path_join("content.pck.json")), "root": root}
	var declarations: Dictionary = {}
	for id: String in candidates:
		var candidate: Dictionary = candidates[id]
		var description: Dictionary = candidate.description
		var issue: String = validate_descriptor(description)
		if issue.is_empty() and description.id != id:
			issue = "Package identity differs: " + id
		if not issue.is_empty():
			unavailable[id] = issue
			continue
		installed[id] = description
		roots[id] = candidate.root
		var declaration: Dictionary = description.declaration.duplicate(true)
		declaration.id = id
		if description.kind == "avatars":
			declaration.owner_protocol = description.owner_protocol
		declarations[id] = declaration
	unavailable.merge(Selection.unavailable_packages(declarations))
	for id: String in required:
		if unavailable.has(id) or not installed.has(id):
			return _error("Update rejected: " + id + ": " + str(unavailable.get(id, "Missing package")))
		var issue: String = _check_payload(roots[id], installed[id])
		if not issue.is_empty():
			return _error(issue)
	return OK

## Called only for a requested dependency closure, before parsing any of its runtime scripts.
func activate(ids: Array) -> Error:
	var planned: Dictionary = mounted.duplicate()
	var additions: Array[String] = []
	for id: String in ids:
		if mounted.has(id):
			continue
		if unavailable.has(id) or not installed.has(id):
			return _error(id + ": " + str(unavailable.get(id, "Missing package")))
		var description: Dictionary = installed[id].duplicate(true)
		var issue: String = _check_payload(roots[id], description)
		if not issue.is_empty():
			return _activation_error(id, issue)
		var index: Dictionary = Data.read_json(String(roots[id]).path_join(description.resource_index))
		for key: String in ["files", "uids", "script_classes"]:
			if not index.has(key):
				return _activation_error(id, "Missing resource index field: " + key)
			description[key] = index[key]
		issue = _validate_index(description)
		if not issue.is_empty():
			return _activation_error(id, issue)
		planned[id] = description
		additions.append(id)
	if additions.is_empty():
		return OK
	var files: Dictionary = {}
	var uids: Dictionary = {}
	for id: String in planned:
		for path: String in planned[id].files:
			if files.has(path):
				return _error("Conflicting package path: " + path)
			files[path] = id
		for uid: String in planned[id].uids:
			var value: int = ResourceUID.text_to_id(uid)
			var path: String = planned[id].uids[uid]
			if (ResourceUID.has_id(value) and ResourceUID.get_id_path(value) != path) or (uids.has(uid) and uids[uid] != path):
				return _error("Conflicting resource UID: " + uid)
			uids[uid] = path
	var merged: Dictionary = ScriptClasses.merge(ProjectSettings.get_global_class_list(), planned)
	if not merged.ok:
		return _error(merged.error)
	for id: String in additions:
		for pack: String in planned[id].packs:
			if not ProjectSettings.load_resource_pack(String(roots[id]).path_join(pack), false):
				return _activation_error(id, "Cannot mount package: " + pack)
		for uid_text: String in planned[id].uids:
			var uid: int = ResourceUID.text_to_id(uid_text)
			if not ResourceUID.has_id(uid):
				ResourceUID.add_id(uid, planned[id].uids[uid_text])
		mounted[id] = planned[id]
	if merged.has_content_classes:
		var error: Error = ScriptClasses.register(_directory, merged.classes)
		if error != OK:
			return _error("Cannot register content classes: " + error_string(error))
	return OK

func _activation_error(id: String, message: String) -> Error:
	unavailable[id] = message
	return _error(id + ": " + message)

## Import a recognizable package folder. Updates remain restart-bound.
func install(source: String, directory: String) -> Error:
	var description: Dictionary = Data.read_json(source.path_join("content.pck.json"))
	var issue: String = validate_descriptor(description)
	if not issue.is_empty():
		return _error(issue)
	issue = _check_payload(source, description)
	if not issue.is_empty():
		return _error(issue)
	var destination: String = directory.path_join(description.id)
	if installed.has(description.id) or DirAccess.dir_exists_absolute(destination):
		return _error("已安装此包；请退出后替换内容文件，保留 config")
	var stage: String = directory.path_join("tmp/content_import/" + Data.token())
	for name: String in payload_files(description):
		var target: String = stage.path_join(name)
		var error: Error = DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		if error == OK:
			error = DirAccess.copy_absolute(source.path_join(name), target)
		if error != OK:
			return error
	for folder: String in description.external_directories:
		var error: Error = DirAccess.make_dir_recursive_absolute(stage.path_join(folder))
		if error != OK:
			return error
	return DirAccess.rename_absolute(stage, destination)

## Validates before writing; replacement is staged and the previous source stays in tmp.
func import_source(archive: String, destination: String = "res://games", replace_existing: bool = false) -> Error:
	last_error = ""
	var reader: ZIPReader = ZIPReader.new()
	var error: Error = reader.open(archive)
	if error != OK:
		return error
	var raw: Variant = JSON.parse_string(reader.read_file("manifest.json").get_string_from_utf8())
	var manifest: Dictionary = Data._json_numbers(raw) if raw is Dictionary else {}
	manifest["id"] = archive.get_file().get_basename()
	if manifest.get("kind") == "avatars":
		if not destination.trim_suffix("/").ends_with("/avatars"):
			reader.close()
			return _error("Choose the owning protocol avatars/ directory")
		manifest.owner_protocol = destination.trim_suffix("/").get_base_dir().get_file()
	var catalog: RefCounted = Catalog.new()
	var issue: String = catalog.validate_manifest(manifest)
	if not issue.is_empty():
		reader.close()
		return _error(issue)
	var target: String = destination.path_join(manifest.id) if manifest.kind == "avatars" else destination.path_join(Paths.package_relative(manifest))
	if DirAccess.dir_exists_absolute(target) and not replace_existing:
		reader.close()
		return ERR_ALREADY_EXISTS
	var entries: PackedStringArray = reader.get_files()
	var required: Array = manifest.get("resources", {}).values()
	for key: String in ["entry", "room_scene", "cover", "config_panel", "player_config_panel", "config_validator"]:
		if manifest.has(key):
			required.append(manifest[key])
	for adapter: Dictionary in manifest.get("adapters", []):
		if adapter.has("entry"):
			required.append(adapter["entry"])
	for path: String in required:
		if path not in entries:
			reader.close()
			return _error("Missing declared file: " + path)
	var classes: Dictionary = {}
	for item: Dictionary in ProjectSettings.get_global_class_list():
		if not str(item["path"]).begins_with(target + "/"):
			classes[item["class"]] = item["path"]
	var class_pattern: RegEx = RegEx.new()
	class_pattern.compile("(?m)^class_name\\s+([A-Za-z_][A-Za-z_0-9]*)")
	var uid_pattern: RegEx = RegEx.new()
	uid_pattern.compile('uid="(uid://[^"]+)"')
	for path: String in entries:
		if not Data.relative_path(path.trim_suffix("/")) or entries.count(path) != 1:
			reader.close()
			return _error("Invalid/duplicate archive path: " + path)
		var uid_text: String = ""
		var uid_path: String = path.trim_suffix(".uid")
		if path.ends_with(".import"):
			var import_config: ConfigFile = ConfigFile.new()
			if import_config.parse(reader.read_file(path).get_string_from_utf8()) != OK:
				reader.close()
				return _error("Invalid import settings: " + path)
			uid_text = import_config.get_value("remap", "uid", "")
			uid_path = path.trim_suffix(".import")
		elif path.ends_with(".uid"):
			uid_text = reader.read_file(path).get_string_from_utf8().strip_edges()
		elif path.ends_with(".tscn") or path.ends_with(".tres"):
			var match_uid: RegExMatch = uid_pattern.search(reader.read_file(path).get_string_from_utf8().get_slice("\n", 0))
			if match_uid != null:
				uid_text = match_uid.get_string(1)
		if not uid_text.is_empty():
			var uid: int = ResourceUID.text_to_id(uid_text)
			if uid == ResourceUID.INVALID_ID or (ResourceUID.has_id(uid) and ResourceUID.get_id_path(uid) != target.path_join(uid_path)):
				reader.close()
				return _error("UID conflict: " + path)
		if path.ends_with(".gd"):
			var found: RegExMatch = class_pattern.search(reader.read_file(path).get_string_from_utf8())
			if found != null:
				var name_value: String = found.get_string(1)
				if classes.has(name_value):
					reader.close()
					return _error("Global class conflict: " + name_value)
				classes[name_value] = path
	catalog.scan()
	for dependency: String in manifest.get("dependencies", {}):
		if not Versions.matches(catalog.get_package(dependency).get("package_version", ""), manifest["dependencies"][dependency]):
			reader.close()
			return _error("Import dependency first: " + dependency)
	var stage: String = "res://tmp/content_stage_" + Data.token()
	for path: String in entries:
		if path.ends_with("/"):
			error = DirAccess.make_dir_recursive_absolute(stage.path_join(path))
			if error != OK:
				reader.close()
				return error
			continue
		var output: String = stage.path_join(path)
		error = DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		if error != OK:
			reader.close()
			return error
		var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			reader.close()
			return FileAccess.get_open_error()
		file.store_buffer(reader.read_file(path))
		file.flush()
		error = file.get_error()
		file.close()
		if error != OK:
			reader.close()
			return error
	reader.close()
	var payload: Dictionary = External.inventory(stage)
	if not payload.ok:
		return _error(payload.error)
	error = DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	if error != OK:
		return error
	var backup: String = ""
	if DirAccess.dir_exists_absolute(target):
		backup = "res://tmp/content_backup_" + Data.token()
		error = DirAccess.rename_absolute(target, backup)
		if error != OK:
			return error
	error = DirAccess.rename_absolute(stage, target)
	if error != OK and not backup.is_empty():
		var restore_error: Error = DirAccess.rename_absolute(backup, target)
		if restore_error != OK:
			last_error = "Previous package preserved at " + backup
	return error

func _check_payload(directory: String, description: Dictionary) -> String:
	for relative: String in description.payload_files:
		if not FileAccess.file_exists(directory.path_join(relative)):
			return "Missing package payload: " + directory.path_join(relative)
	for relative: String in description.get("external_directories", []):
		if not DirAccess.dir_exists_absolute(directory.path_join(relative)):
			return "Missing external directory: " + directory.path_join(relative)
	return ""

func _error(message: String) -> Error:
	last_error = message
	return ERR_INVALID_DATA
