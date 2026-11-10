## Read-only room roster and host-link RTT. Opening this panel never sends packets.
extends CanvasLayer

var _connection: Node
var _i18n: RefCounted
var _can_open: Callable
var _refresh_in: float = 0.0
var _rows: Array[Array] = []
@onready var _title: Label = %Title
@onready var _hint: Label = %Hint
@onready var _note: Label = %Note
@onready var _table: GridContainer = %Players

## The formal shell injects the existing connection and its current input context.
func configure(connection: Node, i18n: RefCounted, can_open: Callable) -> void:
	_connection = connection
	_i18n = i18n
	_can_open = can_open

func _ready() -> void:
	assert(_connection != null and _i18n != null and _can_open.is_valid(), "Network panel requires the application context")
	for index: int in range(8):
		var row: Array[Label] = []
		for column: int in range(4):
			var label: Label = Label.new()
			label.custom_minimum_size = Vector2([360.0, 140.0, 160.0, 140.0][column], 40.0)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if column == 0 else Control.SIZE_FILL
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if column in [1, 3] else HORIZONTAL_ALIGNMENT_LEFT
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size", 22)
			_table.add_child(label)
			row.append(label)
		_rows.append(row)
	_connection.changed.connect(_connection_changed)
	_i18n.changed.connect(_localize)
	get_window().focus_exited.connect(close)
	_localize()
	close()

func _text(key: String) -> String:
	return _i18n.text("core", StringName(key))

func _localize() -> void:
	_title.text = _text("玩家与延迟")
	_hint.text = _text("松开 Tab 关闭 · F3 查看总积分")
	_note.text = _text("延迟为玩家与房主之间的往返时间；其他玩家的数据由房主提供。")
	%PlayerHeading.text = _text("玩家")
	%LatencyHeading.text = _text("至房主 RTT")
	%StateHeading.text = _text("连接状态")
	%LossHeading.text = _text("丢包率")
	_note.text += "\n" + _text("丢包率为可靠包估计，约每 10 秒更新并平滑；自己的行显示上行，其他玩家显示房主下行。")
	if visible:
		_refresh()

func _connection_changed() -> void:
	if not _connection.online:
		close()
	elif visible:
		_refresh()

## Tab is reserved by the shell before GUI focus traversal and activity key handlers.
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or (event.keycode != KEY_TAB and event.physical_keycode != KEY_TAB):
		return
	if not event.pressed:
		if visible:
			close()
			get_viewport().set_input_as_handled()
		return
	if visible:
		get_viewport().set_input_as_handled()
		return
	if event.echo or event.ctrl_pressed or event.alt_pressed or event.shift_pressed or event.meta_pressed or not _can_open.call():
		return
	show()
	_refresh()
	_refresh_in = 0.5
	set_process(true)
	get_viewport().set_input_as_handled()

func close() -> void:
	hide()
	set_process(false)

func _process(delta: float) -> void:
	if not _can_open.call() or not (Input.is_physical_key_pressed(KEY_TAB) or Input.is_key_pressed(KEY_TAB)):
		close()
		return
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = 0.5
		_refresh()

func _refresh() -> void:
	var players: Array = _connection.players
	var local_peer: int = _connection.local_peer()
	for index: int in _rows.size():
		var row: Array = _rows[index]
		var occupied: bool = index < players.size()
		for label: Label in row:
			label.visible = occupied
		if not occupied:
			continue
		var player: Dictionary = players[index]
		row[0].text = player.name
		if player.peer_id == local_peer:
			row[0].text += " · " + _text("你")
		if player.peer_id == 1:
			row[0].text += " · " + _text("房主")
		row[0].modulate = Color.WHITE if player.connected else Color("#95a0ad")
		var sample: Dictionary = _connection.get_peer_stats(1 if player.peer_id == local_peer and not _connection.host else player.peer_id)
		var state: String = "host" if player.connected and player.peer_id == 1 else sample.state
		var captions: Dictionary[String, String] = {"host": "房主", "offline": "已掉线", "measuring": "测量中", "connected": "正常", "degraded": "波动较大", "stalled": "无响应"}
		var color: Color = Color("#99d9bf")
		if state in ["offline", "stalled"]:
			color = Color("#f28c8c")
		elif state == "degraded":
			color = Color("#f3c779")
		elif state == "measuring":
			color = Color("#b0bbc9")
		row[1].text = "%d ms" % roundi(sample.rtt_msec) if state in ["connected", "degraded"] else "—"
		row[2].text = _text(captions[state])
		row[1].modulate = color
		row[2].modulate = color
		row[3].text = "—"
		row[3].modulate = color
		if state in ["connected", "degraded"]:
			row[3].text = "%.1f%%" % sample.packet_loss_percent if sample.packet_loss_ready else _text("测量中")
