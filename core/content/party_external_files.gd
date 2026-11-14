## Formal loose package files live exclusively under external/.
extends RefCounted
const Data = preload("res://core/runtime/party_data.gd")
const ExportFiles = preload("res://core/content/party_export_files.gd")

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
	var collected: Dictionary = ExportFiles.collect(root, "external")
	if not collected.ok:
		return collected
	var files: Array[String] = []
	for path: String in collected.files:
		var relative: String = path.trim_prefix(root + "/")
		# These are Godot import companions, never raw runtime payload.
		if relative.ends_with(".import") or relative.ends_with(".uid") or relative.get_file() == ".gdignore":
			continue
		if not safe_path(relative):
			return {"ok": false, "error": "Invalid external file: " + relative}
		files.append(relative)
	for directory: String in collected.directories:
		if not safe_path(directory):
			return {"ok": false, "error": "Invalid external directory: " + directory}
	return {"ok": true, "files": files, "directories": collected.directories}

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
