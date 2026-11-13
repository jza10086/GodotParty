## Worker writes package-owned PCKs after one shared import of the dependency closure.
extends SceneTree
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var request: Dictionary = preload("res://core/runtime/party_data.gd").read_json("res://build_request.json")
	if not request.get("outputs") is Dictionary or request.outputs.is_empty() or not ProjectSettings.get_setting("content/shared_import", false):
		push_error("Invalid shared pack worker arguments")
		quit(1)
		return
	var catalog: RefCounted = preload("res://core/content/party_catalog.gd").new()
	if catalog.scan() != OK:
		push_error(str(catalog.errors))
		quit(1)
		return
	var builder: RefCounted = preload("res://core/dev/party_shared_pack_builder.gd").new()
	for id: String in request.outputs:
		var output: String = request.outputs[id]
		if not output.is_absolute_path():
			push_error("Absolute output required: " + id)
			quit(1)
			return
		var error: Error = builder.export_imported_pack(catalog, id, output)
		if error != OK:
			push_error(builder.last_error + ": " + error_string(error))
			quit(1)
			return
	print("SHARED_PACK_PASS")
	quit()
