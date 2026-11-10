## Opt-in UDP relay below ENet. Only locally outgoing datagrams are impaired.
## Native acknowledgements, handshakes, RPC and scene replication all retain ENet semantics.
extends RefCounted

const MAX_LINKS: int = 32
const MAX_QUEUED_BYTES: int = 16 * 1024 * 1024
const MAX_QUEUED_PACKETS: int = 8192
const IDLE_LINK_MSEC: int = 30000
var _server: UDPServer = UDPServer.new()
var _links: Array[Dictionary] = []
var _queue: Array[Dictionary] = []
var _queued_bytes: int = 0
var _target_address: String = ""
var _target_port: int = 0
var _host_side: bool = false
var _delay_msec: int = 0
var _loss_percent: float = 0.0
var _random: RandomNumberGenerator = RandomNumberGenerator.new()

## Host: public socket -> loopback ENet. Client: loopback socket -> remote host.
## The caller passes already validated local settings. A failed bind leaves no active relay.
func start(bind_address: String, port: int, target_address: String, target_port: int, host_side: bool, values: Dictionary) -> Error:
	stop()
	_target_address = target_address
	_target_port = target_port
	_host_side = host_side
	_delay_msec = values.delay_msec
	_loss_percent = float(values.loss_percent)
	_random.randomize()
	return _server.listen(port, bind_address)

func is_active() -> bool:
	return _server.is_listening()

func local_port() -> int:
	return _server.get_local_port()

## Bound queues fail explicitly rather than introducing unconfigured packet loss.
func poll() -> Error:
	var error: Error = _server.poll()
	if error != OK:
		return error
	var now: int = Time.get_ticks_msec()
	while _server.is_connection_available():
		var incoming: PacketPeerUDP = _server.take_connection()
		if _links.size() >= MAX_LINKS:
			incoming.close()
			continue
		var outgoing: PacketPeerUDP = PacketPeerUDP.new()
		error = outgoing.connect_to_host(_target_address, _target_port)
		if error != OK:
			incoming.close()
			outgoing.close()
			return error
		_links.append({"incoming": incoming, "outgoing": outgoing, "last_activity": now})
	for link: Dictionary in _links:
		if link.incoming.get_available_packet_count() > 0 or link.outgoing.get_available_packet_count() > 0:
			link.last_activity = now
		error = _forward(link.incoming, link.outgoing, not _host_side, now)
		if error != OK:
			return error
		error = _forward(link.outgoing, link.incoming, _host_side, now)
		if error != OK:
			return error
	var sent: int = 0
	while sent < _queue.size() and _queue[sent].due <= now:
		var packet: Dictionary = _queue[sent]
		error = packet.target.put_packet(packet.bytes)
		if error != OK:
			return error
		_queued_bytes -= packet.bytes.size()
		sent += 1
	if sent > 0:
		_queue = _queue.slice(sent)
	for index: int in range(_links.size() - 1, -1, -1):
		if now - int(_links[index].last_activity) > IDLE_LINK_MSEC:
			_links[index].incoming.close()
			_links[index].outgoing.close()
			_links.remove_at(index)
	return OK

func _forward(source: PacketPeerUDP, target: PacketPeerUDP, impair: bool, now: int) -> Error:
	# Bound per-frame work; remaining datagrams stay in the socket's receive queue.
	for index: int in mini(source.get_available_packet_count(), 256):
		var bytes: PackedByteArray = source.get_packet()
		var error: Error = source.get_packet_error()
		if error != OK:
			return error
		if impair and _random.randf() * 100.0 < _loss_percent:
			continue
		if impair and _delay_msec > 0:
			if _queue.size() >= MAX_QUEUED_PACKETS or _queued_bytes + bytes.size() > MAX_QUEUED_BYTES:
				return ERR_OUT_OF_MEMORY
			_queue.append({"due": now + _delay_msec, "target": target, "bytes": bytes})
			_queued_bytes += bytes.size()
		else:
			error = target.put_packet(bytes)
			if error != OK:
				return error
	return OK

## Leaving always discards delayed packets, so they cannot enter the next session.
func stop() -> void:
	_queue.clear()
	_queued_bytes = 0
	for link: Dictionary in _links:
		link.outgoing.close()
	_server.stop()
	_links.clear()
