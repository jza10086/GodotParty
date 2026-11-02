## Shared preset file controls. The owner supplies and consumes drafts, never live settings.
extends VBoxContainer
signal loaded(value: Dictionary)
const Presets = preload("res://core/runtime/party_presets.gd")
var service: RefCounted
var package_id: String
var protocol_id: String
var capture: Callable
var picker: OptionButton
var status: Label
var can_load: bool
var dialogs: Array[Control] = []

func configure(store: RefCounted, id: String, protocol: String, read_draft: Callable, editable: bool = true) -> void:
	service = Presets.new(store)
	package_id = id
	protocol_id = protocol
	capture = read_draft
	can_load = editable
	visible = editable
	if not editable:
		return
	picker = %Picker
	status = %Status
	%LoadDraft.pressed.connect(_load)
	%SaveAs.pressed.connect(_name_dialog.bind(false))
	%Overwrite.pressed.connect(_overwrite)
	%Rename.pressed.connect(_name_dialog.bind(true))
	%Delete.pressed.connect(_delete)
	%Refresh.pressed.connect(refresh)
	%Folder.pressed.connect(_open_directory)
	refresh()

## Modals belong to the viewport, outside this toolbar and any clipping scroll container.
func _attach_dialog(dialog: Control) -> void:
	get_tree().get_first_node_in_group(&"framework_pages").add_child(dialog)
	dialogs.append(dialog)

func _exit_tree() -> void:
	for dialog: Control in dialogs:
		if is_instance_valid(dialog):
			dialog.queue_free()

func selected() -> String:
	return picker.get_item_text(picker.selected) if picker.selected >= 0 else ""

func refresh() -> void:
	var previous: String = selected()
	picker.clear()
	for name_value: String in service.names(package_id, protocol_id):
		picker.add_item(name_value)
		if name_value == previous:
			picker.select(picker.item_count - 1)
	status.text = "文件名就是预设名称；加载后仍需应用。"

func _load() -> void:
	if not can_load or selected().is_empty():
		return
	var value: Dictionary = service.read(package_id, protocol_id, selected())
	if value.is_empty():
		status.text = service.last_error
		return
	loaded.emit(value)
	status.text = "房主规则已加载到草稿，点击应用后才影响房间。"

func _result(error: Error) -> void:
	if error == OK:
		refresh()
	status.text = "已保存文件；没有应用设置。" if error == OK else service.last_error + " " + error_string(error)

func _name_dialog(rename_mode: bool) -> void:
	var old_name: String = selected()
	if rename_mode and old_name.is_empty():
		return
	var dialog: GPPartyDialog = preload("res://core/ui/dialogs/preset_name.tscn").instantiate()
	dialog.title = "重命名预设" if rename_mode else "另存预设"
	dialog.dialog_hide_on_ok = false
	_attach_dialog(dialog)
	var field: LineEdit = dialog.content.get_node("NameField")
	field.text = old_name if rename_mode else ""
	var hint: Label = dialog.content.get_node("Hint")
	dialog.confirmed.connect(func() -> void:
		service.last_error = ""
		var error: Error = service.rename(package_id, protocol_id, old_name, field.text) if rename_mode else service.save(package_id, protocol_id, field.text, capture.call())
		if error != OK:
			hint.text = service.last_error + " " + error_string(error)
			return
		_result(error)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(650, 240))

func _confirm(message: String, action: Callable) -> void:
	var dialog: GPPartyDialog = preload("res://core/ui/party_dialog.tscn").instantiate()
	dialog.dialog_text = message
	_attach_dialog(dialog)
	dialog.confirmed.connect(func() -> void:
		action.call()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(650, 250))

func _overwrite() -> void:
	var name_value: String = selected()
	if name_value.is_empty():
		return
	var value: Dictionary = capture.call()
	_confirm("用当前房主规则草稿覆盖“" + name_value + "”？", func() -> void: _result(service.save(package_id, protocol_id, name_value, value, true)))

func _delete() -> void:
	var name_value: String = selected()
	if not name_value.is_empty():
		_confirm("删除预设“" + name_value + "”？", func() -> void: _result(service.remove(package_id, protocol_id, name_value)))

func _open_directory() -> void:
	var path: String = service.directory(package_id, protocol_id)
	if path.is_empty():
		return
	var error: Error = DirAccess.make_dir_recursive_absolute(path)
	if error == OK:
		error = OS.shell_open(ProjectSettings.globalize_path(path))
	if error != OK:
		status.text = error_string(error)

