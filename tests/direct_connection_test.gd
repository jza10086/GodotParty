## Focused checks for direct-connect validation, endpoints, preferences, and cancellation.
extends SceneTree

const TEST_SETTINGS_PATH: String = "user://direct_connection_test.cfg"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_address_validation()
	_test_endpoint_formatting()
	_test_scene_references()
	_test_connection_preferences()
	_test_host_binding_failures()
	_test_connection_timeout()
	await _test_cancel_connection()
	if _failures.is_empty():
		print("DIRECT_CONNECTION_TEST: PASS")
		_cleanup_test_settings()
		quit(0)
		return
	for failure: String in _failures:
		push_error("DIRECT_CONNECTION_TEST: %s" % failure)
	_cleanup_test_settings()
	quit(1)


func _test_address_validation() -> void:
	for address: String in [
		"127.0.0.1",
		"192.168.1.20",
		"localhost",
		"party.example.com",
		"::1",
		"[::1]",
		"2001:db8::10",
	]:
		_expect(
			LobbyProtocol.validate_address(address) == OK,
			"Address should be accepted: %s" % address
		)
	for address: String in [
		"",
		"127.0.0.1:7000",
		"udp://127.0.0.1",
		"example.com/room",
		"[::1",
		"[::1]:7000",
		"0.0.0.0",
		"169.254.20.1",
		"224.0.0.1",
		"::",
		"fe80::1",
		"fc00::1",
		"ff02::1",
	]:
		_expect(
			LobbyProtocol.validate_address(address) != OK,
			"Address should be rejected: %s" % address
		)
	_expect(
		LobbyProtocol.normalize_connection_address(" [::1] ") == "::1",
		"Bracketed IPv6 should normalize without brackets."
	)
	_expect(
		LobbyProtocol.validate_bind_address("*") == OK,
		"Wildcard bind should be accepted."
	)
	_expect(
		LobbyProtocol.validate_bind_address("::") == OK,
		"IPv6 wildcard bind should be accepted."
	)


func _test_endpoint_formatting() -> void:
	_expect(
		LobbyProtocol.format_endpoint("192.168.1.20", 7000)
		== "192.168.1.20:7000",
		"IPv4 endpoint should use address:port."
	)
	_expect(
		LobbyProtocol.format_endpoint("::1", 7000) == "[::1]:7000",
		"IPv6 endpoint should use brackets."
	)
	_expect(
		LobbyProtocol.is_public_ipv4_address("8.8.8.8"),
		"A globally routable IPv4 address should be public."
	)
	_expect(
		not LobbyProtocol.is_public_ipv4_address("192.168.1.2"),
		"A private IPv4 address should not be public."
	)
	_expect(
		not LobbyProtocol.is_public_ipv4_address("203.0.113.2"),
		"A documentation IPv4 address should not be public."
	)
	_expect(
		LobbyProtocol.is_public_ipv6_address("2606:4700:4700::1111"),
		"A global-unicast IPv6 address should be public."
	)
	_expect(
		not LobbyProtocol.is_public_ipv6_address("2001:db8::1"),
		"A documentation IPv6 address should not be public."
	)
	var local_address: LocalNetworkAddress = LocalNetworkAddress.new(
		"loopback",
		"Loopback",
		"::1",
		IP.TYPE_IPV6,
		true
	)
	_expect(
		local_address.format_endpoint(7000) == "[::1]:7000",
		"LocalNetworkAddress should format shareable endpoints."
	)


func _test_scene_references() -> void:
	var start_scene: PackedScene = load(
		"res://game/lobby/start_menu.tscn"
	) as PackedScene
	var lobby_scene: PackedScene = load(
		"res://game/lobby/lobby.tscn"
	) as PackedScene
	_expect(start_scene != null, "Start menu scene should load.")
	_expect(lobby_scene != null, "Lobby scene should load.")
	if start_scene != null:
		var start_instance: Node = start_scene.instantiate()
		_expect(
			start_instance.get("ip_mode_option") is OptionButton,
			"Start menu IP mode option should resolve to a node."
		)
		_expect(
			start_instance.get("public_ipv4_label") is Label,
			"Start menu public IPv4 label should resolve to a node."
		)
		_expect(
			start_instance.get_node_or_null(
				"Center/Panel/Margin/Content/Columns/HostColumn/SelectedAdapterLabel"
			) == null,
			"Adapter selection status should not appear on the start menu."
		)
		_expect(
			start_instance.get("advanced_settings_scene") is PackedScene,
			"Advanced network settings scene should resolve."
		)
		_expect(
			start_instance.get("cancel_button") is Button,
			"Start menu cancel button should resolve to a node."
		)
		start_instance.free()
	var advanced_scene: PackedScene = load(
		"res://game/lobby/advanced_network_settings.tscn"
	) as PackedScene
	_expect(advanced_scene != null, "Advanced network settings should load.")
	if advanced_scene != null:
		var advanced_instance: Node = advanced_scene.instantiate()
		_expect(
			advanced_instance.get("address_list") is VBoxContainer,
			"Advanced settings address list should resolve."
		)
		var address_scroll: Node = advanced_instance.get_node_or_null(
			"Center/Panel/Margin/Content/AddressScroll"
		)
		_expect(
			address_scroll is ScrollContainer,
			"Adapter addresses should be hosted in a ScrollContainer."
		)
		advanced_instance.free()
	if lobby_scene != null:
		var lobby_instance: Node = lobby_scene.instantiate()
		_expect(
			lobby_instance.get("connection_info_container") is VBoxContainer,
			"Lobby connection container should resolve to a node."
		)
		lobby_instance.free()


func _test_connection_preferences() -> void:
	var preferences: ConnectionPreferences = ConnectionPreferences.new()
	preferences.display_name = "测试玩家"
	preferences.join_address = "2001:db8::20"
	preferences.port = 17040
	preferences.ip_mode = ConnectionPreferences.IP_MODE_IPV6
	preferences.specific_bind_address = "2001:db8::20"
	_expect(
		preferences.save_to_file(TEST_SETTINGS_PATH) == OK,
		"Connection preferences should save."
	)
	var loaded: ConnectionPreferences = ConnectionPreferences.load_from_file(
		TEST_SETTINGS_PATH
	)
	_expect(loaded.display_name == "测试玩家", "Nickname should restore.")
	_expect(loaded.join_address == "2001:db8::20", "Address should restore.")
	_expect(loaded.port == 17040, "Port should restore.")
	_expect(
		loaded.ip_mode == ConnectionPreferences.IP_MODE_IPV6,
		"IP mode should restore."
	)
	_expect(
		loaded.specific_bind_address == "2001:db8::20",
		"Specific adapter address should restore."
	)
	_expect(
		loaded.get_effective_bind_address() == "2001:db8::20",
		"Specific adapter should override the main IP mode."
	)


func _test_host_binding_failures() -> void:
	var session: GameSessionState = GameSessionState.new()
	session.name = "BindingFailureSession"
	root.add_child(session)
	var manager: NetworkManagerService = NetworkManagerService.new()
	manager.name = "BindingFailureManager"
	manager.game_session = session
	root.add_child(manager)
	var invalid_bind_error: Error = manager.host_session(
		"BindingTester",
		17042,
		"203.0.113.10"
	)
	_expect(
		invalid_bind_error == ERR_DOES_NOT_EXIST,
		"An exact bind that is not local should be rejected."
	)

	manager.queue_free()
	session.queue_free()


func _test_connection_timeout() -> void:
	var session: GameSessionState = GameSessionState.new()
	session.name = "TimeoutSession"
	root.add_child(session)
	var manager: NetworkManagerService = NetworkManagerService.new()
	manager.name = "TimeoutManager"
	manager.game_session = session
	root.add_child(manager)
	var failures: Array[String] = []
	manager.connection_failed.connect(
		func(reason: String) -> void:
			failures.append(reason)
	)
	var join_error: Error = manager.join_session(
		"TimeoutTester",
		"192.0.2.1",
		17043
	)
	_expect(join_error == OK, "A timeout test connection should create its peer.")
	if join_error == OK:
		manager._on_connection_timeout(1)
		_expect(
			manager.connection_state == NetworkManagerService.ConnectionState.OFFLINE,
			"A connection timeout should return to OFFLINE."
		)
		_expect(
			failures.size() == 1 and failures[0].contains("连接超时"),
			"A connection timeout should emit a focused reason."
		)
	manager.queue_free()
	session.queue_free()


func _test_cancel_connection() -> void:
	var session: GameSessionState = GameSessionState.new()
	session.name = "DirectConnectionSession"
	root.add_child(session)
	var manager: NetworkManagerService = NetworkManagerService.new()
	manager.name = "DirectConnectionManager"
	manager.game_session = session
	root.add_child(manager)
	var cancelled: Array[String] = []
	manager.connection_cancelled.connect(
		func(reason: String) -> void:
			cancelled.append(reason)
	)
	var join_error: Error = manager.join_session(
		"CancelTester",
		"192.0.2.1",
		17041
	)
	_expect(join_error == OK, "A pending connection should create its ENet peer.")
	if join_error == OK:
		manager.cancel_connection()
		_expect(
			manager.connection_state == NetworkManagerService.ConnectionState.OFFLINE,
			"Cancelling should return to OFFLINE."
		)
		_expect(cancelled.size() == 1, "Cancelling should emit once.")
		_expect(manager.current_port == 0, "Cancelling should clear runtime details.")
	manager.queue_free()
	session.queue_free()
	await process_frame


func _cleanup_test_settings() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(TEST_SETTINGS_PATH)
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
