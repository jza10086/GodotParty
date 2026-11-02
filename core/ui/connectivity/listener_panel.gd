## Main-menu reachability dialog. Its sockets live only while this panel is visible.
extends VBoxContainer

const Protocol = preload("res://core/network/connectivity/probe_protocol.gd")
const Listener = preload("res://core/network/connectivity/probe_listener.gd")
var _listener: Node
var _transport: OptionButton
var _family: OptionButton
var _port: LineEdit
var _start: Button
var _stop: Button
var _addresses: OptionButton
var _address_label: Label
var _address_refresh: Button
var _copy: Button
var _web: Button
var _status: Label
var _notice: Label
var _elapsed: float = 0.0

func _ready() -> void:
	_transport = %Transport
	_transport.add_item("UDP")
	_transport.add_item("TCP")
	_family = %Family
	for label: String in ["IPv4 + IPv6", "仅 IPv4", "仅 IPv6"]:
		_family.add_item(label)
	_port = %Port
	_port.text = "7777"
	_port.max_length = 5
	_port.custom_minimum_size.x = 130
	_start = %Start
	_start.pressed.connect(_begin)
	_stop = %Stop
	_stop.pressed.connect(stop)
	_address_label = %AddressLabel
	_addresses = %Addresses
	_addresses.clip_text = true
	_addresses.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address_refresh = %AddressRefresh
	_address_refresh.pressed.connect(_refresh_addresses)
	_copy = %Copy
	_copy.pressed.connect(_copy_endpoint.bind(false))
	_web = %Web
	_web.pressed.connect(_copy_endpoint.bind(true))
	_status = %Status
	_notice = %Notice
	_listener = %Listener
	_family.item_selected.connect(func(_index: int) -> void: _refresh_addresses())
	_refresh_addresses()
	_refresh()

func _begin() -> void:
	if _listener.active:
		return
	var port: int = Protocol.parse_port(_port.text)
	if port == 0:
		_notice.text = "端口必须是 1–65535 的整数"
		return
	var kind: String = _transport.get_item_text(_transport.selected)
	var bindings: Array[String] = ["*", "0.0.0.0", "::"]
	var bind_address: String = bindings[_family.selected]
	if kind == "UDP":
		bind_address = Protocol.address(_selected_address())
		if bind_address.is_empty():
			_notice.text = "请先选择可用的本机 UDP 监听 / 回包 IP"
			return
	var error: Error = _listener.start(kind, port, bind_address)
	if error != OK:
		_notice.text = _listener.last_event
	elif kind == "UDP":
		_notice.text = "监听 / 回包 IP 已固定为 %s。其他设备请连接此地址；更换 IP 前请先停止。" % _listener.local_address
	else:
		_notice.text = "监听中。请将下方地址发给其他设备；复制网页链接仅适用于 TCP。"
	_refresh()

func stop() -> void:
	if _listener != null:
		_listener.stop()
		_refresh()

func stop_when_online(connection: Node) -> void:
	if connection.online:
		stop()

func _selected_address() -> String:
	return "" if _addresses.selected < 0 else str(_addresses.get_item_metadata(_addresses.selected))

func _refresh_addresses() -> void:
	# Never let a refresh change the displayed endpoint of an active UDP socket.
	if _listener != null and _listener.active and _listener.transport == "UDP":
		return
	var previous: String = _selected_address()
	_addresses.clear()
	var seen: Array[String] = []
	for interface: Dictionary in IP.get_local_interfaces():
		for raw: String in interface.get("addresses", []):
			var host: String = Protocol.address(raw)
			if host.is_empty() or host in seen:
				continue
			var v6: bool = host.contains(":")
			if (_family.selected == 1 and v6) or (_family.selected == 2 and not v6):
				continue
			seen.append(host)
			var local: bool = host in ["::1", "0:0:0:0:0:0:0:1"] or host.begins_with("127.")
			_addresses.add_item("%s · %s · %s%s" % ["IPv6" if v6 else "IPv4", interface.get("friendly", interface.get("name", "")), host, "（仅本机）" if local else ""])
			var index: int = _addresses.item_count - 1
			_addresses.set_item_metadata(index, host)
			if host == previous:
				_addresses.select(index)
	if _addresses.item_count == 0:
		_addresses.add_item("没有可用地址，请检查网卡并刷新")
		_addresses.set_item_metadata(0, "")

func _copy_endpoint(web: bool) -> void:
	var host: String = _listener.local_address if _listener.transport == "UDP" else _selected_address()
	if host.is_empty() or not _listener.active:
		_notice.text = "请先开始监听并选择可用地址"
		return
	var text: String = "http://" + Protocol.endpoint(host, _listener.port) + "/" if web else Protocol.share(_listener.transport, host, _listener.port)
	DisplayServer.clipboard_set(text)
	_notice.text = "已复制：" + text

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.25:
		_elapsed = 0.0
		_refresh()

func _refresh() -> void:
	if _listener == null:
		return
	var udp: bool = _transport.get_item_text(_transport.selected) == "UDP"
	var fixed_address: bool = _listener.active and _listener.transport == "UDP"
	_family.set_item_text(0, "全部地址" if udp else "IPv4 + IPv6")
	_family.tooltip_text = "筛选候选地址；UDP 一次只监听所选 IP" if udp else "选择 TCP 监听地址族"
	_address_label.text = "UDP 监听 / 回包 IP（只监听所选地址；链路本地 IPv6 未列出）" if udp else "本机分享地址（不是公网可达性证明；链路本地 IPv6 未列出）"
	_addresses.disabled = fixed_address
	_address_refresh.disabled = fixed_address
	_start.disabled = _listener.active or (udp and _selected_address().is_empty())
	_stop.disabled = not _listener.active
	_transport.disabled = _listener.active
	_family.disabled = _listener.active
	_port.editable = not _listener.active
	_copy.disabled = not _listener.active
	_web.disabled = not _listener.active or _listener.transport != "TCP"
	_status.text = "%s\n有效请求 %d · 回复提交 %d · 忽略 %d · 发送错误 %d\n%s" % ["%s 监听中 · %s" % [_listener.transport, Protocol.endpoint(_listener.local_address, _listener.port)] if _listener.active else "已停止监听", _listener.received, _listener.replied, _listener.discarded, _listener.send_errors, _listener.last_event]
