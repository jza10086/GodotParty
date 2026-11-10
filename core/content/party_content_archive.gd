## Portable content ZIPs are validated at import and applied before any PCK is mounted.
## APK updates replace packaged artifacts, preserving player configuration and loose edits.
extends RefCounted
const Packages = preload("res://core/content/party_packages.gd")
const Paths = preload("res://core/config/party_paths.gd")
const Data = preload("res://core/runtime/party_data.gd")
var last_error: String = ""

func inspect(path: String, platform: String = OS.get_name()) -> Dictionary:
	var reader: ZIPReader = ZIPReader.new()
	var error: Error = reader.open(path)
	if error != OK:
		return _failure("Cannot open content ZIP: " + error_string(error))
	var entries: PackedStringArray = reader.get_files()
	var header: Variant = JSON.parse_string(reader.read_file("bundle.json").get_string_from_utf8()) if entries.has("bundle.json") else null
	if not header is Dictionary or header.get("format") != 1 or header.get("platform") != platform or not header.get("id") is String or header.id.is_empty() or not header.get("packages") is Array:
		reader.close()
		return _failure("Invalid content bundle or wrong platform")
	var files: Dictionary = {"bundle.json": false}
	var folders: Dictionary = {}
	var descriptions: Dictionary = {}
	var validator: RefCounted = Packages.new()
	for relative: Variant in header.packages:
		if not relative is String or not Data.relative_path(relative) or relative != relative.simplify_path():
			reader.close()
			return _failure("Invalid package directory")
		var descriptor: String = relative.path_join("content.pck.json")
		var description: Variant = JSON.parse_string(reader.read_file(descriptor).get_string_from_utf8()) if entries.has(descriptor) else null
		if not description is Dictionary:
			reader.close()
			return _failure("Missing package descriptor: " + descriptor)
		var issue: String = validator.validate_descriptor(description)
		if not issue.is_empty() or Paths.package_relative(description) != relative or description.get("artifact") != "content.pck" or descriptions.has(description.id):
			reader.close()
			return _failure("Invalid package " + relative + ": " + issue)
		descriptions[description.id] = description
		files[descriptor] = true
		files[relative.path_join("content.pck")] = true
		for loose: String in description.get("external_files", []):
			files[relative.path_join(loose)] = false
		for folder: String in description.get("external_directories", []):
			folders[relative.path_join(folder)] = true
	for file: String in files:
		if not entries.has(file):
			reader.close()
			return _failure("Content ZIP is missing " + file)
	for file: String in entries:
		if not files.has(file) or entries.count(file) != 1:
			reader.close()
			return _failure("Unexpected or duplicate ZIP entry: " + file)
	reader.close()
	return {"ok": true, "id": header.id, "files": files, "directories": folders.keys()}

## Queue updates for next launch; never mutate already-mounted PCKs.
func queue_update(source: String, directory: String) -> Error:
	var checked: Dictionary = inspect(source)
	if not checked.ok:
		return ERR_INVALID_DATA
	var target: String = directory.path_join("tmp/content_update.zip")
	var error: Error = DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	if error == OK:
		error = DirAccess.copy_absolute(source, target + ".pending")
	if error == OK:
		error = DirAccess.rename_absolute(target + ".pending", target)
	if error != OK:
		last_error = "Cannot queue content update: " + error_string(error)
	return error

func bootstrap(directory: String) -> Error:
	var bundled: String = "res://core/bundled_content.zip"
	var marker: String = directory.path_join("tmp/bundled_content_id.txt")
	if FileAccess.file_exists(bundled):
		var checked: Dictionary = inspect(bundled)
		if not checked.ok:
			return ERR_INVALID_DATA
		var installed: String = FileAccess.get_file_as_string(marker) if FileAccess.file_exists(marker) else ""
		if installed != checked.id:
			var error: Error = apply(bundled, directory, checked)
			if error != OK:
				return error
			error = _write(marker, checked.id.to_utf8_buffer())
			if error != OK:
				last_error = "Cannot record bundled content version: " + error_string(error)
				return error
	var pending: String = directory.path_join("tmp/content_update.zip")
	if FileAccess.file_exists(pending):
		var checked: Dictionary = inspect(pending)
		if not checked.ok:
			return ERR_INVALID_DATA
		var error: Error = apply(pending, directory, checked)
		if error != OK:
			return error
		error = DirAccess.remove_absolute(pending)
		if error != OK:
			last_error = "Cannot clear applied content update: " + error_string(error)
			return error
	return OK

## Stage and back up all replacements before writing; restore them if publication fails.
func apply(source: String, directory: String, checked: Dictionary) -> Error:
	var reader: ZIPReader = ZIPReader.new()
	var error: Error = reader.open(source)
	if error != OK:
		last_error = "Cannot open content ZIP: " + error_string(error)
		return error
	var stage: String = directory.path_join("tmp/content_install/" + Data.token())
	var writes: Array[Dictionary] = []
	for folder: String in checked.directories:
		error = DirAccess.make_dir_recursive_absolute(directory.path_join(folder))
		if error != OK:
			break
	if error == OK:
		for relative: String in checked.files:
			if relative == "bundle.json":
				continue
			var target: String = directory.path_join(relative)
			var existed: bool = FileAccess.file_exists(target)
			if existed and not checked.files[relative]:
				continue
			var staged: String = stage.path_join("next").path_join(relative)
			var backup: String = stage.path_join("previous").path_join(relative)
			error = _write(staged, reader.read_file(relative))
			if error == OK and existed:
				error = DirAccess.make_dir_recursive_absolute(backup.get_base_dir())
				if error == OK:
					error = DirAccess.copy_absolute(target, backup)
			if error == OK:
				error = DirAccess.make_dir_recursive_absolute(target.get_base_dir())
			if error != OK:
				break
			writes.append({"target": target, "staged": staged, "backup": backup, "existed": existed})
	reader.close()
	if error != OK:
		last_error = "Cannot stage content: " + error_string(error)
		return error
	var applied: Array[Dictionary] = []
	for write: Dictionary in writes:
		applied.append(write)
		error = DirAccess.rename_absolute(write.staged, write.target)
		if error != OK:
			break
	if error != OK:
		for index: int in range(applied.size() - 1, -1, -1):
			var write: Dictionary = applied[index]
			var rollback: Error = DirAccess.copy_absolute(write.backup, write.target) if write.existed else (DirAccess.remove_absolute(write.target) if FileAccess.file_exists(write.target) else OK)
			if rollback != OK:
				push_error("Content rollback failed: " + write.target + " " + error_string(rollback))
		last_error = "Cannot install content: " + error_string(error) + "; backups: " + stage
		return error
	error = _remove_stage(stage)
	if error != OK:
		last_error = "Content installed but cannot clear staging directory: " + stage
	return error

## Only called for the fresh transaction directory created by apply(), never an archive path.
func _remove_stage(path: String) -> Error:
	if not DirAccess.dir_exists_absolute(path):
		return OK
	for file: String in DirAccess.get_files_at(path):
		var error: Error = DirAccess.remove_absolute(path.path_join(file))
		if error != OK:
			return error
	for folder: String in DirAccess.get_directories_at(path):
		var error: Error = _remove_stage(path.path_join(folder))
		if error != OK:
			return error
	return DirAccess.remove_absolute(path)

func _write(path: String, bytes: PackedByteArray) -> Error:
	var error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		return error
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	return file.get_error()

func _failure(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}
