## Full-screen post-match settlement leaderboard supporting multiple scored columns
## (for example coins, diamonds, points or elapsed time), optional icons, deltas and count-up animation.
## Pure presentation only: the caller owns scoring, rewards and transition timing.
extends Control

signal action_requested()

const LeaderboardUtils: Script = preload("res://games/assets/GP_default_ui/leaderboard/leaderboard_utils.gd")
const TweenNumberScene: PackedScene = preload("res://games/assets/GP_default_ui/components/tween_number.tscn")

const DEFAULT_COLUMN_WIDTH: float = 240.0

@export var result_row_scene: PackedScene

var _presentation: Dictionary = {}
var _columns: Array = []
var _players: Dictionary[String, Dictionary] = {}
var _seconds: float = -1.0
var _show_countdown: bool = true
var _action_text: String = ""
var _initialized: bool = false
var _row_normal_style: StyleBoxFlat
var _row_winner_style: StyleBoxFlat
var _row_self_style: StyleBoxFlat

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _metric_headings: HBoxContainer = %MetricHeadings
@onready var _rows: VBoxContainer = %Rows
@onready var _countdown: Label = %Countdown
@onready var _action_row: CenterContainer = %ActionRow
@onready var _action_button: Button = %ActionButton

func _ready() -> void:
	_initialized = true
	assert(result_row_scene != null, "Assign the settlement row scene")
	_row_normal_style = _make_row_style(Color(0.06, 0.10, 0.16, 0.42), Color(0.55, 0.76, 0.94, 0.14), 1)
	_row_winner_style = _make_row_style(Color(0.18, 0.16, 0.10, 0.48), Color(0.95, 0.82, 0.44, 0.46), 1)
	_row_self_style = _make_row_style(Color(0.11, 0.21, 0.32, 0.56), Color(0.56, 0.82, 0.98, 0.52), 1)
	_action_button.pressed.connect(func() -> void: action_requested.emit())
	if not _presentation.is_empty():
		_render()
	_sync_footer()

## Populate title, multi-metric columns and ranked player rows.
## Column items accept {key, title, format?, icon?, width?, color?, animated?}.
## Row items accept {player_id, rank, metrics, name?, members?, color?, is_self?, connected?, status?, deltas?}.
func configure(presentation: Dictionary, players: Array = []) -> void:
	_presentation = presentation.duplicate(true)
	var raw_columns: Variant = _presentation.get("columns", [{"key": "score", "title": "本轮分数", "format": "integer"}])
	_columns = raw_columns if raw_columns is Array else []
	_players = LeaderboardUtils.index_players(players)
	if _initialized:
		_render()
		_sync_footer()

## Update the optional countdown text controlled by the owning gate or controller.
func set_countdown(seconds: float) -> void:
	_show_countdown = true
	_seconds = seconds if is_finite(seconds) else -1.0
	if _initialized:
		_sync_footer()

## Hide the countdown footer when the view is controlled by an action button instead.
func hide_countdown() -> void:
	_show_countdown = false
	if _initialized:
		_sync_footer()

## Show or hide an optional footer action button (e.g. "返回大厅" on final standings).
func set_action_button(label: String) -> void:
	_action_text = label
	if _initialized:
		_sync_footer()
		if not _action_text.is_empty() and is_visible_in_tree():
			_action_button.grab_focus()

func _sync_footer() -> void:
	_countdown.visible = _show_countdown
	if _show_countdown:
		_countdown.text = "等待其他玩家" if _seconds < 0.0 else "%d 秒后继续" % ceili(_seconds)
	var show_action: bool = not _action_text.is_empty()
	_action_row.visible = show_action
	if show_action:
		_action_button.text = _action_text

func _make_row_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(16)
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style

func _render() -> void:
	_title.text = str(_presentation.get("title", "本轮结算")).trim_prefix("GodotPartyDefault · ")
	_title.tooltip_text = _title.text
	var subtitle_text: String = str(_presentation.get("subtitle", ""))
	_subtitle.text = subtitle_text
	_subtitle.visible = not subtitle_text.is_empty()
	_rebuild_headings()
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var ordered: Array[Dictionary] = LeaderboardUtils.sort_rows(_presentation.get("rows", []))
	for row: Dictionary in ordered:
		_add_row(row)

func _rebuild_headings() -> void:
	for child: Node in _metric_headings.get_children():
		_metric_headings.remove_child(child)
		child.queue_free()
	for index: int in _columns.size():
		var column: Variant = _columns[index]
		if not column is Dictionary:
			continue
		var col_width: float = float(column.get("width", DEFAULT_COLUMN_WIDTH))
		var cell: HBoxContainer = HBoxContainer.new()
		cell.name = "MetricHeading%d" % index
		cell.custom_minimum_size = Vector2(col_width, 0.0)
		cell.alignment = BoxContainer.ALIGNMENT_END
		cell.add_theme_constant_override("separation", 8)
		var icon: Variant = column.get("icon")
		if icon is Texture2D:
			var icon_rect: TextureRect = TextureRect.new()
			icon_rect.texture = icon
			icon_rect.custom_minimum_size = Vector2(24.0, 24.0)
			icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(icon_rect)
		var label: Label = Label.new()
		label.text = str(column.get("title", column.get("key", "")))
		label.tooltip_text = label.text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.theme_type_variation = &"MutedLabel"
		label.add_theme_font_size_override("font_size", 22)
		cell.add_child(label)
		_metric_headings.add_child(cell)

func _add_row(row: Dictionary) -> void:
	var panel: PanelContainer = result_row_scene.instantiate() as PanelContainer
	assert(panel != null, "Settlement row scene root must be a PanelContainer")
	panel.name = "Row" + str(_rows.get_child_count() + 1)
	var player_id: String = str(row.get("player_id", ""))
	panel.set_meta(&"player_id", player_id)
	_rows.add_child(panel)
	var player_info: Dictionary = _players.get(player_id, {})
	var rank_value: int = LeaderboardUtils.parse_rank(row)
	var connected: bool = bool(row.get("connected", player_info.get("connected", true)))
	var is_self: bool = bool(row.get("is_self", player_info.get("is_local", false)))
	if is_self:
		panel.add_theme_stylebox_override("panel", _row_self_style)
	elif rank_value == 1:
		panel.add_theme_stylebox_override("panel", _row_winner_style)
	else:
		panel.add_theme_stylebox_override("panel", _row_normal_style)
	var rank_label: Label = panel.get_node("Line/Rank") as Label
	rank_label.text = LeaderboardUtils.rank_text(rank_value)
	rank_label.modulate = LeaderboardUtils.rank_color(rank_value) if connected else LeaderboardUtils.COLOR_MUTED
	var name_label: Label = panel.get_node("Line/PlayerBox/PlayerName") as Label
	var display_name: String = LeaderboardUtils.resolve_name(row, _players)
	name_label.text = display_name
	name_label.tooltip_text = display_name
	var player_color: Variant = LeaderboardUtils.parse_color(row.get("color"))
	if player_color is Color:
		var tinted: Color = player_color
		name_label.modulate = tinted if connected else Color(tinted.r, tinted.g, tinted.b, 0.45)
	else:
		name_label.modulate = LeaderboardUtils.COLOR_TEXT if connected else LeaderboardUtils.COLOR_MUTED
	var status_label: Label = panel.get_node("Line/PlayerBox/Status") as Label
	var status_text: String = str(row.get("status", ""))
	status_label.text = status_text
	status_label.visible = not status_text.is_empty()
	var metrics_container: HBoxContainer = panel.get_node("Line/Metrics") as HBoxContainer
	var metrics_map: Dictionary = row.get("metrics", {}) if row.get("metrics") is Dictionary else {}
	var deltas_map: Dictionary = row.get("deltas", {}) if row.get("deltas") is Dictionary else {}
	for index: int in _columns.size():
		var column: Variant = _columns[index]
		if not column is Dictionary:
			continue
		var key: String = str(column.get("key", ""))
		var cell: HBoxContainer = _build_metric_cell(column, metrics_map.get(key), deltas_map.get(key), connected, rank_value == 1)
		cell.name = "Metric%d" % index
		metrics_container.add_child(cell)

func _build_metric_cell(column: Dictionary, raw_value: Variant, raw_delta: Variant, connected: bool, is_winner: bool) -> HBoxContainer:
	var col_width: float = float(column.get("width", DEFAULT_COLUMN_WIDTH))
	var format: String = str(column.get("format", "integer"))
	var cell: HBoxContainer = HBoxContainer.new()
	cell.custom_minimum_size = Vector2(col_width, 40.0)
	cell.alignment = BoxContainer.ALIGNMENT_END
	cell.add_theme_constant_override("separation", 10)
	var icon: Variant = column.get("icon")
	if icon is Texture2D:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = Vector2(26.0, 26.0)
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon_rect)
	var value_color: Color = LeaderboardUtils.COLOR_MUTED
	if connected:
		var custom_color: Variant = column.get("color")
		value_color = custom_color if custom_color is Color else (LeaderboardUtils.COLOR_GOLD if is_winner else LeaderboardUtils.COLOR_TEXT)
	var use_tween: bool = bool(column.get("animated", false)) and format == "integer" and (raw_value is int or raw_value is float)
	if use_tween:
		var target_value: int = int(raw_value)
		var start_value: int = target_value - int(raw_delta) if (raw_delta is int or raw_delta is float) else 0
		var tween_num: PartyTweenNumber = TweenNumberScene.instantiate() as PartyTweenNumber
		tween_num.custom_minimum_size = Vector2(124.0, 40.0)
		tween_num.font_size = 32
		tween_num.alignment = 2
		tween_num.duration_seconds = 1.0
		tween_num.number_color = value_color
		cell.add_child(tween_num)
		tween_num.reset(start_value)
		tween_num.set_value(target_value)
	else:
		var value_label: Label = Label.new()
		value_label.text = LeaderboardUtils.format_metric(raw_value, format)
		value_label.tooltip_text = value_label.text
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 32)
		value_label.modulate = value_color
		cell.add_child(value_label)
	var delta_text: String = LeaderboardUtils.format_delta(raw_delta, format)
	if not delta_text.is_empty():
		var delta_label: Label = Label.new()
		delta_label.text = delta_text
		delta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		delta_label.add_theme_font_size_override("font_size", 21)
		delta_label.modulate = LeaderboardUtils.COLOR_POSITIVE if float(raw_delta) > 0.0 else LeaderboardUtils.COLOR_NEGATIVE
		cell.add_child(delta_label)
	return cell
