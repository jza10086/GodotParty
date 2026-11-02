## Default-route IPv4/IPv6 TCP reachability. No game protocol, TLS or inbound test.
extends Node

const TEST_HOSTS: Array[String] = ["aliyun.com", "www.baidu.com"]
const TIMEOUT_MS: int = 4000

class Attempt extends RefCounted:
	var family: IP.Type
	var label: String
	var hosts: Array[String] = []
	var index: int = -1
	var query: int = IP.RESOLVER_INVALID_ID
	var tcp: StreamPeerTCP
	var phase: String = "idle"
	var deadline: int = 0
	var started: int = 0
	var address: String = ""
	var status: String = "尚未检测"
	var history: PackedStringArray = []
	var available: bool = false

var active: bool = false
var results: Array[Attempt] = []
var _port: int = 443

## Optional endpoints support isolated loopback regression; the PC UI uses only the defaults.
func start(hosts: Array[String] = TEST_HOSTS, port: int = 443) -> Error:
	if active:
		return ERR_BUSY
	if hosts.is_empty() or port < 1 or port > 65535:
		return ERR_INVALID_PARAMETER
	for host: String in hosts:
		if host.strip_edges().is_empty():
			return ERR_INVALID_PARAMETER
	results.clear()
	_port = port
	for family: IP.Type in [IP.TYPE_IPV4, IP.TYPE_IPV6]:
		var attempt: Attempt = Attempt.new()
		attempt.family = family
		attempt.label = "IPv4" if family == IP.TYPE_IPV4 else "IPv6"
		attempt.hosts = hosts.duplicate()
		results.append(attempt)
		_next_host(attempt)
	active = true
	return OK

func stop() -> void:
	for attempt: Attempt in results:
		if attempt.phase != "done":
			_close(attempt)
			attempt.phase = "done"
			attempt.status = "已取消，未得出结论"
	active = false

func _exit_tree() -> void:
	stop()

func _process(_delta: float) -> void:
	if not active:
		return
	var now: int = Time.get_ticks_msec()
	for attempt: Attempt in results:
		if attempt.phase == "resolving":
			_poll_dns(attempt, now)
		elif attempt.phase == "connecting":
			_poll_tcp(attempt, now)
	active = results.any(func(attempt: Attempt) -> bool: return attempt.phase != "done")

func _next_host(attempt: Attempt) -> void:
	_close(attempt)
	attempt.index += 1
	if attempt.index >= attempt.hosts.size():
		attempt.phase = "done"
		attempt.status = "未验证可用（所有测试目标均未连接成功）"
		return
	var host: String = attempt.hosts[attempt.index]
	attempt.phase = "resolving"
	attempt.status = "正在解析 " + host
	attempt.deadline = Time.get_ticks_msec() + TIMEOUT_MS
	attempt.query = IP.resolve_hostname_queue_item(host, attempt.family)
	if attempt.query == IP.RESOLVER_INVALID_ID:
		_failed(attempt, "无法创建 DNS 查询")

func _poll_dns(attempt: Attempt, now: int) -> void:
	var state: IP.ResolverStatus = IP.get_resolve_item_status(attempt.query)
	if state == IP.RESOLVER_STATUS_DONE:
		attempt.address = IP.get_resolve_item_address(attempt.query)
		_release_dns(attempt)
		if not attempt.address.is_valid_ip_address() or attempt.address.contains(":") != (attempt.family == IP.TYPE_IPV6):
			_failed(attempt, "没有对应地址族的解析结果")
			return
		attempt.tcp = StreamPeerTCP.new()
		attempt.phase = "connecting"
		attempt.started = now
		attempt.deadline = now + TIMEOUT_MS
		attempt.status = "正在连接 " + _endpoint(attempt)
		var error: Error = attempt.tcp.connect_to_host(attempt.address, _port)
		if error != OK:
			_failed(attempt, "无法发起连接 " + _endpoint(attempt) + "：" + error_string(error))
	elif state in [IP.RESOLVER_STATUS_ERROR, IP.RESOLVER_STATUS_NONE]:
		_failed(attempt, "DNS 解析失败或没有 " + ("A" if attempt.family == IP.TYPE_IPV4 else "AAAA") + " 记录")
	elif now >= attempt.deadline:
		_failed(attempt, "DNS 解析超时（4 秒）")

func _poll_tcp(attempt: Attempt, now: int) -> void:
	var error: Error = attempt.tcp.poll()
	if error == OK and attempt.tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		attempt.available = true
		attempt.status = "出站可用 · " + attempt.hosts[attempt.index] + " → " + _endpoint(attempt) + " · 建连 %d ms" % (now - attempt.started)
		attempt.phase = "done"
		_close(attempt)
	elif error != OK or attempt.tcp.get_status() in [StreamPeerTCP.STATUS_ERROR, StreamPeerTCP.STATUS_NONE]:
		_failed(attempt, "TCP 连接失败 " + _endpoint(attempt) + ("：" + error_string(error) if error != OK else ""))
	elif now >= attempt.deadline:
		_failed(attempt, "TCP 连接超时（4 秒） " + _endpoint(attempt))

func _failed(attempt: Attempt, reason: String) -> void:
	attempt.history.append(attempt.hosts[attempt.index] + "：" + reason)
	_next_host(attempt)

func _release_dns(attempt: Attempt) -> void:
	if attempt.query != IP.RESOLVER_INVALID_ID:
		IP.erase_resolve_item(attempt.query)
		attempt.query = IP.RESOLVER_INVALID_ID

func _close(attempt: Attempt) -> void:
	_release_dns(attempt)
	if attempt.tcp != null:
		attempt.tcp.disconnect_from_host()
		attempt.tcp = null

func _endpoint(attempt: Attempt) -> String:
	return ("[%s]:%d" if attempt.family == IP.TYPE_IPV6 else "%s:%d") % [attempt.address, _port]

func report() -> String:
	if results.is_empty():
		return "IPv4：尚未检测\nIPv6：尚未检测"
	var lines: PackedStringArray = []
	for attempt: Attempt in results:
		lines.append(attempt.label + "：" + attempt.status)
		for item: String in attempt.history:
			lines.append("  " + item)
	return "\n".join(lines)
