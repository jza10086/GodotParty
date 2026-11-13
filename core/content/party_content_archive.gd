## Portable content ZIPs are validated at import and applied before any PCK is mounted.
## Formal external payload is replaced transactionally; personal config stays outside the payload.
extends RefCounted
const Packages = preload("res://core/content/party_packages.gd")
const Paths = preload("res://core/config/party_paths.gd")
const Data = preload("res://core/runtime/party_data.gd")
var last_error: String = ""

func inspect(path: String) -> Dictionary:
	var reader: ZIPReader = ZIPReader.new()
	var error: Error = reader.open(path)
	if error != OK:
		return _failure("Cannot open content ZIP: " + error_string(error))
	var entries: PackedStringArray = reader.get_files()
	var header: Variant = JSON.parse_string(reader.read_file("bundle.json").get_string_from_utf8()) if entries.has("bundle.json") else null
	if not header is Dictionary or header.get("format") != 2 or header.has("platform") or not header.get("id") is String or header.id.is_empty() or not header.get("packages") is Array:
		reader.close()
		return _failure("Invalid shared content bundle; regenerate with the current framework")
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
	var parent_folders: Dictionary = {}
	for folder: String in folders:
		parent_folders[folder + "/"] = true
	for file: String in files.keys() + folders.keys():
		var parent: String = file.get_base_dir()
		while not parent.is_empty():
			parent_folders[parent + "/"] = true
			parent = parent.get_base_dir()
	for file: String in entries:
		if (not files.has(file) and not parent_folders.has(file)) or entries.count(file) != 1:
			reader.close()
			return _failure("Unexpected or duplicate ZIP entry: " + file)
	reader.close()
	return {"ok": true, "id": header.id, "files": files, "directories": folders.keys(), "descriptions": descriptions}

## Queue updates for next launch; never mutate already-mounted PCKs.
func queue_update(source: String, directory: String, active: Callable = Callable(), progress: Callable = Callable()) -> Error:
	var checked: Dictionary = inspect(source)
	if not checked.ok:
		return ERR_INVALID_DATA
	var target: String = directory.path_join("tmp/content_update.zip")
	var pending: String = target + "." + Data.token() + ".pending"
	var error: Error = DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	if error != OK:
		last_error = "Cannot create update directory: " + error_string(error)
		return error
	var input: FileAccess = FileAccess.open(source, FileAccess.READ)
	if input == null:
		return FileAccess.get_open_error()
	var output: FileAccess = FileAccess.open(pending, FileAccess.WRITE)
	if output == null:
		return FileAccess.get_open_error()
	while input.get_position() < input.get_length():
		if active.is_valid() and not active.call():
			error = ERR_SKIP
			break
		var bytes: PackedByteArray = input.get_buffer(mini(1048576, input.get_length() - input.get_position()))
		if bytes.is_empty():
			error = ERR_FILE_CANT_READ
			break
		output.store_buffer(bytes)
		error = output.get_error()
		if error != OK:
			break
		if progress.is_valid():
			progress.call(input.get_position(), input.get_length())
		await Engine.get_main_loop().process_frame
	input.close()
	output.flush()
	if error == OK:
		error = output.get_error()
	output.close()
	if error == OK and active.is_valid() and not active.call():
		error = ERR_SKIP
	if error == OK:
		error = DirAccess.rename_absolute(pending, target)
	if error != OK:
		last_error = "Cannot queue content update: " + error_string(error)
		var cleanup: Error = DirAccess.remove_absolute(pending)
		if cleanup != OK:
			last_error += "; cannot clear temporary copy: " + error_string(cleanup)
	return error

## Merge bundled and downloaded updates into one candidate set; verify before publication.
func bootstrap(directory: String, packages: RefCounted, source_roots: Dictionary = {}) -> Error:
	var archives: Array[Dictionary] = []
	var bundled: String = "res://core/bundled_content.zip"
	var marker: String = directory.path_join("tmp/bundled_content_id.txt")
	var bundle_id: String = ""
	if FileAccess.file_exists(bundled):
		var checked: Dictionary = inspect(bundled)
		if not checked.ok:
			return ERR_INVALID_DATA
		var previous: String = FileAccess.get_file_as_string(marker) if FileAccess.file_exists(marker) else ""
		if previous != checked.id:
			bundle_id = checked.id
			archives.append({"path": bundled, "checked": checked})
	var pending: String = directory.path_join("tmp/content_update.zip")
	if FileAccess.file_exists(pending):
		var checked: Dictionary = inspect(pending)
		if not checked.ok:
			return ERR_INVALID_DATA
		archives.append({"path": pending, "checked": checked})
	if archives.is_empty():
		var error: Error = packages.prepare(directory, source_roots)
		last_error = packages.last_error
		return error
	var error: Error = _apply_batch(archives, directory, packages, source_roots)
	if error != OK:
		return error
	if not bundle_id.is_empty():
		error = _write(marker, bundle_id.to_utf8_buffer())
		if error != OK:
			last_error = "Cannot record bundled content version: " + error_string(error)
			return error
	if FileAccess.file_exists(pending):
		error = DirAccess.remove_absolute(pending)
		if error != OK:
			last_error = "Cannot clear applied content update: " + error_string(error)
	return error

## Public offline install follows the same candidate validation and rollback path.
func apply(source: String, directory: String, checked: Dictionary) -> Error:
	return _apply_batch([{"path": source, "checked": checked}], directory, Packages.new(), {})

func _apply_batch(archives: Array, directory: String, packages: RefCounted, source_roots: Dictionary) -> Error:
	var stage: String = directory.path_join("tmp/content_install/" + Data.token())
	var replacements: Dictionary = source_roots.duplicate()
	var updated: Dictionary = {}
	var error: Error = OK
	for archive: Dictionary in archives:
		var reader: ZIPReader = ZIPReader.new()
		error = reader.open(archive.path)
		if error != OK:
			last_error = "Cannot open update archive: " + error_string(error)
			return error
		for id: String in archive.checked.descriptions:
			var description: Dictionary = archive.checked.descriptions[id]
			var relative: String = Paths.package_relative(description)
			var root: String = stage.path_join("next").path_join(relative)
			replacements[id] = root
			updated[id] = description
			var names: Array = ["content.pck", "content.pck.json"]
			names.append_array(description.external_files)
			for name: String in names:
				error = _write(root.path_join(name), reader.read_file(relative.path_join(name)))
				if error != OK:
					break
			if error != OK:
				break
			for folder: String in description.external_directories:
				error = DirAccess.make_dir_recursive_absolute(root.path_join(folder))
				if error != OK:
					break
		reader.close()
		if error != OK:
			last_error = "Cannot stage content: " + error_string(error)
			return error
	error = packages.prepare(directory, replacements, updated.keys())
	if error != OK:
		last_error = packages.last_error
		var cleanup: Error = _remove_stage(stage)
		if cleanup != OK:
			last_error += "; staging retained: " + stage
		return error
	var writes: Array[Dictionary] = []
	for id: String in updated:
		var description: Dictionary = updated[id]
		var relative: String = Paths.package_relative(description)
		var target_root: String = directory.path_join(relative)
		var old_path: String = target_root.path_join("content.pck.json")
		var old: Dictionary = Data.read_json(old_path) if FileAccess.file_exists(old_path) else {}
		var names: Array = ["content.pck", "content.pck.json"]
		names.append_array(description.external_files)
		# Retired formal files are deletions in the same transaction, never orphaned payload.
		for name: String in old.get("external_files", []):
			if Packages.External.safe_path(name) and name not in names:
				names.append(name)
		for name: String in names:
			var target: String = target_root.path_join(name)
			var backup: String = stage.path_join("previous").path_join(relative).path_join(name)
			var existed: bool = FileAccess.file_exists(target)
			var staged: String = replacements[id].path_join(name)
			if existed:
				error = DirAccess.make_dir_recursive_absolute(backup.get_base_dir())
				if error == OK:
					error = DirAccess.copy_absolute(target, backup)
			if error == OK:
				error = DirAccess.make_dir_recursive_absolute(target.get_base_dir())
			if error != OK:
				last_error = "Cannot back up content: " + error_string(error)
				return error
			writes.append({"target": target, "staged": staged, "backup": backup, "existed": existed, "delete": name not in description.external_files and name not in ["content.pck", "content.pck.json"]})
		for folder: String in description.external_directories:
			error = DirAccess.make_dir_recursive_absolute(target_root.path_join(folder))
			if error != OK:
				last_error = "Cannot create external directory: " + error_string(error)
				return error
	var applied: Array[Dictionary] = []
	for write: Dictionary in writes:
		applied.append(write)
		if write.delete:
			error = DirAccess.remove_absolute(write.target) if write.existed else OK
		else:
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
	for id: String in updated:
		packages.roots[id] = directory.path_join(Paths.package_relative(updated[id]))
	error = _remove_stage(stage)
	if error != OK:
		last_error = "Content installed but staging cleanup failed: " + stage
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
