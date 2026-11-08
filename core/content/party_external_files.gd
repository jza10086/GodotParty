## Manifest-declared loose payloads. Directory declarations end in "/", paths stay package-relative.
extends RefCounted
const Data = preload("res://core/runtime/party_data.gd")

static func validate(value: Variant) -> String:
	if not value is Array:
		return "external_files must be an array"
	var seen: Array[String] = []
	for entry: Variant in value:
		if not entry is String or not safe_path(entry.trim_suffix("/")):
			return "Invalid external_files path: " + str(entry)
		var path: String = entry.trim_suffix("/").to_lower()
		for other: String in seen:
			if path == other or path.begins_with(other + "/") or other.begins_with(path + "/"):
				return "Overlapping external_files paths: " + entry
		seen.append(path)
	return ""

static func safe_path(path: String) -> bool:
	if not Data.relative_path(path) or path != path.simplify_path() or path.ends_with("/"):
		return false
	for part: String in path.split("/"):
		if part.begins_with(".") or part.contains("*") or part.contains("?") or part.ends_with(".") or part.ends_with(" "):
			return false
	return path.get_slice("/", 0).to_lower() not in ["config", "avatars", "manifest.json", "content.pck", "content.pck.json"]

static func contains(declarations: Array, path: String) -> bool:
	for entry: String in declarations:
		if path == entry.trim_suffix("/") or (entry.ends_with("/") and path.begins_with(entry)):
			return true
	return false

## Collect physical files, including empty folders. Missing payloads and links fail export.
static func inventory(root: String, declarations: Array) -> Dictionary:
	var files: Array[String] = []
	var directories: Array[String] = []
	var issue: String = validate(declarations)
	if not issue.is_empty():
		return {"ok": false, "error": issue}
	for entry: String in declarations:
		var path: String = root.path_join(entry.trim_suffix("/"))
		var current: String = root
		for part: String in entry.trim_suffix("/").split("/"):
			var parent: DirAccess = DirAccess.open(current)
			if parent != null and parent.is_link(part):
				return {"ok": false, "error": "External path contains a link: " + path}
			current = current.path_join(part)
		if entry.ends_with("/"):
			issue = _walk(root, entry.trim_suffix("/"), files, directories)
		elif not FileAccess.file_exists(path):
			issue = "Missing external file: " + path
		elif DirAccess.open(path.get_base_dir()).is_link(path.get_file()):
			issue = "External file is a link: " + path
		else:
			files.append(entry)
		if not issue.is_empty():
			return {"ok": false, "error": issue}
	return {"ok": true, "files": files, "directories": directories}

static func _walk(root: String, relative: String, files: Array[String], directories: Array[String]) -> String:
	var path: String = root.path_join(relative)
	var parent: DirAccess = DirAccess.open(path.get_base_dir())
	if parent != null and parent.is_link(path.get_file()):
		return "External directory is a link: " + path
	var folder: DirAccess = DirAccess.open(path)
	if folder == null:
		return "Cannot open external directory: " + path
	directories.append(relative)
	for file: String in folder.get_files():
		if file.begins_with(".") or file.ends_with(".import") or file.ends_with(".uid") or file.ends_with("~") or file.get_extension().to_lower() in ["tmp", "bak", "pending"]:
			continue
		var child: String = relative.path_join(file)
		if not safe_path(child) or folder.is_link(file):
			return "Invalid external file: " + child
		files.append(child)
	for directory: String in folder.get_directories():
		if directory.begins_with("."):
			continue
		var child: String = relative.path_join(directory)
		if not safe_path(child):
			return "Invalid external directory: " + child
		var issue: String = _walk(root, child, files, directories)
		if not issue.is_empty():
			return issue
	return ""

static func copy_payload(source: String, destination: String, files: Array, directories: Array, preserve_existing: bool = false) -> Error:
	for directory: String in directories:
		var error: Error = DirAccess.make_dir_recursive_absolute(destination.path_join(directory))
		if error != OK:
			return error
	for relative: String in files:
		var target: String = destination.path_join(relative)
		if preserve_existing and FileAccess.file_exists(target):
			continue
		var error: Error = DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		if error == OK:
			error = DirAccess.copy_absolute(source.path_join(relative), target)
		if error != OK:
			return error
	return OK
