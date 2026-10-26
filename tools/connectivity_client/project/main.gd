## Standalone touch-friendly UDP/TCP probe UI; no game content or saved settings.
extends Control

const Protocol = preload("res://probe_protocol.gd")
const Probe = preload("res://probe_client.gd")
var _probe: Node
var _transport: OptionButton
var _address: LineEdit
var _port: LineEdit
var _start: Button
var _stop: Button
var _paste: Button
var _result: Label
var _notice: Label
var _margin: MarginContainer
var _elapsed: float = 0.0

func _ready() -> void:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Noto Sans CJK SC", "Noto Sans SC", "Microsoft YaHei", "sans-serif"])
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 28
	var background: ColorRect = ColorRect.new()
	background.color = Color("17232e")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin = MarginContainer.new()
	add_child(_margin)
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, 28)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_margin.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 18)
	scroll.add_child(box)
	var title: Label = _label(box, "连通性测试")
	title.add_theme_font_size_override("font_size", 44)
	_label(box, "先在电脑主界面打开“监听测试”并开始监听，再填写该电脑的地址。")
	if OS.get_name() == "iOS":
		_label(box, "连接局域网时请允许“本地网络”权限；若已拒绝，请在系统设置中开启后重试。SideStore 安装或刷新完成后，建议关闭 LocalDevVPN 再测试。")
	_transport = OptionButton.new()
	_transport.add_item("UDP")
	_transport.add_item("TCP")
	_transport.custom_minimum_size.y = 72
	box.add_child(_transport)
	_label(box, "主机 IPv4 / IPv6 地址")
	_address = _field(box, "192.168.1.10 或 2001:db8::1", "")
	_address.max_length = 64
	_address.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	_label(box, "端口")
	_port = _field(box, "1–65535", "7777")
	_port.max_length = 5
	_port.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_paste = _button(box, "粘贴地址 / 分享链接", _paste_address)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	box.add_child(actions)
	_start = _button(actions, "开始测试", _begin)
	_stop = _button(actions, "停止", func() -> void: _probe.stop(); _refresh())
	_notice = _label(box, "每次最多等待 3 秒。TCP 每次重新连接；RTT 包含连接时间。")
	_result = _label(box, "尚未开始")
	_button(box, "复制测试结果", func() -> void:
		DisplayServer.clipboard_set(_probe.report())
		_notice.text = "测试结果已复制")
	_label(box, "成功表示收到匹配的应用层回复。超时不能单独判断是防火墙、地址、路由还是服务端问题；这也不代表游戏房间握手通过。进入后台会自动停止。")
	_probe = Probe.new()
	add_child(_probe)
	get_viewport().size_changed.connect(_fit_safe_area)
	_fit_safe_area()
	_refresh()

func _label(parent: Node, text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _field(parent: Node, placeholder: String, value: String) -> LineEdit:
	var field: LineEdit = LineEdit.new()
	field.placeholder_text = placeholder
	field.text = value
	field.custom_minimum_size.y = 76
	parent.add_child(field)
	return field

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 76
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _paste_address() -> void:
	var parsed: Dictionary = Protocol.parse_share(DisplayServer.clipboard_get())
	if parsed.is_empty():
		_notice.text = "剪贴板格式无效。请复制 IP 或 udp://地址:端口 / tcp://[IPv6]:端口。"
		return
	_address.text = parsed.address
	if parsed.has("port"):
		_port.text = str(parsed.port)
	if not parsed.get("transport", "").is_empty():
		_transport.select(1 if parsed.transport == "TCP" else 0)
	_notice.text = "已填入，请确认后开始测试"

func _begin() -> void:
	_address.release_focus()
	_port.release_focus()
	var error: Error = _probe.start(_transport.get_item_text(_transport.selected), _address.text, Protocol.parse_port(_port.text))
	_notice.text = _probe.status if error != OK else "正在测试；修改协议或地址前请先停止"
	_refresh()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.2:
		_elapsed = 0.0
		_refresh()
		_fit_safe_area()

func _refresh() -> void:
	if _probe == null:
		return
	_start.disabled = _probe.active
	_stop.disabled = not _probe.active
	_paste.disabled = _probe.active
	_transport.disabled = _probe.active
	_address.editable = not _probe.active
	_port.editable = not _probe.active
	_result.text = _probe.report() if _probe.attempts > 0 else _probe.status

func _fit_safe_area() -> void:
	var left: float = 0.0
	var right: float = 0.0
	var top: float = 0.0
	var bottom: float = 0.0
	var screen: Vector2 = Vector2(DisplayServer.window_get_size())
	if screen.x <= 0 or screen.y <= 0:
		return
	if OS.get_name() in ["Android", "iOS"]:
		var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
		var factor: Vector2 = size / screen
		if safe.has_area():
			left = maxf(0.0, safe.position.x) * factor.x
			top = maxf(0.0, safe.position.y) * factor.y
			right = maxf(0.0, screen.x - safe.end.x) * factor.x
			bottom = maxf(0.0, screen.y - safe.end.y) * factor.y
		bottom = maxf(bottom, DisplayServer.virtual_keyboard_get_height() * factor.y)
	# Keep the form readable on iPad and wide windows without narrowing phone layouts.
	var extra: float = maxf(0.0, (size.x - left - right - 900.0) / 2.0)
	_margin.offset_left = left + extra
	_margin.offset_top = top
	_margin.offset_right = -right - extra
	_margin.offset_bottom = -bottom

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _probe != null:
		_probe.stop("返回操作，已停止测试")
		_refresh()
