## Lets the host select one exact local interface address without crowding the start page.
class_name AdvancedNetworkSettings
extends Control

signal specific_address_changed(address: String)
signal refresh_requested()
signal closed()

@export var address_list: VBoxContainer
@export var refresh_button: Button
@export var clear_selection_button: Button
@export var close_button: Button
@export var status_label: Label

var _port: int = LobbyProtocol.DEFAULT_PORT
var _selected_address: String = ""
var _checkboxes_by_address: Dictionary[String, CheckBox] = {}
var _updating_selection: bool = false


func _ready() -> void:
	_assert_required_references()
	refresh_button.pressed.connect(refresh_requested.emit)
	clear_selection_button.pressed.connect(_clear_selection)
	close_button.pressed.connect(closed.emit)


func configure(
		addresses: Array[LocalNetworkAddress],
		selected_address: String,
		port: int
) -> void:
	_port = port
	_selected_address = selected_address
	_updating_selection = true
	for child: Node in address_list.get_children():
		address_list.remove_child(child)
		child.queue_free()
	_checkboxes_by_address.clear()
	for local_address: LocalNetworkAddress in addresses:
		address_list.add_child(_create_address_row(local_address))
	_updating_selection = false
	_refresh_status(addresses.size())


func _create_address_row(
		local_address: LocalNetworkAddress
) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 52.0)
	row.add_theme_constant_override("separation", 14)

	var checkbox: CheckBox = CheckBox.new()
	checkbox.button_pressed = (
		local_address.address.to_lower() == _selected_address.to_lower()
	)
	checkbox.toggled.connect(
		_on_address_toggled.bind(local_address.address)
	)
	_checkboxes_by_address[local_address.address] = checkbox

	var label: Label = Label.new()
	label.text = local_address.get_display_text()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	var endpoint_label: Label = Label.new()
	endpoint_label.text = local_address.format_endpoint(_port)
	endpoint_label.custom_minimum_size = Vector2(270.0, 0.0)

	var copy_button: Button = Button.new()
	copy_button.text = "复制"
	copy_button.pressed.connect(
		_copy_endpoint.bind(local_address)
	)

	row.add_child(checkbox)
	row.add_child(label)
	row.add_child(endpoint_label)
	row.add_child(copy_button)
	return row


func _on_address_toggled(enabled: bool, address: String) -> void:
	if _updating_selection:
		return
	_updating_selection = true
	if enabled:
		for candidate_address: String in _checkboxes_by_address:
			if candidate_address != address:
				_checkboxes_by_address[candidate_address].set_pressed_no_signal(false)
		_selected_address = address
	elif _selected_address.to_lower() == address.to_lower():
		_selected_address = ""
	_updating_selection = false
	specific_address_changed.emit(_selected_address)
	_refresh_status(_checkboxes_by_address.size())


func _clear_selection() -> void:
	_updating_selection = true
	for checkbox: CheckBox in _checkboxes_by_address.values():
		checkbox.set_pressed_no_signal(false)
	_selected_address = ""
	_updating_selection = false
	specific_address_changed.emit("")
	_refresh_status(_checkboxes_by_address.size())


func _copy_endpoint(local_address: LocalNetworkAddress) -> void:
	var endpoint: String = local_address.format_endpoint(_port)
	DisplayServer.clipboard_set(endpoint)
	status_label.text = "已复制：%s" % endpoint


func _refresh_status(address_count: int) -> void:
	if address_count == 0:
		status_label.text = "没有发现当前版本支持的可分享地址。"
	elif _selected_address.is_empty():
		status_label.text = "未指定适配器，将使用主界面的 IP 模式。"
	else:
		status_label.text = "已指定监听地址：%s" % _selected_address


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _assert_required_references() -> void:
	assert(address_list != null, "Advanced settings requires address_list.")
	assert(refresh_button != null, "Advanced settings requires refresh_button.")
	assert(
		clear_selection_button != null,
		"Advanced settings requires clear_selection_button."
	)
	assert(close_button != null, "Advanced settings requires close_button.")
	assert(status_label != null, "Advanced settings requires status_label.")
