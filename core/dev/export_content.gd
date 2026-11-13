## Build-time content export. Optional --request selects packages from the visual exporter.
extends SceneTree
const Catalog = preload("res://core/content/party_catalog.gd")
const Packages = preload("res://core/content/party_packages.gd")
const Paths = preload("res://core/config/party_paths.gd")
const Selection = preload("res://core/content/party_content_selection.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var output: String = ""
	var request_path: String = ""
	var stage_source: String = ""
	var workspace: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--stage-source="):
			stage_source = argument.trim_prefix("--stage-source=")
		elif argument.begins_with("--workspace="):
			workspace = argument.trim_prefix("--workspace=")
		elif argument.begins_with("--request="):
			request_path = argument.trim_prefix("--request=")
	if output.is_empty() or not output.is_absolute_path():
		_fail("An absolute --output= directory is required")
		return
	var catalog: RefCounted = Catalog.new()
	if catalog.scan() != OK:
		_fail(str(catalog.errors))
		return
	var requested: Array = catalog.ids()
	if not request_path.is_empty():
		var json: JSON = JSON.new()
		if json.parse(FileAccess.get_file_as_string(request_path)) != OK or not json.data is Dictionary or not json.data.get("packages") is Array:
			_fail("Invalid export request")
			return
		requested = json.data.packages
	var selection: Dictionary = Selection.resolve(catalog, requested)
	if not selection.ok:
		_fail(selection.error)
		return
	if not stage_source.is_empty():
		for id: String in selection.ids:
			for path: String in Catalog.files(catalog.packages[id]._root):
				var relative: String = path.trim_prefix(catalog.packages[id]._root + "/")
				if Packages.External.contains(relative.trim_suffix(".import").trim_suffix(".uid")):
					continue
				var target: String = stage_source.path_join(path.trim_prefix("res://"))
				var error: Error = DirAccess.make_dir_recursive_absolute(target.get_base_dir())
				if error == OK:
					error = DirAccess.copy_absolute(path, target)
				if error != OK:
					_fail("Cannot stage " + path + ": " + error_string(error))
					return
			var manifest: Dictionary = catalog.packages[id]
			var payload: Dictionary = Packages.External.inventory(manifest._root)
			if not payload.ok:
				_fail(payload.error)
				return
			var error: Error = Packages.External.stage_payload(manifest._root, stage_source.path_join(manifest._root.trim_prefix("res://")), payload.files, payload.directories)
			if error != OK:
				_fail("Cannot stage external payload: " + error_string(error))
				return
		print("CONTENT_SOURCE_STAGE_PASS")
		quit()
		return
	var builder: RefCounted = preload("res://core/dev/party_shared_pack_builder.gd").new()
	if not workspace.is_empty():
		builder.work_directory = workspace
	var outputs: Dictionary = {}
	for id: String in selection.ids:
		var destination: String = output.path_join(Paths.package_relative(catalog.packages[id]))
		var error: Error = DirAccess.make_dir_recursive_absolute(destination)
		if error != OK:
			_fail("Cannot create export directory: " + error_string(error))
			return
		outputs[id] = destination.path_join("content.pck")
	if ProjectSettings.get_setting("content/shared_import", false):
		for id: String in outputs:
			var error: Error = builder.export_imported_pack(catalog, id, outputs[id])
			if error != OK:
				_fail(id + ": " + builder.last_error + " " + error_string(error))
				return
	else:
		var error: Error = await builder.build(catalog, outputs, builder.work_directory)
		if error != OK:
			_fail(builder.last_error + " " + error_string(error))
			return
	print("CONTENT_EXPORT_PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
