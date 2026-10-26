## One outstanding probe at a time. TCP includes a fresh connection in each RTT.
extends Node

const Protocol = preload("res://probe_protocol.gd")
const TIMEOUT_MS: int = 3000
var active: bool = false
var transport: String = "UDP"
var host: String = ""
var port: int = 0
var attempts: int = 0
var successes: int = 0
var timeouts: int = 0
var errors: int = 0
var canceled: int = 0
var last_ms: int = -1
var total_ms: int = 0
var status: String = "填写主机地址和测试端口"
var _udp: PacketPeerUDP
var _tcp: StreamPeerTCP
var _expected: String = ""
var _outgoing: PackedByteArray = PackedByteArray()
var _offset: int = 0
var _incoming: PackedByteArray = PackedByteArray()
var _started_at: int = 0
var _next_at: int = 0

func start(kind: String, address: String, destination_port: int) -> Error:
	stop()
	host = Protocol.address(address)
	if kind not in ["UDP", "TCP"] or host.is_empty() or destination_port < 1 or destination_port > 65535:
		status = "请填写有效的单播 IPv4 / IPv6 和 1–65535 端口（不支持带接口的链路本地 IPv6）"
		return ERR_INVALID_PARAMETER
	transport = kind
	port = destination_port
	attempts = 0
	successes = 0
	timeouts = 0
	errors = 0
	canceled = 0
	last_ms = -1
	total_ms = 0
	_next_at = 0
	active = true
	status = "开始探测，等待匹配回复"
	return OK

func stop(reason: String = "已停止") -> void:
	if not _expected.is_empty():
		canceled += 1
	_close_socket()
	_expected = ""
	if active:
		status = reason
	active = false

func _process(_delta: float) -> void:
	if not active:
		return
	var now: int = Time.get_ticks_msec()
	if _expected.is_empty():
		if now >= _next_at:
			_begin_probe(now)
		return
	if now - _started_at >= TIMEOUT_MS:
		timeouts += 1
		_finish("超时：3 秒内未收到匹配回复")
		return
	if _udp != null:
		for _index: int in range(mini(16, _udp.get_available_packet_count())):
			var packet: PackedByteArray = _udp.get_packet()
			if packet.size() <= Protocol.MAX_BYTES and packet.get_string_from_ascii() == _expected:
				_success(now)
				break
	elif _tcp != null:
		_poll_tcp(now)

func _begin_probe(now: int) -> void:
	attempts += 1
	_started_at = now
	var nonce: String = Crypto.new().generate_random_bytes(12).hex_encode()
	var request: String = "GPTEST/1 PING %d %s" % [attempts, nonce]
	_expected = request.replace(" PING ", " PONG ")
	status = "第 %d 次探测，等待回复" % attempts
	var error: Error = OK
	if transport == "UDP":
		_udp = PacketPeerUDP.new()
		error = _udp.connect_to_host(host, port)
		if error == OK:
			error = _udp.put_packet(request.to_ascii_buffer())
	else:
		_tcp = StreamPeerTCP.new()
		_outgoing = (request + "\n").to_ascii_buffer()
		_offset = 0
		_incoming.clear()
		error = _tcp.connect_to_host(host, port)
	if error != OK:
		_fail("无法发起探测：" + error_string(error))

func _poll_tcp(now: int) -> void:
	var error: Error = _tcp.poll()
	if error != OK or _tcp.get_status() in [StreamPeerTCP.STATUS_ERROR, StreamPeerTCP.STATUS_NONE]:
		_fail("TCP 连接失败或被关闭，未收到完整匹配回复")
		return
	if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	_tcp.set_no_delay(true)
	if _offset < _outgoing.size():
		var sent: Array = _tcp.put_partial_data(_outgoing.slice(_offset))
		if sent[0] != OK:
			_fail("TCP 发送失败：" + error_string(sent[0]))
			return
		_offset += int(sent[1])
	var available: int = _tcp.get_available_bytes()
	if available == 0:
		return
	if _incoming.size() + available > Protocol.MAX_BYTES + 2:
		_fail("TCP 回复过长或不是 GPTEST/1 协议")
		return
	var chunk: Array = _tcp.get_partial_data(available)
	if chunk[0] != OK:
		_fail("TCP 接收失败：" + error_string(chunk[0]))
		return
	_incoming.append_array(chunk[1])
	var text: String = _incoming.get_string_from_ascii()
	if text.contains("\n"):
		if text.get_slice("\n", 0).trim_suffix("\r") == _expected:
			_success(now)
		else:
			_fail("TCP 回复不匹配（协议、序号或随机标识不同）")

func _success(now: int) -> void:
	last_ms = now - _started_at
	total_ms += last_ms
	successes += 1
	_finish("双向探测成功：%d ms" % last_ms)

func _fail(message: String) -> void:
	errors += 1
	_finish(message)

func _finish(message: String) -> void:
	status = message
	_expected = ""
	_close_socket()
	_next_at = maxi(Time.get_ticks_msec() + 100, _started_at + 1000)

func _close_socket() -> void:
	if _udp != null:
		_udp.close()
	_udp = null
	if _tcp != null:
		_tcp.disconnect_from_host()
	_tcp = null

func report() -> String:
	var average: String = "—" if successes == 0 else str(roundi(float(total_ms) / successes)) + " ms"
	return "%s\n%s\n探测 %d · 成功 %d · 超时 %d · 错误 %d · 取消 %d\n最近 %s · 平均 %s\n%s" % [Protocol.share(transport, host, port), "运行中" if active else "已停止", attempts, successes, timeouts, errors, canceled, "—" if last_ms < 0 else str(last_ms) + " ms", average, status]

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		stop("进入后台，已停止；返回后请手动开始")

func _exit_tree() -> void:
	stop()
