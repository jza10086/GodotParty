## Formal loose package files live exclusively under external/.
extends RefCounted
const Data = preload("res://core/runtime/party_data.gd")

static func safe_path(path: String) -> bool:
	if not Data.relative_path(path) or path != path.simplify_path() or path.ends_with("/"):
		return false
	for part: String in path.split("/"):
		if part.begins_with(".") or part.contains("*") or part.contains("?") or part.ends_with(".") or part.ends_with(" "):
			return false
	return path == "external" or path.begins_with("external/")

static func contains(path: String) -> bool:
	return path == "external" or path.begins_with("external/")

## Formal loose payload has one reserved root. Personal files belong in config/.
static func inventory(root: String) -> Dictionary:
	var files: Array[String] = []
	var directories: Array[String] = []
	if DirAccess.dir_exists_absolute(root.path_join("external")):
		var issue: String = _walk(root, "external", files, directories)
		if not issue.is_empty():
			return {"ok": false, "error": issue}
	files.sort()
	directories.sort()
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

## Build copies keep loose data out of the import pipeline. These markers never ship.
static func stage_payload(source: String, destination: String, files: Array, directories: Array) -> Error:
	var error: Error = copy_payload(source, destination, files, directories)
	if error != OK or directories.is_empty():
		return error
	var marker: FileAccess = FileAccess.open(destination.path_join("external/.gdignore"), FileAccess.WRITE)
	if marker == null:
		return FileAccess.get_open_error()
	marker.store_string("")
	marker.close()
	return OK
