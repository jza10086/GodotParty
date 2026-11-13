## Worker invoked only after the isolated shared resource import has completed.
extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var request: Dictionary = preload("res://core/runtime/party_data.gd").read_json("res://build_request.json")
	var id: String = request.get("id", "")
	var output: String = request.get("output", "")
	if id.is_empty() or not output.is_absolute_path() or not ProjectSettings.get_setting("content/shared_import", false):
		push_error("Invalid shared pack worker arguments")
		quit(1)
		return
	var catalog: RefCounted = preload("res://core/content/party_catalog.gd").new()
	if catalog.scan() != OK:
		push_error(str(catalog.errors))
		quit(1)
		return
	var packages: RefCounted = preload("res://core/content/party_packages.gd").new()
	var error: Error = await packages.export_pack(catalog, id, output)
	if error != OK:
		push_error(packages.last_error + ": " + error_string(error))
		quit(1)
		return
	print("SHARED_PACK_PASS")
	quit()
