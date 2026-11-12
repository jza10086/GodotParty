## Source and PCK packaging share manifests. Mounting never replaces framework files.
extends RefCounted
const Paths = preload("res://core/config/party_paths.gd")
const External = preload("res://core/content/party_external_files.gd")
const ScriptClasses = preload("res://core/content/party_script_classes.gd")
const DESCRIPTOR_FORMAT: int = 3
const Data = preload("res://core/runtime/party_data.gd")
const Catalog = preload("res://core/content/party_catalog.gd")
var last_error: String = ""
var mounted: Dictionary = {}

func export_source(catalog: RefCounted, id: String, output: String) -> Error:
	if not catalog.packages.has(id):
		return ERR_DOES_NOT_EXIST
	var issue: String = catalog.publication_issue(id)
	if not issue.is_empty():
		return _error(issue)
	var manifest: Dictionary = catalog.packages[id]
	var root: String = manifest["_root"]
	var payload: Dictionary = External.inventory(root, manifest.get("external_files", []))
	if not payload.ok:
		return _error(payload.error)
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
	for path: String in Catalog.files(root):
		error = writer.start_file(path.trim_prefix(root + "/"))
		if error == OK:
			error = writer.write_file(FileAccess.get_file_as_bytes(path))
		if error == OK:
			error = writer.close_file()
		if error != OK:
			writer.close()
			return error
	return writer.close()

## Imported assets ship only their runtime outputs and remaps; source ZIPs retain originals.
func export_pack(catalog: RefCounted, id: String, output: String) -> Error:
	last_error = ""
	if not catalog.packages.has(id):
		return ERR_DOES_NOT_EXIST
	var issue: String = catalog.publication_issue(id)
	if not issue.is_empty():
		return _error(issue)
	var manifest: Dictionary = catalog.packages[id]
	var root: String = manifest["_root"]
	var payload: Dictionary = External.inventory(root, manifest.get("external_files", []))
	if not payload.ok:
		return _error(payload.error)
	var paths: Dictionary = {}
	var uid_index: Dictionary = {}
	var imported_sources: Array[String] = []
	for path: String in Catalog.files(root):
		var relative: String = path.trim_prefix(root + "/")
		if External.contains(manifest.get("external_files", []), relative.trim_suffix(".import").trim_suffix(".uid")):
			continue
		paths[path] = path
		if path.ends_with(".import"):
			var imported: ConfigFile = ConfigFile.new()
			if imported.load(path) != OK:
				return _error("Invalid import remap: " + path)
			var has_runtime_remap: bool = false
			for key: String in imported.get_section_keys("remap"):
				if key == "path" or key.begins_with("path."):
					var target: String = imported.get_value("remap", key)
					if not target.begins_with("res://.godot/imported/") or not FileAccess.file_exists(target):
						return _error("Missing/invalid imported resource: " + target)
					has_runtime_remap = true
			if has_runtime_remap:
				var source: String = path.trim_suffix(".import")
				imported_sources.append(source)
				if imported.has_section_key("remap", "uid"):
					uid_index[imported.get_value("remap", "uid")] = source
			for section: String in ["remap", "deps"]:
				for key: String in imported.get_section_keys(section):
					var value: Variant = imported.get_value(section, key)
					if value is String and value.begins_with("res://.godot/imported/"):
						paths[value] = value
					elif value is PackedStringArray:
						for dependency: String in value:
							if dependency.begins_with("res://.godot/imported/"):
								paths[dependency] = dependency
		if path.ends_with(".uid"):
			var uid: String = FileAccess.get_file_as_string(path).strip_edges()
			uid_index[uid] = path.trim_suffix(".uid")
		elif path.get_extension() in ["tscn", "tres", "res", "scn", "png", "svg", "glb", "ogg", "wav", "otf", "ttf"]:
			var uid: int = ResourceLoader.get_resource_uid(path)
			if uid != ResourceUID.INVALID_ID:
				uid_index[ResourceUID.id_to_text(uid)] = path
	# Remove originals after collection so directory iteration order cannot re-add them.
	for source: String in imported_sources:
		paths.erase(source)
	var packer: PCKPacker = PCKPacker.new()
	var error: Error = packer.pck_start(output)
	if error != OK:
		return error
	var index: Array[String] = []
	for path: String in paths:
		if not FileAccess.file_exists(path):
			return _error("Import the project before export; missing " + path)
		index.append(path)
		error = packer.add_file(path, paths[path])
		if error != OK:
			return error
	error = packer.flush()
	if error != OK:
		return error
	var description: Dictionary = {"format": DESCRIPTOR_FORMAT, "engine": Engine.get_version_info()["string"], "core": Data.VERSION, "id": id, "version": manifest["package_version"], "kind": manifest["kind"], "artifact": output.get_file(), "files": index, "uids": uid_index}
	description.script_classes = ScriptClasses.collect(paths)
	description.external_files = payload.files
	description.external_directories = payload.directories
	if manifest.kind == "avatars":
		description.owner_protocol = manifest.owner_protocol
	error = External.copy_payload(root, output.get_base_dir(), payload.files, payload.directories)
	if error != OK:
		return _error("Cannot copy external payload: " + error_string(error))

	var file: FileAccess = FileAccess.open(output + ".json", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(description, "\t"))
	return OK

## Only fixed install locations are scanned. Configuration files are never catalog entries.
static func descriptors(directory: String) -> Array[String]:
	var result: Array[String] = []
	for kind: String in ["protocols", "maingame", "minigame"]:
		var root: String = directory.path_join(kind)
		if not DirAccess.dir_exists_absolute(root):
			continue
		for id: String in DirAccess.get_directories_at(root):
			var package: String = root.path_join(id)
			if FileAccess.file_exists(package.path_join("content.pck.json")) or FileAccess.file_exists(package.path_join("content.pck")):
				result.append(package.path_join("content.pck.json"))
			var avatars: String = package.path_join("avatars")
			if kind == "protocols" and DirAccess.dir_exists_absolute(avatars):
				for avatar: String in DirAccess.get_directories_at(avatars):
					var avatar_path: String = avatars.path_join(avatar)
					if FileAccess.file_exists(avatar_path.path_join("content.pck.json")) or FileAccess.file_exists(avatar_path.path_join("content.pck")):
						result.append(avatar_path.path_join("content.pck.json"))
	result.sort()
	return result

func validate_descriptor(description: Dictionary) -> String:
	if description.get("format") != DESCRIPTOR_FORMAT:
		return "Unsupported package descriptor; re-export core and content together"
	if Paths.package_relative(description).is_empty() or not description.get("version") is String or description.version.is_empty():
		return "Invalid installed package descriptor"
	if not description.get("files") is Array or description.files.is_empty() or not description.get("uids") is Dictionary:
		return "Missing package file/UID index"
	if description.get("core") != Data.VERSION or description.get("engine") != Engine.get_version_info()["string"]:
		return "Package requires another core/engine build"
	var loose: Variant = description.get("external_files", [])
	var folders: Variant = description.get("external_directories", [])
	if not loose is Array or not folders is Array:
		return "Invalid external payload index"
	var external_seen: Dictionary = {}
	for entry: Variant in loose + folders:
		if not entry is String or not External.safe_path(entry) or external_seen.has(entry.to_lower()):
			return "Invalid/conflicting external payload path"
		external_seen[entry.to_lower()] = true
	for file: String in loose:
		for entry: String in external_seen:
			if entry.begins_with(file.to_lower() + "/"):
				return "External file conflicts with directory"
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

## Restart after installing/updating. Structural checks do not prove byte-for-byte equality.
func mount_directory(directory: String, choices: Dictionary = {}) -> Error:
	last_error = ""
	var paths: Dictionary = {}
	var uids: Dictionary = {}
	var planned: Dictionary = {}
	var existing_classes: Array[Dictionary] = ProjectSettings.get_global_class_list()
	for descriptor_path: String in descriptors(directory):
		var description: Dictionary = Data.read_json(descriptor_path)
		var issue: String = validate_descriptor(description)
		if not issue.is_empty():
			return _error(descriptor_path + ": " + issue)
		var expected: String = directory.path_join(Paths.package_relative(description))
		if descriptor_path.get_base_dir().simplify_path() != expected.simplify_path() or description.get("artifact") != "content.pck":
			return _error("Package installed under the wrong folder: " + descriptor_path)
		issue = _check_payload(expected, description)
		if not issue.is_empty():
			return _error(issue)
		var id: String = description.id
		var root: String = "res://games/" + Paths.package_relative(description)
		if FileAccess.file_exists(root.path_join("manifest.json")):
			var choice: String = choices.get(id, "")
			if choice == "source":
				continue
			if choice != "pck":
				return _error("SOURCE_SELECTION_REQUIRED: " + id + " has source and PCK; select source or pck and restart")
		if mounted.has(id) or planned.has(id):
			return _error("Duplicate installed package: " + id)
		for path: String in description.files:
			if paths.has(path):
				return _error("Conflicting package path: " + path)
			paths[path] = id
		for uid_text: String in description.uids:
			var uid: int = ResourceUID.text_to_id(uid_text)
			if (ResourceUID.has_id(uid) and ResourceUID.get_id_path(uid) != description.uids[uid_text]) or (uids.has(uid_text) and uids[uid_text] != description.uids[uid_text]):
				return _error("UID conflict: " + uid_text)
			uids[uid_text] = description.uids[uid_text]
		planned[id] = description
	var merged: Dictionary = ScriptClasses.merge(existing_classes, planned)
	if not merged.ok:
		return _error(merged.error)
	# Mount every resource first. No content script is parsed before its dependencies and types exist.
	for id: String in planned:
		var description: Dictionary = planned[id]
		var expected: String = directory.path_join(Paths.package_relative(description))
		var root: String = "res://games/" + Paths.package_relative(description)
		if not ProjectSettings.load_resource_pack(expected.path_join("content.pck"), false):
			return _error("Cannot mount " + expected)
		var manifest: Dictionary = Data.read_json(root.path_join("manifest.json"))
		if manifest.get("id") != id or manifest.get("package_version") != description.version or manifest.get("kind") != description.kind or Paths.package_relative(manifest) != Paths.package_relative(description):
			return _error("Mounted manifest differs from descriptor; restart required: " + id)
		for uid_text: String in description.uids:
			var uid: int = ResourceUID.text_to_id(uid_text)
			if not ResourceUID.has_id(uid):
				ResourceUID.add_id(uid, description.uids[uid_text])
		mounted[id] = description
	if planned.is_empty():
		return OK
	var catalog: RefCounted = Catalog.new()
	if catalog.scan() != OK:
		return _error(str(catalog.errors))
	for id: String in planned:
		for dependency: String in catalog.packages[id].get("dependencies", {}):
			var version: String = catalog.packages[id].dependencies[dependency]
			if catalog.get_package(dependency).get("package_version") != version:
				return _error(id + ": missing/conflicting dependency " + dependency + " " + version)
	if merged.has_content_classes:
		var error: Error = ScriptClasses.register(directory, merged.classes)
		if error != OK:
			return _error("Cannot register content script classes: " + error_string(error))
	for id: String in planned:
		for entry: Dictionary in planned[id].script_classes:
			var script: Script = load(entry.path)
			if script == null or (not script.can_instantiate() and not script.is_abstract()) or script.get_global_name() != entry["class"]:
				return _error(id + ": cannot load registered class " + entry["class"] + " at " + entry.path)
	return OK

## Install into its declared category; updating a running installation is deliberately refused.
func install(source: String, directory: String) -> Error:
	var description: Dictionary = Data.read_json(source + ".json")
	var issue: String = validate_descriptor(description)
	if not issue.is_empty():
		return _error(issue)
	if not FileAccess.file_exists(source):
		return ERR_FILE_NOT_FOUND
	issue = _check_payload(source.get_base_dir(), description)
	if not issue.is_empty():
		return _error(issue)
	var destination: String = directory.path_join(Paths.package_relative(description))
	var target: String = destination.path_join("content.pck")
	if FileAccess.file_exists(target) or FileAccess.file_exists(target + ".json"):
		return _error("已安装此包；请退出后替换 content.pck 和 content.pck.json，保留 config")
	var error: Error = DirAccess.make_dir_recursive_absolute(destination)
	if error != OK:
		return error
	error = External.copy_payload(source.get_base_dir(), destination, description.get("external_files", []), description.get("external_directories", []), true)
	if error != OK:
		return error
	error = DirAccess.copy_absolute(source, target + ".pending")
	if error != OK:
		return error
	description.artifact = "content.pck"
	var file: FileAccess = FileAccess.open(target + ".json.pending", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(description, "\t"))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		return error
	error = DirAccess.rename_absolute(target + ".pending", target)
	if error == OK:
		error = DirAccess.rename_absolute(target + ".json.pending", target + ".json")
	return error

## Validates before writing; replacement is staged and the previous source stays in tmp.
func import_source(archive: String, destination: String = "res://games", replace_existing: bool = false) -> Error:
	last_error = ""
	var reader: ZIPReader = ZIPReader.new()
	var error: Error = reader.open(archive)
	if error != OK:
		return error
	var raw: Variant = JSON.parse_string(reader.read_file("manifest.json").get_string_from_utf8())
	var manifest: Dictionary = Data._json_numbers(raw) if raw is Dictionary else {}
	var catalog: RefCounted = Catalog.new()
	var issue: String = catalog.validate_manifest(manifest)
	if not issue.is_empty():
		reader.close()
		return _error(issue)
	var target: String = destination.path_join(Paths.package_relative(manifest))
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
		if catalog.get_package(dependency).get("package_version") != manifest["dependencies"][dependency]:
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
	var payload: Dictionary = External.inventory(stage, manifest.get("external_files", []))
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
	for relative: String in description.get("external_files", []):
		if not FileAccess.file_exists(directory.path_join(relative)):
			return "Missing external file: " + directory.path_join(relative)
	for relative: String in description.get("external_directories", []):
		if not DirAccess.dir_exists_absolute(directory.path_join(relative)):
			return "Missing external directory: " + directory.path_join(relative)
	return ""

func _error(message: String) -> Error:
	last_error = message
	return ERR_INVALID_DATA
