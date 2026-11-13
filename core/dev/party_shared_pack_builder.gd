## Build selected PCKs in an isolated source project with both texture import families.
## The running host polls subprocess completion so networking remains responsive.
extends RefCounted
const Catalog = preload("res://core/content/party_catalog.gd")
const Selection = preload("res://core/content/party_content_selection.gd")
const External = preload("res://core/content/party_external_files.gd")
const Data = preload("res://core/runtime/party_data.gd")
const Packages = preload("res://core/content/party_packages.gd")
const Paths = preload("res://core/config/party_paths.gd")
const ScriptClasses = preload("res://core/content/party_script_classes.gd")
const PackageHash = preload("res://core/content/party_package_hash.gd")
var last_error: String = ""
var work_directory: String = Paths.application_root().path_join("tmp/content_build")

func build(catalog: RefCounted, outputs: Dictionary, workspace: String) -> Error:
	var selection: Dictionary = Selection.resolve(catalog, outputs.keys())
	if not selection.ok:
		last_error = selection.error
		return ERR_INVALID_DATA
	var stage: String = workspace.path_join(Data.token())
	var error: Error = await _build_in_stage(catalog, selection.ids, outputs, stage)
	var cleanup: RefCounted = preload("res://core/content/party_content_archive.gd").new()
	if error == OK:
		# Preserve successful subprocess diagnostics next to the job, before removing import copies.
		for name: String in ["import.log", "pack.log"]:
			var saved: Error = DirAccess.copy_absolute(stage.path_join(name), workspace.path_join(stage.get_file() + "." + name))
			if saved != OK:
				last_error = "Cannot retain build log: " + name
				return saved
		error = cleanup._remove_stage(stage)
		if error != OK:
			last_error = "Cannot clear completed build: " + stage
	else:
		# Retain project/request/logs; only regenerate the large source and import copies.
		for folder: String in ["core", "games", ".godot"]:
			var cleanup_error: Error = cleanup._remove_stage(stage.path_join(folder))
			if cleanup_error != OK:
				last_error += "; cannot clear " + folder + ": " + error_string(cleanup_error)
	return error

func _build_in_stage(catalog: RefCounted, selected_ids: Array, outputs: Dictionary, stage: String) -> Error:
	var files: Array[String] = Catalog.files("res://core")
	for selected: String in selected_ids:
		var manifest: Dictionary = catalog.packages[selected]
		for path: String in Catalog.files(manifest._root):
			var relative: String = path.trim_prefix(manifest._root + "/")
			if not External.contains(relative.trim_suffix(".import").trim_suffix(".uid")):
				files.append(path)
	for source: String in files:
		if source.begins_with("res://core/saves/") or source == "res://core/bundled_content.zip" or (source.begins_with("res://core/config/") and source.get_extension() == "json"):
			continue
		var destination: String = stage.path_join(source.trim_prefix("res://"))
		var error: Error = DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		if error == OK:
			error = DirAccess.copy_absolute(source, destination)
		if error != OK:
			last_error = "Cannot stage " + source + ": " + error_string(error)
			return error
	for selected: String in selected_ids:
		var manifest: Dictionary = catalog.packages[selected]
		var inventory: Dictionary = External.inventory(manifest._root)
		if not inventory.ok:
			last_error = inventory.error
			return ERR_INVALID_DATA
		var error: Error = External.stage_payload(manifest._root, stage.path_join(manifest._root.trim_prefix("res://")), inventory.files, inventory.directories)
		if error != OK:
			last_error = "Cannot stage external files: " + error_string(error)
			return error
	var project: FileAccess = FileAccess.open(stage.path_join("project.godot"), FileAccess.WRITE)
	if project == null:
		last_error = "Cannot write shared content project"
		return FileAccess.get_open_error()
	# Serial import avoids the concurrent font-import path that crashed in full-batch validation.
	project.store_string("config_version=5\n[application]\nconfig/name=\"SharedContentBuild\"\n[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\nrenderer/rendering_method.mobile=\"gl_compatibility\"\ntextures/vram_compression/import_s3tc_bptc=true\ntextures/vram_compression/import_etc2_astc=true\n[editor]\nimport/use_multiple_threads=false\nexport/convert_text_resources_to_binary=false\n[content]\nshared_import=true\n")
	project.flush()
	var error: Error = project.get_error()
	project.close()
	if error != OK:
		last_error = "Cannot save shared content project"
		return error
	error = await _run(stage, ["--import"], stage.path_join("import.log"), "")
	if error != OK:
		return error
	var request: FileAccess = FileAccess.open(stage.path_join("build_request.json"), FileAccess.WRITE)
	if request == null:
		last_error = "Cannot write shared content request"
		return FileAccess.get_open_error()
	request.store_string(JSON.stringify({"outputs": outputs}))
	request.flush()
	error = request.get_error()
	request.close()
	if error != OK:
		last_error = "Cannot save shared content request"
		return error
	error = await _run(stage, ["--script", "res://core/dev/export_shared_pack.gd"], stage.path_join("pack.log"), "SHARED_PACK_PASS")
	if error != OK:
		return error
	var validator: RefCounted = Packages.new()
	for id: String in outputs:
		var description: Dictionary = Data.read_json(outputs[id] + ".json")
		var issue: String = validator.validate_descriptor(description)
		if issue.is_empty():
			issue = validator._check_payload(str(outputs[id]).get_base_dir(), description)
		if not issue.is_empty() or description.get("id") != id or not FileAccess.file_exists(outputs[id]):
			return _error("Invalid built package " + id + ": " + issue)
	return OK

func _run(stage: String, arguments: PackedStringArray, log_path: String, marker: String) -> Error:
	var args: PackedStringArray = ["--headless", "--path", stage, "--log-file", log_path]
	args.append_array(arguments)
	# Use the current editor executable, never a separately pinned engine build.
	var pid: int = OS.create_process(OS.get_executable_path(), args, false)
	if pid < 0:
		last_error = "Cannot launch shared content builder"
		return ERR_CANT_FORK
	var deadline: int = Time.get_ticks_msec() + 600000
	while OS.is_process_running(pid):
		if Time.get_ticks_msec() > deadline:
			var kill_error: Error = OS.kill(pid)
			last_error = "Shared content build timed out: " + log_path + ("; stop failed: " + error_string(kill_error) if kill_error != OK else "")
			return ERR_TIMEOUT
		await Engine.get_main_loop().process_frame
	var code: int = OS.get_process_exit_code(pid)
	var log: String = FileAccess.get_file_as_string(log_path) if FileAccess.file_exists(log_path) else ""
	if code != 0 or log.contains("SCRIPT ERROR") or log.contains("ERROR:") or (not marker.is_empty() and not log.contains(marker)):
		last_error = "Shared content build failed (%d): %s" % [code, log_path]
		return ERR_CANT_CREATE
	return OK


## Imported assets ship only their runtime outputs and remaps; source ZIPs retain originals.
func export_imported_pack(catalog: RefCounted, id: String, output: String) -> Error:
	last_error = ""
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
	var paths: Dictionary = {}
	var uid_index: Dictionary = {}
	var imported_sources: Array[String] = []
	for path: String in Catalog.files(root):
		var relative: String = path.trim_prefix(root + "/")
		if External.contains(relative.trim_suffix(".import").trim_suffix(".uid")):
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
	var description: Dictionary = {"framework_version": Data.VERSION, "id": id, "version": manifest["package_version"], "kind": manifest["kind"], "artifact": output.get_file(), "files": index, "uids": uid_index}
	description.declaration = manifest._declaration.duplicate(true)
	description.declaration.erase("id")
	description.declaration.erase("owner_protocol")
	description.content = manifest.duplicate(true)
	for key: String in ["id", "owner_protocol", "_root", "_declaration", "package_hash", "name", "kind", "package_version", "framework_version", "remark", "supported_languages", "dependencies"]:
		description.content.erase(key)
	description.name = manifest.name
	description.dependencies = manifest.get("dependencies", {}).duplicate(true)
	description.script_classes = ScriptClasses.collect(paths)
	description.external_files = payload.files
	description.external_directories = payload.directories
	if manifest.kind == "avatars":
		description.owner_protocol = manifest.owner_protocol
	error = External.copy_payload(root, output.get_base_dir(), payload.files, payload.directories)
	if error != OK:
		return _error("Cannot copy external payload: " + error_string(error))

	var identity: Dictionary = PackageHash.compute(output.get_base_dir(), description)
	if not identity.ok:
		return _error(identity.error)
	description.package_hash = identity.hash
	var file: FileAccess = FileAccess.open(output + ".json", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(description, "\t"))
	file.flush()
	error = file.get_error()
	file.close()
	return error

## Select one source-derived generation before loading any gameplay resource in the app.
## Fingerprints are product cache keys, never release versions or network identities.
func prepare_distribution(cache_directory: String) -> String:
	var files: Array[String] = Catalog.files("res://core")
	var roots: Array[String] = []
	for kind: String in ["protocols", "maingame", "minigame", "assets"]:
		var base: String = "res://games/" + kind
		for id: String in DirAccess.get_directories_at(base):
			var root: String = base.path_join(id)
			if "manifest.json" not in DirAccess.get_files_at(root):
				continue
			roots.append(root)
			if kind == "protocols":
				for avatar: String in DirAccess.get_directories_at(root.path_join("avatars")):
					roots.append(root.path_join("avatars").path_join(avatar))
	for root: String in roots:
		files.append_array(Catalog.files(root))
		var payload: Dictionary = External.inventory(root)
		if not payload.ok:
			_error(payload.error)
			return ""
		for relative: String in payload.files:
			files.append(root.path_join(relative))
	var fingerprint: Dictionary = source_fingerprint(files)
	if not fingerprint.ok:
		_error(fingerprint.error)
		return ""
	var generation: String = fingerprint.key
	var error: Error = OK
	var cache: String = cache_directory.path_join(generation)
	var pointer: String = cache.path_join("current.json")
	if FileAccess.file_exists(pointer):
		var record: Dictionary = Data.read_json(pointer)
		if not Paths.folder(record.get("generation")):
			_error("Invalid distribution cache index: " + pointer)
			return ""
		var existing: String = cache.path_join(record.generation)
		for root: String in roots:
			var installed: String = existing.path_join(root.trim_prefix("res://games/"))
			if not FileAccess.file_exists(installed.path_join("content.pck")) or not FileAccess.file_exists(installed.path_join("content.pck.json")):
				_error("Incomplete distribution generation: " + installed)
				return ""
		return existing
	# Each startup owns its output directory, including concurrent editor instances.
	var token: String = Data.token()
	var destination: String = cache.path_join(token)
	error = DirAccess.make_dir_recursive_absolute(destination)
	if error != OK:
		_error("Cannot create distribution cache: " + error_string(error))
		return ""
	var project: String = ProjectSettings.globalize_path("res://")
	error = await _run(project, ["--script", "res://core/dev/export_content.gd", "--", "--output=" + destination, "--workspace=" + cache_directory.get_base_dir().path_join("content_build")], destination.path_join("build.log"), "CONTENT_EXPORT_PASS")
	if error != OK:
		return ""
	var pending: String = pointer + "." + token + ".pending"
	var marker: FileAccess = FileAccess.open(pending, FileAccess.WRITE)
	if marker == null:
		_error("Cannot publish distribution generation")
		return ""
	marker.store_string(JSON.stringify({"generation": token}))
	marker.flush()
	error = marker.get_error()
	marker.close()
	if error != OK:
		_error("Cannot save distribution generation")
		return ""
	error = DirAccess.rename_absolute(pending, pointer)
	if error != OK:
		_error("Cannot publish distribution index: " + error_string(error))
		return ""
	return destination

## Build cache inputs include file bytes and import/build parameters, independently of package_version.
static func source_fingerprint(files: Array[String]) -> Dictionary:
	files.sort()
	var context: HashingContext = HashingContext.new()
	var error: Error = context.start(HashingContext.HASH_SHA256)
	if error == OK:
		error = PackageHash._blob(context, str(Engine.get_version_info().string).to_utf8_buffer())
	for path: String in files:
		if path.begins_with("res://core/saves/") or path == "res://core/bundled_content.zip" or (path.begins_with("res://core/config/") and path.get_extension() == "json"):
			continue
		if error != OK:
			break
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {"ok": false, "error": "Cannot read build input: " + path}
		error = PackageHash._blob(context, path.to_utf8_buffer())
		if error == OK:
			error = PackageHash._length(context, file.get_length())
		while error == OK and file.get_position() < file.get_length():
			var bytes: PackedByteArray = file.get_buffer(mini(1048576, file.get_length() - file.get_position()))
			if bytes.is_empty():
				error = ERR_FILE_CANT_READ
			else:
				error = context.update(bytes)
		file.close()
	if error != OK:
		return {"ok": false, "error": "Cannot fingerprint build inputs: " + error_string(error)}
	return {"ok": true, "key": context.finish().hex_encode()}

func _error(message: String) -> Error:
	last_error = message
	return ERR_INVALID_DATA
