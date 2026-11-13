## Source and PCK packaging share manifests. Mounting never replaces framework files.
extends RefCounted
const Paths = preload("res://core/config/party_paths.gd")
const External = preload("res://core/content/party_external_files.gd")
const ScriptClasses = preload("res://core/content/party_script_classes.gd")
const Versions = preload("res://core/content/party_versions.gd")
const PackageHash = preload("res://core/content/party_package_hash.gd")
const Selection = preload("res://core/content/party_content_selection.gd")
const Data = preload("res://core/runtime/party_data.gd")
const Catalog = preload("res://core/content/party_catalog.gd")
var last_error: String = ""
var mounted: Dictionary = {}
var installed: Dictionary = {}
var unavailable: Dictionary = {}
var roots: Dictionary = {}

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

## Only fixed install locations are scanned. Configuration files are never catalog entries.
static func descriptors(directory: String) -> Array[String]:
	var result: Array[String] = []
	for kind: String in ["protocols", "maingame", "minigame", "assets"]:
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
	if Paths.package_relative(description).is_empty() or not PackageHash.valid(description.get("package_hash")) or description.get("artifact") != "content.pck":
		return "Invalid package directory/artifact/hash"
	if not description.get("files") is Array or description.files.is_empty() or not description.get("uids") is Dictionary:
		return "Missing package file/UID index"
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

## Validate the final startup candidate set once, before mounting or replacing anything.
## Replacement roots point at staged payloads; successful results survive transaction publication.
func prepare(directory: String, replacements: Dictionary = {}, required: Array = []) -> Error:
	last_error = ""
	installed.clear()
	roots.clear()
	unavailable.clear()
	var candidates: Dictionary = {}
	for descriptor_path: String in descriptors(directory):
		var description: Dictionary = Data.read_json(descriptor_path)
		var relative: String = descriptor_path.get_base_dir().trim_prefix(directory.trim_suffix("/") + "/")
		var id: String = relative.get_file()
		if candidates.has(id):
			return _error("Duplicate package ID: " + id)
		candidates[id] = {"description": description, "root": descriptor_path.get_base_dir(), "relative": relative}
	for id: String in replacements:
		var root: String = replacements[id]
		var description: Dictionary = Data.read_json(root.path_join("content.pck.json"))
		candidates[id] = {"description": description, "root": root, "relative": Paths.package_relative(description)}
	var declarations: Dictionary = {}
	for id: String in candidates:
		var candidate: Dictionary = candidates[id]
		var description: Dictionary = candidate.description
		var issue: String = validate_descriptor(description)
		if issue.is_empty() and (description.id != id or Paths.package_relative(description) != candidate.relative):
			issue = "Package installed under the wrong folder: " + candidate.root
		if issue.is_empty() and description.framework_version != Data.VERSION:
			issue = "Framework version differs: " + description.framework_version + " / " + Data.VERSION
		if issue.is_empty():
			issue = _check_payload(candidate.root, description)
		if issue.is_empty():
			var checked: Dictionary = PackageHash.compute(candidate.root, description)
			if not checked.ok:
				issue = checked.error
			elif checked.hash != description.package_hash:
				issue = "Package hash differs: " + id
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
		if unavailable.has(id):
			return _error("Update rejected: " + id + ": " + unavailable[id])
	# File, UID and class conflicts invalidate a batch before publication as well.
	return _check_conflicts()

func _check_conflicts() -> Error:
	var files: Dictionary = {}
	var uids: Dictionary = {}
	var planned: Dictionary = {}
	for id: String in installed:
		if unavailable.has(id):
			continue
		var description: Dictionary = installed[id]
		planned[id] = description
		for path: String in description.files:
			if files.has(path):
				return _error("Conflicting package path: " + path)
			files[path] = id
		for uid: String in description.uids:
			var resource_uid: int = ResourceUID.text_to_id(uid)
			if ResourceUID.has_id(resource_uid) and ResourceUID.get_id_path(resource_uid) != description.uids[uid]:
				return _error("UID conflicts with loaded registry: " + uid)
			if uids.has(uid) and uids[uid] != description.uids[uid]:
				return _error("Conflicting package UID: " + uid)
			uids[uid] = description.uids[uid]
	var merged: Dictionary = ScriptClasses.merge(ProjectSettings.get_global_class_list(), planned)
	return OK if merged.ok else _error(merged.error)

## Only prepared artifacts may enter this process. Source/PCK ambiguity is resolved at startup.
func mount_prepared(directory: String) -> Error:
	var planned: Dictionary = {}
	for id: String in installed:
		if not unavailable.has(id):
			planned[id] = installed[id]
	var merged: Dictionary = ScriptClasses.merge(ProjectSettings.get_global_class_list(), planned)
	if not merged.ok:
		return _error(merged.error)
	for id: String in planned:
		var description: Dictionary = planned[id]
		if not ProjectSettings.load_resource_pack(roots[id].path_join("content.pck"), true):
			return _error("Cannot mount package: " + id)
		for uid_text: String in description.uids:
			var uid: int = ResourceUID.text_to_id(uid_text)
			if ResourceUID.has_id(uid) and ResourceUID.get_id_path(uid) != description.uids[uid_text]:
				return _error("UID conflict: " + uid_text)
			if not ResourceUID.has_id(uid):
				ResourceUID.add_id(uid, description.uids[uid_text])
		mounted[id] = description
	if merged.has_content_classes or OS.has_feature("editor"):
		var error: Error = ScriptClasses.register(directory, merged.classes)
		if error != OK:
			return _error("Cannot register content classes: " + error_string(error))
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
