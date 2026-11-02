## Build-time package export, using the same catalog as the real application.
extends SceneTree
const Catalog = preload("res://core/content/party_catalog.gd")
const Packages = preload("res://core/content/party_packages.gd")
const Paths = preload("res://core/config/party_paths.gd")

func _initialize() -> void:
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if output.is_empty() or not output.is_absolute_path():
		push_error("An absolute --output= directory is required")
		quit(1)
		return
	var catalog: RefCounted = Catalog.new()
	if catalog.scan() != OK:
		push_error(str(catalog.errors))
		quit(1)
		return
	var packages: RefCounted = Packages.new()
	for id: String in catalog.ids():
		var destination: String = output.path_join(Paths.package_relative(catalog.get_package(id)))
		var error: Error = DirAccess.make_dir_recursive_absolute(destination)
		if error == OK:
			error = packages.export_pack(catalog, id, destination.path_join("content.pck"))
		if error != OK:
			push_error(id + ": " + packages.last_error + " " + error_string(error))
			quit(1)
			return
	print("CONTENT_EXPORT_PASS")
	quit(0)
