## Full-page final standings. The application owns returning the room to the lobby.
extends Control

signal lobby_requested()

func _ready() -> void:
	%Return.pressed.connect(func() -> void: lobby_requested.emit())

func configure(presentation: Dictionary, players: Array[Dictionary], format_metric: Callable) -> void:
	%Title.text = presentation.get("title", "最终排名")
	var names: Dictionary[String, String] = {}
	for player: Dictionary in players:
		names[player.player_id] = player.name
	var columns: Array = presentation.get("columns", [])
	_add_line(%Heading, "排名", "玩家", "状态", columns.map(func(column: Dictionary) -> String: return column.title), false)
	var ordered: Array[Dictionary] = []
	for index: int in presentation.get("rows", []).size():
		ordered.append({"row": presentation.rows[index], "order": index})
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left: int = a.row.get("rank", 0)
		var right: int = b.row.get("rank", 0)
		if left == right:
			return a.order < b.order
		return right == 0 or (left > 0 and left < right))
	for entry: Dictionary in ordered:
		var row: Dictionary = entry.row
		var rank_value: int = row.get("rank", 0)
		var member_names: PackedStringArray = []
		for id: String in row.get("members", [row.get("player_id", "")]):
			member_names.append(names.get(id, id))
		var metrics: Array[String] = []
		for column: Dictionary in columns:
			metrics.append(format_metric.call(row.get("metrics", {}).get(column.key, "—"), column.get("format", "text")))
		var panel: PanelContainer = PanelContainer.new()
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("#203c49") if rank_value == 1 else Color(0.12, 0.15, 0.19, 0.85)
		style.content_margin_left = 24
		style.content_margin_right = 24
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		style.set_corner_radius_all(8)
		panel.add_theme_stylebox_override("panel", style)
		%Rows.add_child(panel)
		var line: HBoxContainer = HBoxContainer.new()
		line.custom_minimum_size.y = 34
		panel.add_child(line)
		_add_line(line, str(rank_value) if rank_value > 0 else "—", row.get("name", " / ".join(member_names)), row.get("status", ""), metrics, rank_value == 1)
	%Return.grab_focus()

func _add_line(line: HBoxContainer, rank_text: String, player_name: String, status: String, metrics: Array, winner: bool) -> void:
	line.add_theme_constant_override("separation", 28)
	_cell(line, rank_text, 100, false, winner)
	_cell(line, player_name, 0, true, winner)
	_cell(line, status, 140, false, false)
	for value: String in metrics:
		var metric: Label = _cell(line, value, 180, false, winner)
		metric.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _cell(parent: HBoxContainer, value: String, width: float, expand: bool, accent: bool) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.tooltip_text = value
	label.custom_minimum_size.x = width
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color("#b5e4ed") if accent else Color("#dce3ed"))
	parent.add_child(label)
	return label
