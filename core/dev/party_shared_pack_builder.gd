## Build selected PCKs in an isolated source project with both texture import families.
## Export jobs poll subprocess completion; editor playtests never invoke this builder.
extends RefCounted
const Catalog = preload("res://core/content/party_catalog.gd")
const ExportFiles = preload("res://core/content/party_export_files.gd")
const Selection = preload("res://core/content/party_content_selection.gd")
const External = preload("res://core/content/party_external_files.gd")
const Data = preload("res://core/runtime/party_data.gd")
const Packages = preload("res://core/content/party_packages.gd")
const Paths = preload("res://core/config/party_paths.gd")
const ScriptClasses = preload("res://core/content/party_script_classes.gd")
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
	var core_files: Dictionary = ExportFiles.collect("res://core")
	if not core_files.ok:
		return _error(core_files.error)
	var files: Array[String] = core_files.files
	for selected: String in selected_ids:
		var manifest: Dictionary = catalog.packages[selected]
		var collected: Dictionary = ExportFiles.collect(manifest._root)
		if not collected.ok:
			return _error(collected.error)
		for path: String in collected.files:
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
		var description: Dictionary = Data.read_json(String(outputs[id]).get_base_dir().path_join("content.pck.json"))
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
	var collected: Dictionary = ExportFiles.collect(root)
	if not collected.ok:
		return _error(collected.error)
	for path: String in collected.files:
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
	var folder: String = output.get_base_dir()
	var description: Dictionary = {"framework_version": Data.VERSION, "id": id, "version": manifest.package_version, "kind": manifest.kind, "build_id": Data.token(), "packs": [output.get_file()], "resource_index": "resources.json", "settings": "settings.json"}
	description.declaration = manifest._declaration.duplicate(true)
	description.declaration.erase("id")
	description.declaration.erase("owner_protocol")
	description.content = manifest.duplicate(true)
	for key: String in ["id", "owner_protocol", "_root", "_declaration", "build_id", "name", "kind", "package_version", "framework_version", "remark", "supported_languages", "dependencies"]:
		description.content.erase(key)
	description.name = manifest.name
	description.dependencies = manifest.get("dependencies", {}).duplicate(true)
	description.external_files = payload.files
	description.external_directories = payload.directories
	description.payload_files = [output.get_file(), "resources.json", "settings.json"]
	description.payload_files.append_array(payload.files)
	if manifest.kind == "avatars":
		description.owner_protocol = manifest.owner_protocol
	error = External.copy_payload(root, folder, payload.files, payload.directories)
	if error != OK:
		return _error("Cannot copy external payload: " + error_string(error))
	if manifest.has("cover"):
		var preview: Image = Image.load_from_file(ProjectSettings.globalize_path(root.path_join(manifest.cover)))
		if preview == null:
			return _error("Cannot read preview: " + id)
		var ratio: float = minf(1.0, 256.0 / maxi(preview.get_width(), preview.get_height()))
		preview.resize(maxi(1, roundi(preview.get_width() * ratio)), maxi(1, roundi(preview.get_height() * ratio)))
		error = preview.save_png(folder.path_join("preview.png"))
		if error != OK:
			return error
		description.preview = "preview.png"
		description.payload_files.append("preview.png")
	error = _write_json(folder.path_join("resources.json"), {"files": index, "uids": uid_index, "script_classes": ScriptClasses.collect(paths)})
	if error != OK:
		return error
	var schema_issue: String = catalog._prepare_schema(id)
	if not schema_issue.is_empty():
		return _error(schema_issue)
	var localized: Dictionary = {}
	var previous_locale: String = catalog.i18n.locale
	for locale: String in manifest.localization.supported_locales:
		catalog.i18n.set_locale(locale)
		localized[locale] = catalog.localized_schema(id)
	catalog.i18n.set_locale(previous_locale)
	error = _write_json(folder.path_join("settings.json"), {"schema": catalog.schema(id), "localized": localized})
	if error != OK:
		return error
	return _write_json(folder.path_join("content.pck.json"), description)

func _write_json(path: String, value: Dictionary) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	return file.get_error()

func _error(message: String) -> Error:
	last_error = message
	return ERR_INVALID_DATA
