## Collects local connection settings and delegates all network work to NetworkManager.
extends Control

const SPECIFIC_ADAPTER_MODE: String = "specific_adapter"

@export var display_name_input: LineEdit
@export var address_input: LineEdit
@export var port_input: SpinBox
@export var ip_mode_option: OptionButton
@export var advanced_settings_button: Button
@export var advanced_settings_scene: PackedScene
@export var public_ipv4_label: Label
@export var public_ipv6_label: Label
@export var copy_public_ipv4_button: Button
@export var copy_public_ipv6_button: Button
@export var refresh_public_addresses_button: Button
@export var host_button: Button
@export var join_button: Button
@export var cancel_button: Button
@export var status_label: Label

var _preferences: ConnectionPreferences = null
var _local_addresses: Array[LocalNetworkAddress] = []
var _specific_bind_address: String = ""
var _selected_ip_mode: String = ConnectionPreferences.IP_MODE_DUAL
var _updating_ip_mode_option: bool = false
var _advanced_settings: AdvancedNetworkSettings = null


func _ready() -> void:
	_assert_required_references()
	_preferences = ConnectionPreferences.load_from_file()
	display_name_input.text = _preferences.display_name
	address_input.text = _preferences.join_address
	port_input.value = _preferences.port
	_specific_bind_address = _preferences.specific_bind_address
	_setup_ip_modes(_preferences.ip_mode)
	_refresh_local_addresses()

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	cancel_button.pressed.connect(NetworkManager.cancel_connection)
	advanced_settings_button.pressed.connect(_open_advanced_settings)
	refresh_public_addresses_button.pressed.connect(_refresh_public_addresses)
	copy_public_ipv4_button.pressed.connect(_copy_public_ipv4)
	copy_public_ipv6_button.pressed.connect(_copy_public_ipv6)
	port_input.value_changed.connect(_on_port_changed)
	ip_mode_option.item_selected.connect(_on_ip_mode_selected)
	NetworkManager.connection_state_changed.connect(_on_connection_state_changed)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.connection_cancelled.connect(_on_connection_cancelled)
	NetworkManager.public_addresses_changed.connect(
		_refresh_public_endpoint_labels
	)
	if not NetworkManager.last_status_message.is_empty():
		status_label.text = NetworkManager.last_status_message
	_update_busy_state(NetworkManager.connection_state)
	_refresh_public_endpoint_labels()
	if (
		not NetworkManager.public_ipv4_query_finished
		and not NetworkManager.public_ipv6_query_finished
	):
		call_deferred("_refresh_public_addresses")


func _on_host_pressed() -> void:
	var bind_address: String = _get_effective_bind_address()
	var start_error: Error = NetworkManager.host_session(
		display_name_input.text,
		int(port_input.value),
		bind_address
	)
	if start_error != OK:
		status_label.text = _describe_start_error(start_error)
		return
	_save_preferences()


func _on_join_pressed() -> void:
	var start_error: Error = NetworkManager.join_session(
		display_name_input.text,
		address_input.text,
		int(port_input.value)
	)
	if start_error != OK:
		status_label.text = _describe_start_error(start_error)
		return
	address_input.text = LobbyProtocol.normalize_connection_address(
		address_input.text
	)
	_save_preferences()


func _setup_ip_modes(preferred_mode: String) -> void:
	if preferred_mode in [
		ConnectionPreferences.IP_MODE_DUAL,
		ConnectionPreferences.IP_MODE_IPV4,
		ConnectionPreferences.IP_MODE_IPV6,
	]:
		_selected_ip_mode = preferred_mode
	else:
		_selected_ip_mode = ConnectionPreferences.IP_MODE_DUAL
	_refresh_ip_mode_option()


func _refresh_ip_mode_option() -> void:
	_updating_ip_mode_option = true
	ip_mode_option.clear()
	_add_ip_mode(
		"IPv4 + IPv6（默认）",
		ConnectionPreferences.IP_MODE_DUAL
	)
	_add_ip_mode("仅 IPv4", ConnectionPreferences.IP_MODE_IPV4)
	_add_ip_mode("仅 IPv6", ConnectionPreferences.IP_MODE_IPV6)
	var selected_index: int = 0
	for index: int in range(ip_mode_option.item_count):
		if String(ip_mode_option.get_item_metadata(index)) == _selected_ip_mode:
			selected_index = index
			break
	if not _specific_bind_address.is_empty():
		_add_ip_mode(
			"特定适配器：%s" % _get_specific_adapter_name(),
			SPECIFIC_ADAPTER_MODE
		)
		selected_index = ip_mode_option.item_count - 1
	ip_mode_option.select(selected_index)
	_updating_ip_mode_option = false


func _add_ip_mode(label: String, mode: String) -> void:
	ip_mode_option.add_item(label)
	ip_mode_option.set_item_metadata(ip_mode_option.item_count - 1, mode)


func _get_selected_ip_mode() -> String:
	return _selected_ip_mode


func _on_ip_mode_selected(index: int) -> void:
	if _updating_ip_mode_option:
		return
	var selected_mode: String = String(ip_mode_option.get_item_metadata(index))
	if selected_mode == SPECIFIC_ADAPTER_MODE:
		return
	_selected_ip_mode = selected_mode
	_specific_bind_address = ""
	_refresh_ip_mode_option()
	if _advanced_settings != null:
		_advanced_settings.configure(
			_local_addresses,
			_specific_bind_address,
			int(port_input.value)
		)


func _get_specific_adapter_name() -> String:
	for local_address: LocalNetworkAddress in _local_addresses:
		if local_address.address.to_lower() != _specific_bind_address.to_lower():
			continue
		if not local_address.friendly_name.is_empty():
			return local_address.friendly_name
		if not local_address.interface_name.is_empty():
			return local_address.interface_name
	return _specific_bind_address


func _get_effective_bind_address() -> String:
	if not _specific_bind_address.is_empty():
		return _specific_bind_address
	match _get_selected_ip_mode():
		ConnectionPreferences.IP_MODE_IPV4:
			return LobbyProtocol.IPV4_ANY_ADDRESS
		ConnectionPreferences.IP_MODE_IPV6:
			return LobbyProtocol.IPV6_ANY_ADDRESS
		_:
			return LobbyProtocol.DEFAULT_BIND_ADDRESS


func _open_advanced_settings() -> void:
	if _advanced_settings != null:
		return
	var instance: Node = advanced_settings_scene.instantiate()
	if not instance is AdvancedNetworkSettings:
		instance.queue_free()
		status_label.text = "高级网络设置场景无效。"
		return
	_advanced_settings = instance as AdvancedNetworkSettings
	add_child(_advanced_settings)
	_advanced_settings.specific_address_changed.connect(
		_on_specific_address_changed
	)
	_advanced_settings.refresh_requested.connect(_on_advanced_refresh_requested)
	_advanced_settings.closed.connect(_close_advanced_settings)
	_advanced_settings.configure(
		_local_addresses,
		_specific_bind_address,
		int(port_input.value)
	)


func _close_advanced_settings() -> void:
	if _advanced_settings == null:
		return
	_advanced_settings.queue_free()
	_advanced_settings = null


func _on_specific_address_changed(address: String) -> void:
	_specific_bind_address = address
	_refresh_ip_mode_option()


func _on_advanced_refresh_requested() -> void:
	_refresh_local_addresses()
	if _advanced_settings != null:
		_advanced_settings.configure(
			_local_addresses,
			_specific_bind_address,
			int(port_input.value)
		)


func _refresh_local_addresses() -> void:
	_local_addresses = NetworkManager.get_local_connection_addresses()
	if not _specific_bind_address.is_empty():
		var selection_still_exists: bool = false
		for local_address: LocalNetworkAddress in _local_addresses:
			if (
				local_address.address.to_lower()
				== _specific_bind_address.to_lower()
			):
				selection_still_exists = true
				break
		if not selection_still_exists:
			_specific_bind_address = ""
	_refresh_ip_mode_option()


func _refresh_public_addresses() -> void:
	NetworkManager.refresh_public_addresses()


func _on_port_changed(_value: float) -> void:
	_refresh_public_endpoint_labels()
	if _advanced_settings != null:
		_advanced_settings.configure(
			_local_addresses,
			_specific_bind_address,
			int(port_input.value)
		)


func _refresh_public_endpoint_labels() -> void:
	if not NetworkManager.public_ipv4_address.is_empty():
		public_ipv4_label.text = "公网 IPv4：%s" % (
			NetworkManager.public_ipv4_address
		)
		copy_public_ipv4_button.disabled = false
	elif NetworkManager.public_ipv4_query_finished:
		public_ipv4_label.text = "公网 IPv4：查询失败"
		copy_public_ipv4_button.disabled = true
	else:
		public_ipv4_label.text = "公网 IPv4：查询中……"
		copy_public_ipv4_button.disabled = true

	if not NetworkManager.public_ipv6_address.is_empty():
		public_ipv6_label.text = "公网 IPv6：%s" % (
			NetworkManager.public_ipv6_address
		)
		copy_public_ipv6_button.disabled = false
	elif NetworkManager.public_ipv6_query_finished:
		public_ipv6_label.text = "公网 IPv6：当前不可用"
		copy_public_ipv6_button.disabled = true
	else:
		public_ipv6_label.text = "公网 IPv6：查询中……"
		copy_public_ipv6_button.disabled = true


func _copy_public_ipv4() -> void:
	_copy_public_address(NetworkManager.public_ipv4_address)


func _copy_public_ipv6() -> void:
	_copy_public_address(NetworkManager.public_ipv6_address)


func _copy_public_address(address: String) -> void:
	if address.is_empty():
		return
	DisplayServer.clipboard_set(address)
	status_label.text = "已复制：%s" % address


func _on_connection_state_changed(state: int) -> void:
	_update_busy_state(state)
	if state == NetworkManager.ConnectionState.CONNECTING:
		status_label.text = NetworkManager.last_status_message
	elif state == NetworkManager.ConnectionState.STARTING_HOST:
		status_label.text = "正在创建大厅……"


func _on_connection_failed(reason: String) -> void:
	status_label.text = reason


func _on_connection_cancelled(reason: String) -> void:
	status_label.text = reason


func _save_preferences() -> void:
	var preferences: ConnectionPreferences = ConnectionPreferences.new()
	preferences.display_name = SessionPlayer.normalize_display_name(
		display_name_input.text
	)
	preferences.join_address = LobbyProtocol.normalize_connection_address(
		address_input.text
	)
	preferences.port = int(port_input.value)
	preferences.ip_mode = _get_selected_ip_mode()
	preferences.specific_bind_address = _specific_bind_address
	var save_error: Error = preferences.save_to_file()
	if save_error != OK:
		push_warning(
			"Could not save connection preferences: %s" % error_string(save_error)
		)


func _update_busy_state(state: int) -> void:
	var is_busy: bool = state != NetworkManager.ConnectionState.OFFLINE
	var is_connecting: bool = state == NetworkManager.ConnectionState.CONNECTING
	display_name_input.editable = not is_busy
	address_input.editable = not is_busy
	port_input.editable = not is_busy
	ip_mode_option.disabled = is_busy
	advanced_settings_button.disabled = is_busy
	host_button.disabled = is_busy
	join_button.disabled = is_busy
	cancel_button.visible = is_connecting
	cancel_button.disabled = not is_connecting


func _describe_start_error(start_error: Error) -> String:
	if not NetworkManager.last_status_message.is_empty():
		return NetworkManager.last_status_message
	if start_error == ERR_INVALID_PARAMETER or start_error == ERR_INVALID_DATA:
		return "请填写有效昵称、地址和 1024–65535 端口。"
	if start_error == ERR_UNAVAILABLE:
		return "该 IPv6 地址范围暂不支持。"
	if start_error == ERR_DOES_NOT_EXIST:
		return "指定监听地址不属于本机当前可用网卡。"
	if start_error == ERR_ALREADY_IN_USE:
		return "当前已有连接正在运行。"
	if start_error == ERR_CANT_CREATE:
		return "无法创建大厅：UDP 端口可能已被占用。"
	return "操作失败：%s" % error_string(start_error)


func _assert_required_references() -> void:
	assert(display_name_input != null, "StartMenu requires display_name_input.")
	assert(address_input != null, "StartMenu requires address_input.")
	assert(port_input != null, "StartMenu requires port_input.")
	assert(ip_mode_option != null, "StartMenu requires ip_mode_option.")
	assert(
		advanced_settings_button != null,
		"StartMenu requires advanced_settings_button."
	)
	assert(
		advanced_settings_scene != null,
		"StartMenu requires advanced_settings_scene."
	)
	assert(public_ipv4_label != null, "StartMenu requires public_ipv4_label.")
	assert(public_ipv6_label != null, "StartMenu requires public_ipv6_label.")
	assert(
		copy_public_ipv4_button != null,
		"StartMenu requires copy_public_ipv4_button."
	)
	assert(
		copy_public_ipv6_button != null,
		"StartMenu requires copy_public_ipv6_button."
	)
	assert(
		refresh_public_addresses_button != null,
		"StartMenu requires refresh_public_addresses_button."
	)
	assert(host_button != null, "StartMenu requires host_button.")
	assert(join_button != null, "StartMenu requires join_button.")
	assert(cancel_button != null, "StartMenu requires cancel_button.")
	assert(status_label != null, "StartMenu requires status_label.")
