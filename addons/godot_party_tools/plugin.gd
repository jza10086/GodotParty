@tool
extends EditorPlugin
## Manifest-based source/PCK tools. The author works in the full framework project.
const Catalog = preload("res://core/content/party_catalog.gd")
const Packages = preload("res://core/content/party_packages.gd")
var _dialog: EditorFileDialog
var _message: AcceptDialog
var _operation: String = ""
var _manifest: String = ""

func _enter_tree() -> void:
	_dialog = EditorFileDialog.new()
	_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	EditorInterface.get_base_control().add_child(_dialog)
	_dialog.file_selected.connect(_selected)
	_message = AcceptDialog.new()
	EditorInterface.get_base_control().add_child(_message)
	add_tool_menu_item("GodotParty：导出源码包", func() -> void: _choose("source"))
	add_tool_menu_item("GodotParty：导出 PCK", func() -> void: _choose("pack"))
	add_tool_menu_item("GodotParty：导入源码包", func() -> void: _choose("import"))

func _exit_tree() -> void:
	for title: String in ["GodotParty：导出源码包", "GodotParty：导出 PCK", "GodotParty：导入源码包"]:
		remove_tool_menu_item(title)
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	if is_instance_valid(_message):
		_message.queue_free()

func _choose(operation: String) -> void:
	_operation = operation
	_manifest = ""
	_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_dialog.filters = PackedStringArray(["*.zip ; Source package"] if operation == "import" else ["manifest.json ; Content manifest"])
	_dialog.popup_centered_ratio(0.7)

func _selected(path: String) -> void:
	var packages: RefCounted = Packages.new()
	if _operation == "import":
		var error: Error = packages.import_source(path)
		_message.dialog_text = error_string(error) + "\n" + packages.last_error
		_message.popup_centered()
		if error == OK:
			EditorInterface.get_resource_filesystem().scan()
		return
	if _manifest.is_empty():
		_manifest = path
		_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		_dialog.filters = PackedStringArray(["*.pck ; Runtime content"] if _operation == "pack" else ["*.zip ; Source package"])
		_dialog.popup_centered_ratio.call_deferred(0.7)
		return
	var catalog: RefCounted = Catalog.new()
	catalog.scan()
	var manifest: Dictionary = Catalog.Data.read_json(_manifest)
	var error: Error = packages.export_pack(catalog, manifest.get("id", ""), path) if _operation == "pack" else packages.export_source(catalog, manifest.get("id", ""), path)
	_message.dialog_text = error_string(error) + "\n" + packages.last_error
	_message.popup_centered()
