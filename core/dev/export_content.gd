## Build-time content export. Optional --request selects packages from the visual exporter.
extends SceneTree
const Catalog = preload("res://core/content/party_catalog.gd")
const Packages = preload("res://core/content/party_packages.gd")
const Paths = preload("res://core/config/party_paths.gd")
const Selection = preload("res://core/dev/party_export_selection.gd")

func _initialize() -> void:
	var output: String = ""
	var request_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
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
	var packages: RefCounted = Packages.new()
	for id: String in selection.ids:
		var destination: String = output.path_join(Paths.package_relative(catalog.packages[id]))
		var error: Error = DirAccess.make_dir_recursive_absolute(destination)
		if error == OK:
			error = packages.export_pack(catalog, id, destination.path_join("content.pck"))
		if error != OK:
			_fail(id + ": " + packages.last_error + " " + error_string(error))
			return
		print("EXPORTED ", id)
	print("CONTENT_EXPORT_PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
