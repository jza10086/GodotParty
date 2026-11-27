## Full-page final standings. The application owns returning the room to the lobby.
extends Control

signal lobby_requested()


func _ready() -> void:
	%Return.pressed.connect(func() -> void: lobby_requested.emit())


func configure(presentation: Dictionary, players: Array[Dictionary], format_metric: Callable) -> void:
	%Title.text = presentation.get("title", "最终排名")
	var names: Dictionary[String, String] = {}
	var colors: Dictionary[String, Color] = {}
	for player: Dictionary in players:
		var pid: String = str(player.get("player_id", ""))
		names[pid] = str(player.get("name", pid))
		var appearance: Variant = player.get("appearance")
		if appearance is Dictionary:
			var raw_c: Variant = (appearance as Dictionary).get("color")
			if raw_c is Color:
				colors[pid] = raw_c as Color
			elif raw_c is String and Color.html_is_valid(raw_c as String):
				colors[pid] = Color.from_string(raw_c as String, Color.WHITE)
	var columns: Array = presentation.get("columns", [])
	_add_line(%Heading, "排名", "玩家", "状态", columns.map(func(column: Dictionary) -> String: return column.title), false, null, true)
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
		var member_ids: Array = row.get("members", [row.get("player_id", "")])
		var member_names: PackedStringArray = []
		var fallback_color: Variant = null
		for id_v: Variant in member_ids:
			var id_s: String = str(id_v)
			member_names.append(names.get(id_s, id_s))
			if fallback_color == null and colors.has(id_s):
				fallback_color = colors[id_s]
		var metrics: Array[String] = []
		for column: Dictionary in columns:
			metrics.append(format_metric.call(row.get("metrics", {}).get(column.key, "—"), column.get("format", "text")))
		var row_color: Variant = row.get("color", fallback_color)
		var name_color: Variant = row_color if row_color is Color else (Color.from_string(row_color, Color.WHITE) if row_color is String and Color.html_is_valid(row_color) else null)
		var panel: PanelContainer = PanelContainer.new()
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.175, 0.24, 0.88) if rank_value == 1 else Color(0.08, 0.125, 0.185, 0.84)
		style.border_color = (name_color as Color) if name_color is Color else (Color(0.95, 0.82, 0.44, 0.78) if rank_value == 1 else Color(0.58, 0.78, 0.94, 0.35))
		style.set_border_width_all(2)
		style.content_margin_left = 22.0
		style.content_margin_right = 22.0
		style.content_margin_top = 10.0
		style.content_margin_bottom = 10.0
		style.set_corner_radius_all(8)
		style.corner_detail = 16
		style.anti_aliasing = true
		panel.add_theme_stylebox_override("panel", style)
		%Rows.add_child(panel)
		var line: HBoxContainer = HBoxContainer.new()
		line.custom_minimum_size.y = 38.0
		panel.add_child(line)
		_add_line(line, str(rank_value) if rank_value > 0 else "—", row.get("name", " / ".join(member_names)), str(row.get("status", "")), metrics, rank_value == 1, name_color, false)
	%Return.grab_focus()


func _add_line(line: HBoxContainer, rank_text: String, player_name: String, status: String, metrics: Array, winner: bool, name_color: Variant = null, is_heading: bool = false) -> void:
	line.add_theme_constant_override("separation", 24)
	var rank_cell: Label = _cell(line, rank_text, 92.0, false, winner)
	rank_cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var name_cell: Label = _cell(line, player_name, 0.0, true, winner)
	if is_heading:
		rank_cell.add_theme_color_override("font_color", Color(0.66, 0.74, 0.83, 1.0))
		name_cell.add_theme_color_override("font_color", Color(0.66, 0.74, 0.83, 1.0))
	elif name_color is Color:
		name_cell.add_theme_color_override("font_color", name_color as Color)
	if is_heading:
		var st_head: Label = _cell(line, status, 140.0, false, false)
		st_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st_head.add_theme_color_override("font_color", Color(0.66, 0.74, 0.83, 1.0))
	else:
		var st_holder: HBoxContainer = HBoxContainer.new()
		st_holder.custom_minimum_size.x = 140.0
		st_holder.alignment = BoxContainer.ALIGNMENT_CENTER
		if not status.is_empty():
			var pill: PanelContainer = PanelContainer.new()
			var ps: StyleBoxFlat = StyleBoxFlat.new()
			var text_col: Color = Color(0.66, 0.74, 0.83, 1.0)
			if status == "冠军" or status == "MVP":
				ps.bg_color = Color(0.42, 0.32, 0.12, 0.92)
				text_col = Color("#f4d06f")
			elif status.contains("掉线") or status.contains("离线"):
				ps.bg_color = Color(0.62, 0.18, 0.22, 0.92)
				text_col = Color(0.98, 0.92, 0.92, 1.0)
			else:
				ps.bg_color = Color(0.14, 0.22, 0.32, 0.90)
			ps.set_corner_radius_all(6)
			ps.content_margin_left = 10.0
			ps.content_margin_right = 10.0
			ps.content_margin_top = 3.0
			ps.content_margin_bottom = 3.0
			pill.add_theme_stylebox_override("panel", ps)
			pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var sl: Label = Label.new()
			sl.text = status
			sl.add_theme_font_size_override("font_size", 16)
			sl.add_theme_color_override("font_color", text_col)
			pill.add_child(sl)
			st_holder.add_child(pill)
		line.add_child(st_holder)
	for value: String in metrics:
		var metric: Label = _cell(line, value, 180.0, false, winner)
		metric.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if is_heading:
			metric.add_theme_color_override("font_color", Color(0.66, 0.74, 0.83, 1.0))


func _cell(parent: HBoxContainer, value: String, width: float, expand: bool, accent: bool) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.tooltip_text = value
	label.custom_minimum_size.x = width
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color("#f4d06f") if accent else Color("#dce3ed"))
	parent.add_child(label)
	return label
