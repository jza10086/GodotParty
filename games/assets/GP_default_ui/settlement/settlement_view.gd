## Optional protocol-owned round result presentation. The game supplies ranks and local scores;
## this view neither computes rewards nor coordinates readiness or the next activity.
extends Control

@export var result_row_scene: PackedScene
var _presentation: Dictionary = {}
var _columns: Array = []
var _names: Dictionary = {}
var _seconds: float = -1.0
var _initialized: bool = false

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
	assert(result_row_scene != null, "Assign the settlement row scene")
	if not _presentation.is_empty():
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
		var label: Label = %ScoreHeading.duplicate()
		%Heading.add_child(label)
		label.show()
		label.name = "Metric%d" % index
		label.text = _columns[index].title
		label.tooltip_text = label.text
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

func _add_row(row: Dictionary) -> void:
	var line: HBoxContainer = result_row_scene.instantiate()
	line.name = "Row" + str(_rows.get_child_count() + 1)
	line.set_meta(&"player_id", str(row.get("player_id", "")))
	_rows.add_child(line)
	var rank_value: int = _rank(row)
	line.get_node("Rank").text = "—" if rank_value == 0 else str(rank_value)
	var name_label: Label = line.get_node("PlayerName")
	name_label.text = str(_names.get(row.get("player_id", ""), "—"))
	name_label.tooltip_text = name_label.text
	var template: Label = line.get_node("Metric")
	template.hide()
	for index: int in _columns.size():
		var column: Dictionary = _columns[index]
		var label: Label = template.duplicate()
		line.add_child(label)
		label.show()
		label.name = "Metric%d" % index
		label.text = _metric(row.get("metrics", {}).get(column.key), column.format)
		label.tooltip_text = label.text

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
