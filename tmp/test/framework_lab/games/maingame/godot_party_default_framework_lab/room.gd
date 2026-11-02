extends Control
## Test-owned room uses only PartyRoomAPI and the formal framework settings panels.
const RoomAPI: Script = preload("res://core/api/party_room_api.gd")
var room: RoomAPI
var _status: Label
var _ready_button: Button

func room_setup(value: RoomAPI) -> void:
	room = value

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 32)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)
	var title: Label = Label.new()
	title.text = "框架验证 · 正式大厅"
	title.add_theme_font_size_override("font_size", 36)
	column.add_child(title)
	_status = Label.new()
	_status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_button(column, "小游戏池（勾选测试小游戏和空白模板）", room.open_settings.bind("pool"))
	_button(column, "原版协议与本地设置", room.open_settings.bind("protocol"))
	_ready_button = _button(column, "准备 / 开始", room.ready_or_start)
	_button(column, "离开房间", room.leave)
	room_refresh()

func room_refresh() -> void:
	if _status == null:
		return
	var value: Dictionary = room.get_state()
	var lines: PackedStringArray = ["允许开始人数：" + value.allowed_counts]
	for player: Dictionary in value.players:
		lines.append("%s · %s" % [player.name, "已准备" if player.ready else "未准备"])
	lines.append(value.start_reason)
	_status.text = "\n".join(lines)
	_ready_button.text = "开始测试" if value.host else ("取消准备" if value.local_ready else "准备")
	_ready_button.disabled = value.host and not value.start_reason.is_empty()

func room_focus() -> void:
	_ready_button.grab_focus()

func room_stop() -> void:
	set_process(false)

func _button(parent: Node, caption: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = caption
	button.custom_minimum_size.y = 52
	button.pressed.connect(action)
	parent.add_child(button)
	return button
