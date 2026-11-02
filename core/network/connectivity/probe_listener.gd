## Bounded raw UDP/TCP responder. This does not host or join a GodotParty room.
extends Node

const Protocol = preload("res://core/network/connectivity/probe_protocol.gd")
const PAGE: String = """<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>GodotParty 连通性测试</title><style>body{font:20px system-ui;max-width:720px;margin:40px auto;padding:20px;background:#13202b;color:#eef5fa}button{font:inherit;padding:12px}pre{white-space:pre-wrap}</style><h1>TCP 连通性测试</h1><p>页面来自正在监听的 GodotParty。每秒通过 HTTP 校验一次回复，不代表游戏协议握手通过。</p><button id="toggle">停止测试</button><pre id="result">正在测试…</pre><script>
let active=true,ok=0,fail=0,timer;const result=document.querySelector('#result');document.querySelector('#toggle').onclick=()=>{active=!active;document.querySelector('#toggle').textContent=active?'停止测试':'继续测试';if(active)run();else clearTimeout(timer)};
async function run(){if(!active)return;const nonce=Date.now().toString(16)+Math.random().toString(16).slice(2);const start=performance.now();const abort=new AbortController();const timeout=setTimeout(()=>abort.abort(),3000);try{const response=await fetch('/ping?nonce='+nonce,{cache:'no-store',signal:abort.signal});const data=await response.json();if(!response.ok||data.nonce!==nonce)throw Error('回复不匹配');ok++;result.textContent='成功 '+ok+' / 失败 '+fail+' / 往返 '+Math.round(performance.now()-start)+' ms'}catch(e){fail++;result.textContent='成功 '+ok+' / 失败 '+fail+' / '+e.message}finally{clearTimeout(timeout);if(active)timer=setTimeout(run,1000)}}run();
</script></html>"""

var active: bool = false
var transport: String = "UDP"
var port: int = 0
## Bound local endpoint; UDP replies use this address when it is a concrete IP.
var local_address: String = ""
var received: int = 0
var replied: int = 0
var discarded: int = 0
var send_errors: int = 0
var last_event: String = "尚未开始"
var _udp: PacketPeerUDP
var _server: TCPServer
var _clients: Array[Dictionary] = []
var _window: int = 0
var _budget: int = 64

func start(kind: String, listen_port: int, bind_address: String = "*") -> Error:
	stop()
	if kind not in ["UDP", "TCP"] or listen_port < 1 or listen_port > 65535:
		return ERR_INVALID_PARAMETER
	var normalized: String = bind_address if bind_address in ["*", "0.0.0.0", "::"] else Protocol.address(bind_address)
	if normalized.is_empty():
		return ERR_INVALID_PARAMETER
	local_address = normalized
	transport = kind
	port = listen_port
	received = 0
	replied = 0
	discarded = 0
	send_errors = 0
	_budget = 64
	_window = Time.get_ticks_msec()
	var error: Error = OK
	if kind == "UDP":
		_udp = PacketPeerUDP.new()
		error = _udp.bind(port, local_address, 65536)
	else:
		_server = TCPServer.new()
		error = _server.listen(port, local_address)
	if error != OK:
		stop()
		last_event = "监听失败：" + error_string(error) + "（检查本机地址是否仍有效、端口是否被占用）"
		return error
	active = true
	last_event = "%s 已绑定 %s，等待外部探测" % [transport, Protocol.endpoint(local_address, port)]
	return OK

func stop() -> void:
	if _udp != null:
		_udp.close()
	_udp = null
	if _server != null:
		_server.stop()
	_server = null
	for client: Dictionary in _clients:
		client.peer.disconnect_from_host()
	_clients.clear()
	if active:
		last_event = "已停止，端口已释放"
	active = false

func _process(_delta: float) -> void:
	if not active:
		return
	var now: int = Time.get_ticks_msec()
	if now - _window >= 1000:
		_window = now
		_budget = 64
	if _udp != null:
		_poll_udp()
	else:
		_poll_tcp(now)

func _poll_udp() -> void:
	for _index: int in range(mini(32, _udp.get_available_packet_count())):
		var packet: PackedByteArray = _udp.get_packet()
		var host: String = _udp.get_packet_ip()
		var source_port: int = _udp.get_packet_port()
		var text: String = packet.get_string_from_ascii() if packet.size() <= Protocol.MAX_BYTES else ""
		if _budget <= 0 or not Protocol.valid_message(text, "PING"):
			discarded += 1
			continue
		_budget -= 1
		received += 1
		var error: Error = _udp.set_dest_address(host, source_port)
		if error == OK:
			error = _udp.put_packet(text.replace(" PING ", " PONG ").to_ascii_buffer())
		_record_reply(error, Protocol.endpoint(host, source_port))

func _poll_tcp(now: int) -> void:
	for _index: int in range(8):
		if not _server.is_connection_available():
			break
		var peer: StreamPeerTCP = _server.take_connection()
		if _clients.size() >= 8 or _budget <= 0:
			peer.disconnect_from_host()
			discarded += 1
			continue
		_budget -= 1
		peer.set_no_delay(true)
		_clients.append({"peer": peer, "input": PackedByteArray(), "output": PackedByteArray(), "offset": 0, "deadline": now + 5000, "responding": false, "source": Protocol.endpoint(peer.get_connected_host(), peer.get_connected_port())})
	for index: int in range(_clients.size() - 1, -1, -1):
		var client: Dictionary = _clients[index]
		var peer: StreamPeerTCP = client.peer
		var poll_error: Error = peer.poll()
		if poll_error != OK or peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or now >= client.deadline:
			_close_client(index)
			continue
		if client.responding:
			var sent: Array = peer.put_partial_data(client.output.slice(client.offset))
			if sent[0] != OK:
				_record_reply(sent[0], client.source)
				_close_client(index)
				continue
			client.offset += int(sent[1])
			if client.offset == client.output.size():
				_record_reply(OK, client.source)
				_close_client(index)
			continue
		var available: int = peer.get_available_bytes()
		if available == 0:
			continue
		if client.input.size() + available > 4096:
			discarded += 1
			_close_client(index)
			continue
		var chunk: Array = peer.get_partial_data(available)
		if chunk[0] != OK:
			_close_client(index)
			continue
		client.input.append_array(chunk[1])
		var text: String = client.input.get_string_from_ascii()
		if text.begins_with("GET "):
			if text.contains("\r\n\r\n"):
				client.output = _http_response(text).to_utf8_buffer()
				client.responding = true
		elif text.contains("\n"):
			var line: String = text.get_slice("\n", 0).trim_suffix("\r")
			if Protocol.valid_message(line, "PING"):
				received += 1
				client.output = (line.replace(" PING ", " PONG ") + "\n").to_ascii_buffer()
				client.responding = true
			else:
				discarded += 1
				_close_client(index)

func _http_response(request: String) -> String:
	var target: String = request.get_slice("\r\n", 0).get_slice(" ", 1)
	var body: String = "Not found"
	var status: String = "404 Not Found"
	var mime: String = "text/plain; charset=utf-8"
	if target == "/":
		body = PAGE
		mime = "text/html; charset=utf-8"
		status = "200 OK"
	elif target.begins_with("/ping?nonce="):
		var nonce: String = target.trim_prefix("/ping?nonce=")
		var valid: bool = not nonce.is_empty() and nonce.length() <= 64
		for character: String in nonce:
			if not character in "0123456789abcdef":
				valid = false
		if valid:
			body = JSON.stringify({"nonce": nonce})
			mime = "application/json"
			status = "200 OK"
	if status == "200 OK":
		received += 1
	else:
		discarded += 1
	return "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n%s" % [status, mime, body.to_utf8_buffer().size(), body]

func _record_reply(error: Error, source: String) -> void:
	if error == OK:
		replied += 1
		last_event = "%s 收到探测并交给系统发送回复：%s" % [Time.get_time_string_from_system(), source]
	else:
		send_errors += 1
		last_event = "回复发送失败：" + error_string(error)

func _close_client(index: int) -> void:
	_clients[index].peer.disconnect_from_host()
	_clients.remove_at(index)

func _exit_tree() -> void:
	stop()
