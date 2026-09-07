## Describes one usable local address exposed by a network interface.
class_name LocalNetworkAddress
extends RefCounted

var interface_name: String = ""
var friendly_name: String = ""
var address: String = ""
var ip_type: int = IP.TYPE_NONE
var is_loopback: bool = false


func _init(
		new_interface_name: String = "",
		new_friendly_name: String = "",
		new_address: String = "",
		new_ip_type: int = IP.TYPE_NONE,
		new_is_loopback: bool = false
) -> void:
	interface_name = new_interface_name
	friendly_name = new_friendly_name
	address = new_address
	ip_type = new_ip_type
	is_loopback = new_is_loopback


func get_display_text() -> String:
	var interface_label: String = friendly_name
	if interface_label.is_empty():
		interface_label = interface_name
	if interface_label.is_empty():
		interface_label = "本机接口"
	var type_label: String = "IPv6" if ip_type == IP.TYPE_IPV6 else "IPv4"
	var loopback_label: String = " · 本机测试" if is_loopback else ""
	return "%s · %s · %s%s" % [
		interface_label,
		type_label,
		address,
		loopback_label,
	]


func format_endpoint(port: int) -> String:
	return LobbyProtocol.format_endpoint(address, port)
