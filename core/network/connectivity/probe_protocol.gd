## GPTEST/1 is a small, public reachability probe, independent of the game protocol.
extends RefCounted

const MAX_BYTES: int = 96

static func parse_port(value: String) -> int:
	var text: String = value.strip_edges()
	if text.is_empty() or text.length() > 5 or not _digits(text):
		return 0
	var port: int = text.to_int()
	return port if port >= 1 and port <= 65535 else 0

static func address(value: String) -> String:
	var text: String = value.strip_edges()
	if text.begins_with("[") and text.ends_with("]") and text.contains(":"):
		text = text.substr(1, text.length() - 2)
	if not text.is_valid_ip_address() or text in ["0.0.0.0", "::"] or text.contains("%"):
		return ""
	# Scoped IPv6 link-local destinations need an interface selector, which this tool omits.
	if text.contains(":") and (text.to_lower().begins_with("ff") or (text.to_lower().begins_with("fe") and text.substr(2, 1).to_lower() in ["8", "9", "a", "b"])):
		return ""
	if not text.contains(":") and int(text.get_slice(".", 0)) >= 224:
		return ""
	return text

## ASCII / Punycode DNS hostname, without a scheme, port or path.
static func hostname(value: String) -> String:
	var text: String = value.strip_edges().to_lower()
	var name: String = text.trim_suffix(".")
	if name.is_empty() or name.length() > 253:
		return ""
	var has_letter: bool = false
	for label: String in name.split("."):
		if label.is_empty() or label.length() > 63 or label.begins_with("-") or label.ends_with("-"):
			return ""
		for character: String in label:
			if character >= "a" and character <= "z":
				has_letter = true
			elif not (character >= "0" and character <= "9") and character != "-":
				return ""
	return text if has_letter else ""

## Connection targets accept DNS names; bind addresses remain literal unicast IPs.
static func target_address(value: String) -> String:
	var ip: String = address(value)
	return ip if not ip.is_empty() else hostname(value)

static func endpoint(host: String, port: int) -> String:
	return "[%s]:%d" % [host, port] if host.contains(":") else "%s:%d" % [host, port]

static func share(transport: String, host: String, port: int) -> String:
	return transport.to_lower() + "://" + endpoint(host, port)

## Paste accepts an IP / hostname, host:port, or udp:// / tcp:// / http:// endpoints.
static func parse_share(value: String) -> Dictionary:
	var text: String = value.strip_edges()
	var host: String = target_address(text)
	if not host.is_empty():
		return {"address": host}
	var scheme: String = ""
	if text.contains("://"):
		scheme = text.get_slice("://", 0).to_lower()
		if scheme not in ["udp", "tcp", "http"]:
			return {}
		text = text.substr(text.find("://") + 3).trim_suffix("/")
	var split: int = text.rfind(":")
	if split < 0 or (text.count(":") > 1 and not text.begins_with("[")):
		return {}
	host = target_address(text.left(split))
	var port: int = parse_port(text.substr(split + 1))
	if host.is_empty() or port == 0:
		return {}
	return {"address": host, "port": port, "transport": "TCP" if scheme in ["tcp", "http"] else ("UDP" if scheme == "udp" else "")}

static func valid_message(text: String, verb: String) -> bool:
	if text.length() > MAX_BYTES:
		return false
	var parts: PackedStringArray = text.split(" ", true)
	if parts.size() != 4 or parts[0] != "GPTEST/1" or parts[1] != verb:
		return false
	if parts[2].length() > 10 or not _digits(parts[2]) or parts[2].to_int() < 1 or parts[2].to_int() > 2147483647:
		return false
	if parts[3].length() != 24:
		return false
	for character: String in parts[3]:
		if not character in "0123456789abcdef":
			return false
	return true

static func _digits(text: String) -> bool:
	if text.is_empty():
		return false
	for character: String in text:
		if character < "0" or character > "9":
			return false
	return true
