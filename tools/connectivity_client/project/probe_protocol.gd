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
	var text: String = value.strip_edges().trim_prefix("[").trim_suffix("]")
	if not text.is_valid_ip_address() or text in ["0.0.0.0", "::"] or text.contains("%"):
		return ""
	# Scoped IPv6 link-local destinations need an interface selector, which this tool omits.
	if text.contains(":") and (text.to_lower().begins_with("ff") or (text.to_lower().begins_with("fe") and text.substr(2, 1).to_lower() in ["8", "9", "a", "b"])):
		return ""
	if not text.contains(":") and int(text.get_slice(".", 0)) >= 224:
		return ""
	return text

static func endpoint(host: String, port: int) -> String:
	return "[%s]:%d" % [host, port] if host.contains(":") else "%s:%d" % [host, port]

static func share(transport: String, host: String, port: int) -> String:
	return transport.to_lower() + "://" + endpoint(host, port)

## Paste accepts a literal IP or udp://IP:port / tcp://[IPv6]:port / http://IP:port.
static func parse_share(value: String) -> Dictionary:
	var text: String = value.strip_edges()
	var host: String = address(text)
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
	host = address(text.left(split))
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
