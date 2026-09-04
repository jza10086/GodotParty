## Collects local connection settings and delegates all network work to NetworkManager.
extends Control

@export var display_name_input: LineEdit
@export var address_input: LineEdit
@export var port_input: SpinBox
@export var host_button: Button
@export var join_button: Button
@export var status_label: Label


func _ready() -> void:
	_assert_required_references()
	if display_name_input.text.is_empty():
		display_name_input.text = "玩家-%04d" % randi_range(0, 9999)
	if address_input.text.is_empty():
		address_input.text = LobbyProtocol.DEFAULT_ADDRESS
	port_input.value = LobbyProtocol.DEFAULT_PORT
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	NetworkManager.connection_state_changed.connect(_on_connection_state_changed)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	if not NetworkManager.last_status_message.is_empty():
		status_label.text = NetworkManager.last_status_message
	_update_busy_state(NetworkManager.connection_state)


func _on_host_pressed() -> void:
	var start_error: Error = NetworkManager.host_session(
		display_name_input.text,
		int(port_input.value)
	)
	if start_error != OK:
		status_label.text = _describe_start_error(start_error)


func _on_join_pressed() -> void:
	var start_error: Error = NetworkManager.join_session(
		display_name_input.text,
		address_input.text,
		int(port_input.value)
	)
	if start_error != OK:
		status_label.text = _describe_start_error(start_error)


func _on_connection_state_changed(state: int) -> void:
	_update_busy_state(state)
	if state == NetworkManager.ConnectionState.CONNECTING:
		status_label.text = NetworkManager.last_status_message
	elif state == NetworkManager.ConnectionState.STARTING_HOST:
		status_label.text = "正在创建大厅……"


func _on_connection_failed(reason: String) -> void:
	status_label.text = reason


func _update_busy_state(state: int) -> void:
	var is_busy: bool = state != NetworkManager.ConnectionState.OFFLINE
	display_name_input.editable = not is_busy
	address_input.editable = not is_busy
	port_input.editable = not is_busy
	host_button.disabled = is_busy
	join_button.disabled = is_busy


func _describe_start_error(start_error: Error) -> String:
	if start_error == ERR_INVALID_PARAMETER or start_error == ERR_INVALID_DATA:
		return "请填写 1–20 个字符的昵称、有效地址和 1024–65535 端口。"
	if start_error == ERR_ALREADY_IN_USE:
		return "当前已有连接正在运行。"
	return "操作失败：%s" % error_string(start_error)


func _assert_required_references() -> void:
	assert(display_name_input != null, "StartMenu requires display_name_input.")
	assert(address_input != null, "StartMenu requires address_input.")
	assert(port_input != null, "StartMenu requires port_input.")
	assert(host_button != null, "StartMenu requires host_button.")
	assert(join_button != null, "StartMenu requires join_button.")
	assert(status_label != null, "StartMenu requires status_label.")
