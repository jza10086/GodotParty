## Build one shared PCK in an isolated source project with both texture import families.
## The running host polls subprocess completion so networking remains responsive.
extends RefCounted
const Catalog = preload("res://core/content/party_catalog.gd")
const Selection = preload("res://core/dev/party_export_selection.gd")
const External = preload("res://core/content/party_external_files.gd")
const Data = preload("res://core/runtime/party_data.gd")
var last_error: String = ""

func build(catalog: RefCounted, id: String, output: String, work_directory: String) -> Error:
	var selection: Dictionary = Selection.resolve(catalog, [id])
	if not selection.ok:
		last_error = selection.error
		return ERR_INVALID_DATA
	var target: String = ProjectSettings.globalize_path(output)
	var stage: String = work_directory.path_join(Data.token())
	var files: Array[String] = Catalog.files("res://core")
	for selected: String in selection.ids:
		var manifest: Dictionary = catalog.packages[selected]
		for path: String in Catalog.files(manifest._root):
			var relative: String = path.trim_prefix(manifest._root + "/")
			if not External.contains(manifest.get("external_files", []), relative.trim_suffix(".import").trim_suffix(".uid")):
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
	for selected: String in selection.ids:
		var manifest: Dictionary = catalog.packages[selected]
		var inventory: Dictionary = External.inventory(manifest._root, manifest.get("external_files", []))
		if not inventory.ok:
			last_error = inventory.error
			return ERR_INVALID_DATA
		var error: Error = External.stage_payload(manifest._root, stage.path_join(manifest._root.trim_prefix("res://")), manifest.get("external_files", []), inventory.files, inventory.directories)
		if error != OK:
			last_error = "Cannot stage external files: " + error_string(error)
			return error
	var project: FileAccess = FileAccess.open(stage.path_join("project.godot"), FileAccess.WRITE)
	if project == null:
		last_error = "Cannot write shared content project"
		return FileAccess.get_open_error()
	project.store_string("config_version=5\n[application]\nconfig/name=\"SharedContentBuild\"\n[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\nrenderer/rendering_method.mobile=\"gl_compatibility\"\ntextures/vram_compression/import_s3tc_bptc=true\ntextures/vram_compression/import_etc2_astc=true\n[editor]\nexport/convert_text_resources_to_binary=false\n[content]\nshared_import=true\n")
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
	request.store_string(JSON.stringify({"id": id, "output": target}))
	request.flush()
	error = request.get_error()
	request.close()
	if error != OK:
		last_error = "Cannot save shared content request"
		return error
	return await _run(stage, ["--script", "res://core/dev/export_shared_pack.gd"], stage.path_join("pack.log"), "SHARED_PACK_PASS")

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
