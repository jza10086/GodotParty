## Passive Tab scoreboard and connection overview.
## The main game owns standings; core overlays Ping and high packet-loss warnings.
extends CanvasLayer

const COLOR_GOOD: Color = Color("#99d9bf")
const COLOR_WARN: Color = Color("#f3c779")
const COLOR_CRITICAL: Color = Color("#f28c8c")
const COLOR_MUTED: Color = Color("#95a0ad")
const COLOR_TEXT: Color = Color("#edf2f7")
const COLOR_GOLD: Color = Color("#f4d06f")
const COLOR_SILVER: Color = Color("#d5dde8")
const COLOR_BRONZE: Color = Color("#dfa578")
const METRIC_COLUMN_WIDTH: float = 144.0

@export var packet_loss_icon: Texture2D
@export var disconnected_icon: Texture2D
@export var host_icon: Texture2D
@export_range(0.0, 100.0, 0.5) var loss_warn_percent: float = 1.0
@export_range(0.0, 100.0, 0.5) var loss_critical_percent: float = 5.0
@export_range(10.0, 500.0, 5.0) var ping_warn_msec: float = 80.0
@export_range(20.0, 1000.0, 5.0) var ping_critical_msec: float = 150.0

var _connection: Node
var _i18n: RefCounted
var _can_open: Callable
var _standings: Callable
var _format_metric: Callable
var _refresh_in: float = 0.0
var _row_normal_style: StyleBoxFlat
var _row_self_style: StyleBoxFlat

@onready var _rank_heading: Label = %RankHeading
@onready var _player_heading: Label = %PlayerHeading
@onready var _metric_headings: HBoxContainer = %MetricHeadings
@onready var _ping_heading: Label = %PingHeading
@onready var _rows: VBoxContainer = %Rows

## Inject the active room connection and shell context before entering the tree.
func configure(connection: Node, i18n: RefCounted, can_open: Callable, standings: Callable, format_metric: Callable) -> void:
	_connection = connection
	_i18n = i18n
	_can_open = can_open
	_standings = standings
	_format_metric = format_metric

func _ready() -> void:
	assert(_connection != null and _i18n != null and _can_open.is_valid() and _standings.is_valid() and _format_metric.is_valid(), "Network panel requires the application context")
	assert(packet_loss_icon != null and disconnected_icon != null and host_icon != null, "Network panel requires status icons")
	_row_normal_style = _make_row_style(Color(0.09, 0.135, 0.20, 0.55), Color(0.58, 0.78, 0.94, 0.12), 0)
	_row_self_style = _make_row_style(Color(0.14, 0.26, 0.38, 0.86), Color(0.64, 0.84, 0.98, 0.75), 2)
	_connection.changed.connect(_connection_changed)
	_i18n.changed.connect(_localize)
	get_window().focus_exited.connect(close)
	_localize()
	close()

func _make_row_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _text(key: String) -> String:
	return _i18n.text("core", StringName(key))

func _localize() -> void:
	_rank_heading.text = _text("名次")
	_player_heading.text = _text("玩家")
	_ping_heading.text = "Ping"
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
	var presentation: Dictionary = _standings.call()
	var ranked: bool = not presentation.is_empty()
	var result_rows: Array = presentation.get("rows", [])
	var columns: Array = presentation.get("columns", [])
	var players: Array = _ordered_players(result_rows)
	var results: Dictionary = {}
	for entry: Variant in result_rows:
		if not entry is Dictionary:
			continue
		for id: Variant in entry.get("members", [entry.get("player_id", "")]):
			if id is String:
				results[id] = entry
	_rank_heading.visible = ranked
	_metric_headings.visible = ranked and not columns.is_empty()
	_rebuild_metric_headings(columns)
	_clear_children(_rows)
	var local_peer: int = _connection.local_peer()
	for player: Variant in players:
		if not player is Dictionary:
			continue
		var entry: Dictionary = results.get(str(player.get("player_id", "")), {})
		_rows.add_child(_build_row(player, entry, columns, ranked, local_peer))

func _rebuild_metric_headings(columns: Array) -> void:
	_clear_children(_metric_headings)
	for column: Variant in columns:
		if not column is Dictionary:
			continue
		var col_width: float = float(column.get("width", METRIC_COLUMN_WIDTH))
		var cell: HBoxContainer = HBoxContainer.new()
		cell.custom_minimum_size = Vector2(col_width, 0.0)
		cell.alignment = BoxContainer.ALIGNMENT_END
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_theme_constant_override("separation", 6)
		var icon: Variant = column.get("icon")
		if icon is Texture2D:
			var icon_rect: TextureRect = TextureRect.new()
			icon_rect.texture = icon
			icon_rect.custom_minimum_size = Vector2(18.0, 18.0)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(icon_rect)
		var label: Label = Label.new()
		label.text = str(column.get("title", column.get("key", "")))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.theme_type_variation = &"MutedLabel"
		label.add_theme_font_size_override("font_size", 20)
		cell.add_child(label)
		_metric_headings.add_child(cell)

func _build_row(player: Dictionary, entry: Dictionary, columns: Array, ranked: bool, local_peer: int) -> PanelContainer:
	var is_self: bool = int(player.get("peer_id", -1)) == local_peer
	var connected: bool = bool(player.get("connected", true))
	var appearance: Variant = player.get("appearance")
	var fallback_raw: Variant = (appearance as Dictionary).get("color") if appearance is Dictionary else null
	var raw_color: Variant = entry.get("color", fallback_raw)
	var player_color: Variant = raw_color if raw_color is Color else (Color.from_string(raw_color, COLOR_TEXT) if raw_color is String and Color.html_is_valid(raw_color) else null)
	var row_bg: Color = Color(0.11, 0.175, 0.26, 0.90) if is_self else Color(0.08, 0.125, 0.185, 0.84)
	var border_col: Color = Color(0.64, 0.84, 0.98, 0.82) if is_self else Color(0.58, 0.78, 0.94, 0.32)
	if player_color is Color:
		var pc: Color = player_color as Color
		border_col = Color(pc.r, pc.g, pc.b, 0.92 if connected else 0.42)
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_row_style(row_bg, border_col, 2))
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 20)
	panel.add_child(line)
	if ranked:
		var rank_value: int = int(entry.get("rank", 0))
		var rank_label: Label = Label.new()
		rank_label.custom_minimum_size = Vector2(68.0, 32.0)
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rank_label.add_theme_font_size_override("font_size", 22)
		rank_label.text = str(rank_value) if rank_value > 0 else "—"
		rank_label.modulate = _rank_color(rank_value) if connected else COLOR_MUTED
		line.add_child(rank_label)
	var name_label: Label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size = Vector2(280.0, 32.0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.text = str(player.get("name", ""))
	if player_color is Color:
		var tinted: Color = player_color as Color
		name_label.modulate = tinted if connected else Color(tinted.r, tinted.g, tinted.b, 0.55)
	else:
		name_label.modulate = COLOR_TEXT if connected else COLOR_MUTED
	line.add_child(name_label)
	if ranked and not columns.is_empty():
		var metrics_row: HBoxContainer = HBoxContainer.new()
		metrics_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		metrics_row.add_theme_constant_override("separation", 20)
		var metrics_data: Dictionary = entry.get("metrics", {}) if entry.get("metrics") is Dictionary else {}
		for column: Variant in columns:
			if not column is Dictionary:
				continue
			metrics_row.add_child(_build_metric_cell(column, metrics_data.get(column.get("key", "")), connected))
		line.add_child(metrics_row)
	line.add_child(_build_ping_cell(player, local_peer))
	return panel

func _build_metric_cell(column: Dictionary, raw_value: Variant, connected: bool) -> HBoxContainer:
	var col_width: float = float(column.get("width", METRIC_COLUMN_WIDTH))
	var cell: HBoxContainer = HBoxContainer.new()
	cell.custom_minimum_size = Vector2(col_width, 32.0)
	cell.alignment = BoxContainer.ALIGNMENT_END
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_constant_override("separation", 6)
	var icon: Variant = column.get("icon")
	if icon is Texture2D:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = Vector2(20.0, 20.0)
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon_rect)
	var label: Label = Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 22)
	label.text = "—" if raw_value == null else str(_format_metric.call(raw_value, str(column.get("format", "text"))))
	label.modulate = COLOR_TEXT if connected else COLOR_MUTED
	cell.add_child(label)
	return cell

func _build_ping_cell(player: Dictionary, local_peer: int) -> HBoxContainer:
	var cell: HBoxContainer = HBoxContainer.new()
	cell.custom_minimum_size = Vector2(146.0, 32.0)
	cell.alignment = BoxContainer.ALIGNMENT_END
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var peer_id: int = int(player.get("peer_id", -1))
	var connected: bool = bool(player.get("connected", true))
	var sample: Dictionary = _connection.get_peer_stats(1 if peer_id == local_peer and not _connection.host else peer_id)
	var state: String = "host" if connected and peer_id == 1 else str(sample.get("state", "offline"))
	var ping_text: String = "—"
	var ping_color: Color = COLOR_MUTED
	var pill_bg: Color = Color(0.14, 0.22, 0.32, 0.90)
	var warn_texture: Texture2D = null
	var warn_color: Color = Color.WHITE
	if state == "host":
		ping_text = "房主"
		ping_color = Color(0.96, 0.97, 0.99, 1.0)
		pill_bg = Color(0.18, 0.37, 0.56, 0.92)
		warn_texture = host_icon
		warn_color = COLOR_GOLD
	elif state in ["connected", "degraded"]:
		var rtt: float = float(sample.get("rtt_msec", 0.0))
		ping_text = "%d ms" % roundi(rtt)
		ping_color = _ping_color(rtt)
		if rtt >= ping_critical_msec:
			pill_bg = Color(0.42, 0.15, 0.18, 0.90)
		elif rtt >= ping_warn_msec or state == "degraded":
			pill_bg = Color(0.32, 0.24, 0.12, 0.90)
		var loss_ready: bool = bool(sample.get("packet_loss_ready", false))
		var loss_percent: float = float(sample.get("packet_loss_percent", 0.0))
		if loss_ready and loss_percent >= loss_warn_percent:
			warn_texture = packet_loss_icon
			warn_color = COLOR_CRITICAL if loss_percent >= loss_critical_percent else COLOR_WARN
	elif state in ["offline", "stalled"]:
		ping_text = "掉线" if state == "offline" else "无响应"
		ping_color = Color(0.98, 0.92, 0.92, 1.0)
		pill_bg = Color(0.62, 0.18, 0.22, 0.92)
		warn_texture = disconnected_icon
		warn_color = Color(0.98, 0.85, 0.85, 1.0)
	var pill: PanelContainer = PanelContainer.new()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_style: StyleBoxFlat = StyleBoxFlat.new()
	pill_style.bg_color = pill_bg
	pill_style.set_corner_radius_all(6)
	pill_style.content_margin_left = 10.0
	pill_style.content_margin_right = 10.0
	pill_style.content_margin_top = 4.0
	pill_style.content_margin_bottom = 4.0
	pill.add_theme_stylebox_override("panel", pill_style)
	var pill_row: HBoxContainer = HBoxContainer.new()
	pill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_row.add_theme_constant_override("separation", 6)
	pill.add_child(pill_row)
	if warn_texture != null:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = warn_texture
		icon_rect.custom_minimum_size = Vector2(18.0, 18.0)
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.modulate = warn_color
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill_row.add_child(icon_rect)
	var ping_label: Label = Label.new()
	ping_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ping_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ping_label.add_theme_font_size_override("font_size", 16)
	ping_label.text = ping_text
	ping_label.add_theme_color_override("font_color", ping_color)
	pill_row.add_child(ping_label)
	cell.add_child(pill)
	return cell

func _ping_color(rtt_msec: float) -> Color:
	if rtt_msec >= ping_critical_msec:
		return COLOR_CRITICAL
	if rtt_msec >= ping_warn_msec:
		return COLOR_WARN
	return COLOR_GOOD

func _rank_color(rank_value: int) -> Color:
	match rank_value:
		1: return COLOR_GOLD
		2: return COLOR_SILVER
		3: return COLOR_BRONZE
	return COLOR_TEXT

func _clear_children(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

## Keep author ranks and tie order. Team members share their author's row; omitted players follow.
func _ordered_players(rows: Array) -> Array:
	var indices: Array[int] = []
	for index: int in rows.size():
		indices.append(index)
	indices.sort_custom(func(a: int, b: int) -> bool:
		var rank_a: int = int(rows[a].get("rank", 0))
		var rank_b: int = int(rows[b].get("rank", 0))
		if rank_a == rank_b:
			return a < b
		return rank_b == 0 or (rank_a > 0 and rank_a < rank_b))
	var ordered: Array = []
	var included: Array[String] = []
	for index: int in indices:
		for id: Variant in rows[index].get("members", [rows[index].get("player_id", "")]):
			if not id is String:
				continue
			for player: Dictionary in _connection.players:
				if str(player.get("player_id", "")) == id:
					ordered.append(player)
					included.append(id)
	for player: Dictionary in _connection.players:
		var id: String = str(player.get("player_id", ""))
		if id not in included:
			ordered.append(player)
	return ordered
