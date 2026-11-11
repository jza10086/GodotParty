@tool
extends EditorPlugin
## Platform export menus share the same content picker and release backend.
var _export_window: ConfirmationDialog
var _android_export_window: ConfirmationDialog
var _ios_export_window: ConfirmationDialog

func _enter_tree() -> void:
	_export_window = preload("res://addons/godot_party_tools/export_window.gd").new()
	EditorInterface.get_base_control().add_child(_export_window)
	add_tool_menu_item("GodotParty：导出 Windows 可玩包", _export_window.open)
	_android_export_window = preload("res://addons/godot_party_tools/export_window.gd").new()
	_android_export_window.platform = "Android"
	EditorInterface.get_base_control().add_child(_android_export_window)
	add_tool_menu_item("GodotParty：导出 Android 可玩包", _android_export_window.open)
	_ios_export_window = preload("res://addons/godot_party_tools/export_window.gd").new()
	_ios_export_window.platform = "iOS"
	EditorInterface.get_base_control().add_child(_ios_export_window)
	add_tool_menu_item("GodotParty：导出 iOS 可玩包", _ios_export_window.open)

func _exit_tree() -> void:
	for title: String in ["GodotParty：导出 Windows 可玩包", "GodotParty：导出 Android 可玩包", "GodotParty：导出 iOS 可玩包"]:
		remove_tool_menu_item(title)
	if is_instance_valid(_ios_export_window):
		_ios_export_window.queue_free()
	if is_instance_valid(_android_export_window):
		_android_export_window.queue_free()
	if is_instance_valid(_export_window):
		_export_window.queue_free()
