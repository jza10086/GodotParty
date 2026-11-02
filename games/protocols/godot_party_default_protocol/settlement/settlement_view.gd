## Optional protocol-owned round result presentation. The game supplies ranks and local scores;
## this view neither computes rewards nor coordinates readiness or the next activity.
extends Control

const LABEL: PackedScene = preload("res://core/ui/ambient_reveal/components/display/label.tscn")
var _presentation: Dictionary = {}
var _columns: Array = []
var _names: Dictionary = {}
var _seconds: float = -1.0
var _initialized: bool = false
var _compact: bool = false

@onready var _card: MarginContainer = %Card
@onready var _padding: MarginContainer = %Padding
@onready var _column: VBoxContainer = %Column
@onready var _title: Label = %Title
@onready var _rows: VBoxContainer = %Rows
@onready var _countdown: Label = %Countdown

## Public columns come from the game result. Missing metrics are shown as a dash.
func configure(presentation: Dictionary, players: Array[Dictionary]) -> void:
	_presentation = presentation.duplicate(true)
	_columns = _presentation.get("columns", [{"key": "score", "title": "本轮分数", "format": "integer"}])
	_names.clear()
	for player: Dictionary in players:
		var id: Variant = player.get("player_id")
		var display_name: Variant = player.get("name")
		if id is String and display_name is String:
			_names[id] = display_name
	if _initialized:
		_render()

## The owning controller publishes this countdown. A negative value waits for peers;
## the view never advances a timer or exposes a host-only Continue button.
func set_countdown(seconds: float) -> void:
	_seconds = seconds if is_finite(seconds) else -1.0
	if _initialized:
		_countdown.text = "等待其他玩家" if _seconds < 0.0 else "%d 秒后继续" % ceili(_seconds)

func _ready() -> void:
	_initialized = true
	resized.connect(_resize_layout)
	_resize_layout()
	_render()
	set_countdown(_seconds)

func _render() -> void:
	_title.text = str(_presentation.get("title", "本轮结算")).trim_prefix("GodotPartyDefault · ")
	_title.tooltip_text = _title.text
	for node: Node in %Heading.get_children():
		if node.has_meta("metric"):
			%Heading.remove_child(node)
			node.queue_free()
	%ScoreHeading.hide()
	for index: int in _columns.size():
		var label: Label = _label(%Heading, "Metric%d" % index, _columns[index].title)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.set_meta("metric", true)
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var ordered: Array[Dictionary] = []
	var source: Variant = _presentation.get("rows", [])
	if source is Array:
		for index: int in source.size():
			if source[index] is Dictionary:
				ordered.append({"row": source[index], "order": index})
	# Explicit source indices preserve tied ranks even though Array.sort_custom is not stable.
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var first: int = _rank(a.row)
		var second: int = _rank(b.row)
		if first == second:
			return int(a.order) < int(b.order)
		if first == 0 or second == 0:
			return second == 0
		return first < second)
	for entry: Dictionary in ordered.slice(0, 8):
		_add_row(entry.row)
	_resize_layout()

func _add_row(row: Dictionary) -> void:
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "Row" + str(_rows.get_child_count() + 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.set_meta(&"player_id", str(row.get("player_id", "")))
	_rows.add_child(line)
	var rank_value: int = _rank(row)
	var rank_label: Label = _label(line, "Rank", "—" if rank_value == 0 else str(rank_value))
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var name_label: Label = _label(line, "PlayerName", str(_names.get(row.get("player_id", ""), "—")))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.tooltip_text = name_label.text
	for index: int in _columns.size():
		var column: Dictionary = _columns[index]
		var label: Label = _label(line, "Metric%d" % index, _metric(row.get("metrics", {}).get(column.key), column.format))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.tooltip_text = label.text
		label.set_meta("metric", true)

func _rank(row: Dictionary) -> int:
	var value: Variant = row.get("rank", 0)
	if value is int or (value is float and is_finite(value) and value == floor(value)):
		return maxi(0, int(value))
	return 0

func _metric(value: Variant, format: String) -> String:
	if value == null:
		return "—"
	match format:
		"integer": return str(int(value))
		"decimal": return "%.2f" % float(value)
		"time": return "%02d:%05.2f" % [int(value) / 60000, fmod(float(value) / 1000.0, 60.0)]
	return str(value)

func _label(parent: Node, node_name: String, text: String) -> Label:
	var label: Label = LABEL.instantiate() as Label
	label.name = node_name
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _resize_layout() -> void:
	if not _initialized:
		return
	_compact = size.x < 1500.0 or size.y < 850.0
	var outer: int = 24 if _compact else 64
	for edge: String in ["left", "right", "top", "bottom"]:
		%Layout.add_theme_constant_override("margin_" + edge, outer)
		_padding.add_theme_constant_override("margin_" + edge, 24 if _compact else 42)
	_card.custom_minimum_size.x = maxf(0.0, minf(1080.0, size.x - float(outer * 2)))
	_column.add_theme_constant_override("separation", 14 if _compact else 20)
	_rows.add_theme_constant_override("separation", 4 if _compact else 6)
	_title.add_theme_font_size_override("font_size", 34 if _compact else 46)
	_countdown.add_theme_font_size_override("font_size", 18 if _compact else 21)
	var rank_width: float = 72.0 if _compact else 96.0
	var score_width: float = minf(180.0, _card.custom_minimum_size.x * 0.52 / maxi(1, _columns.size()))
	%RankHeading.custom_minimum_size.x = rank_width

	%Heading.add_theme_constant_override("separation", 20 if _compact else 28)
	for label: Label in %Heading.get_children():
		if label.has_meta("metric"):
			label.custom_minimum_size.x = score_width
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.tooltip_text = label.text
		label.add_theme_font_size_override("font_size", 18 if _compact else 21)
	for line: HBoxContainer in _rows.get_children():
		line.custom_minimum_size.y = 44 if _compact else 64
		line.add_theme_constant_override("separation", 20 if _compact else 28)
		line.get_node("Rank").custom_minimum_size.x = rank_width
		for label: Label in line.get_children():
			if label.has_meta("metric"):
				label.custom_minimum_size.x = score_width
			label.add_theme_font_size_override("font_size", 23 if _compact else 29)
