## Outbound diagnostics for the PC main menu. Uses the same probe behavior as Android.
extends VBoxContainer

const Protocol = preload("res://core/network/connectivity/probe_protocol.gd")
const Probe = preload("res://core/network/connectivity/probe_client.gd")
var _probe: Node
var _transport: OptionButton
var _address: LineEdit
var _port: LineEdit
var _start: Button
var _stop: Button
var _paste: Button
var _copy: Button
var _result: Label
var _notice: Label
var _elapsed: float = 0.0
var _outbound: Node
var _outbound_start: Button
var _outbound_stop: Button
var _outbound_copy: Button
var _outbound_result: Label

func _ready() -> void:
	_transport = %Transport
	_transport.add_item("UDP")
	_transport.add_item("TCP")
	_port = %Port
	_port.max_length = 5
	_address = %Address
	_address.max_length = 254
	_paste = %Paste
	_paste.pressed.connect(_paste_address)
	_start = %Start
	_start.pressed.connect(_begin)
	_stop = %Stop
	_stop.pressed.connect(stop)
	_notice = %Notice
	_result = %Result
	_copy = %Copy
	_copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_probe.report())
		_notice.text = "测试结果已复制")
	_probe = %Probe
	_address.text_submitted.connect(func(_text: String) -> void: _begin())
	_port.text_submitted.connect(func(_text: String) -> void: _begin())
	_build_outbound()
	_refresh()

func _paste_address() -> void:
	apply_address(DisplayServer.clipboard_get())

## Populate fields from a shared endpoint without starting a connection.
func apply_address(value: String) -> bool:
	if _probe.active:
		return false
	var parsed: Dictionary = Protocol.parse_share(value)
	if parsed.is_empty():
		_notice.text = "地址格式无效，请粘贴 IP、域名或 udp://主机:端口 / tcp://[IPv6]:端口"
		return false
	_address.text = parsed.address
	if parsed.has("port"):
		_port.text = str(parsed.port)
	if not parsed.get("transport", "").is_empty():
		_transport.select(1 if parsed.transport == "TCP" else 0)
	_notice.text = "已填入，请确认后开始测试"
	return true

func _begin() -> void:
	if _probe.active:
		return
	_address.release_focus()
	_port.release_focus()
	var error: Error = _probe.start(_transport.get_item_text(_transport.selected), _address.text, Protocol.parse_port(_port.text))
	_notice.text = _probe.status if error != OK else "正在测试；修改协议或地址前请先停止"
	_refresh()

func stop() -> void:
	if _outbound != null:
		_outbound.stop()
	if _probe != null:
		_probe.stop()
		_refresh()

func stop_when_online(connection: Node) -> void:
	if connection.online:
		stop()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.2:
		_elapsed = 0.0
		_refresh()

func _refresh() -> void:
	if _probe == null:
		return
	_start.disabled = _probe.active
	_stop.disabled = not _probe.active
	_paste.disabled = _probe.active
	_transport.disabled = _probe.active
	_address.editable = not _probe.active
	_port.editable = not _probe.active
	_copy.disabled = _probe.attempts == 0 and _probe.errors == 0
	_result.text = _probe.report() if _probe.attempts > 0 or _probe.errors > 0 else _probe.status
	if _outbound != null:
		_outbound_start.disabled = _outbound.active
		_outbound_stop.disabled = not _outbound.active
		_outbound_copy.disabled = _outbound.results.is_empty()
		_outbound_result.text = _outbound.report()

func _build_outbound() -> void:
	_outbound_start = %OutboundStart
	_outbound_start.pressed.connect(func() -> void:
		_outbound.start()
		_refresh())
	_outbound_stop = %OutboundStop
	_outbound_stop.pressed.connect(func() -> void:
		_outbound.stop()
		_refresh())
	_outbound_copy = %OutboundCopy
	_outbound_copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set("本机默认路由 TCP 443 出站检测\n" + _outbound.report()))
	_outbound_result = %OutboundResult
	_outbound = %Outbound
