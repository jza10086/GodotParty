## Minimal in-game live leaderboard overlay showing only rank, player name and score.
## Dynamically sizes its row count to match active players (up to 12) and never captures input.
class_name PartyMiniLeaderboard
extends PanelContainer

const LeaderboardUtils: Script = preload("res://games/assets/GP_default_ui/leaderboard/leaderboard_utils.gd")
const MAX_SUPPORTED_ROWS: int = 12

@export var row_scene: PackedScene
@export_range(1, 12) var max_rows: int = MAX_SUPPORTED_ROWS
@export_enum("integer", "decimal", "time", "text") var score_format: String = "integer"

var _entries: Array[Dictionary] = []
var _has_data: bool = false
var _initialized: bool = false
var _row_normal_style: StyleBoxFlat
var _row_self_style: StyleBoxFlat

@onready var _rows: VBoxContainer = %Rows

func _ready() -> void:
	_initialized = true
	assert(row_scene != null, "Assign the mini leaderboard row scene")
	_row_normal_style = _make_row_style(Color(1.0, 1.0, 1.0, 0.0))
	_row_self_style = _make_row_style(Color(0.32, 0.56, 0.76, 0.3))
	if _has_data:
		_render()
	else:
		_clear_rows()
		hide()

## Set live entries directly. Each entry uses {rank, name, score, color?, is_self?, connected?}.
func set_entries(entries: Array) -> void:
	_has_data = true
	_entries.clear()
	for entry: Variant in entries:
		if entry is Dictionary:
			_entries.append(entry.duplicate(true))
	if _initialized:
		_render()

## Populate from the shared standings presentation contract (uses the first metric column).
func set_presentation(presentation: Dictionary, players: Array = []) -> void:
	var lookup: Dictionary[String, Dictionary] = LeaderboardUtils.index_players(players)
	var columns: Variant = presentation.get("columns", [])
	var metric_key: String = "score"
	var metric_format: String = score_format
	if columns is Array and not columns.is_empty() and columns[0] is Dictionary:
		metric_key = str(columns[0].get("key", "score"))
		metric_format = str(columns[0].get("format", score_format))
	score_format = metric_format
	var normalized: Array[Dictionary] = []
	for row: Dictionary in LeaderboardUtils.sort_rows(presentation.get("rows", [])):
		var player_id: String = str(row.get("player_id", ""))
		var player_info: Dictionary = lookup.get(player_id, {})
		var metrics: Dictionary = row.get("metrics", {}) if row.get("metrics") is Dictionary else {}
		normalized.append({
			"rank": LeaderboardUtils.parse_rank(row),
			"name": LeaderboardUtils.resolve_name(row, lookup),
			"score": metrics.get(metric_key),
			"color": row.get("color"),
			"is_self": bool(row.get("is_self", player_info.get("is_local", false))),
			"connected": bool(row.get("connected", player_info.get("connected", true))),
		})
	set_entries(normalized)

## Clear all rows and hide the overlay.
func clear_entries() -> void:
	_has_data = true
	_entries.clear()
	if _initialized:
		_render()

func _make_row_style(bg: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style

func _clear_rows() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

func _render() -> void:
	_clear_rows()
	var ordered: Array[Dictionary] = LeaderboardUtils.sort_rows(_entries)
	var limit: int = clampi(max_rows, 1, MAX_SUPPORTED_ROWS)
	var count: int = mini(ordered.size(), limit)
	visible = count > 0
	if count == 0:
		return
	for index: int in count:
		var entry: Dictionary = ordered[index]
		var panel: PanelContainer = row_scene.instantiate() as PanelContainer
		assert(panel != null, "Mini leaderboard row scene root must be a PanelContainer")
		panel.name = "Row%d" % (index + 1)
		var is_self: bool = bool(entry.get("is_self", false))
		var connected: bool = bool(entry.get("connected", true))
		panel.add_theme_stylebox_override("panel", _row_self_style if is_self else _row_normal_style)
		var rank_value: int = LeaderboardUtils.parse_rank(entry)
		var rank_label: Label = panel.get_node("Line/Rank") as Label
		rank_label.text = LeaderboardUtils.rank_text(rank_value)
		rank_label.modulate = LeaderboardUtils.rank_color(rank_value) if connected else LeaderboardUtils.COLOR_MUTED
		var name_label: Label = panel.get_node("Line/PlayerName") as Label
		name_label.text = str(entry.get("name", "—"))
		var player_color: Variant = LeaderboardUtils.parse_color(entry.get("color"))
		if player_color is Color:
			var tinted: Color = player_color
			name_label.modulate = tinted if connected else Color(tinted.r, tinted.g, tinted.b, 0.45)
		else:
			name_label.modulate = LeaderboardUtils.COLOR_TEXT if connected else LeaderboardUtils.COLOR_MUTED
		var score_label: Label = panel.get_node("Line/Score") as Label
		var raw_score: Variant = entry.get("score")
		score_label.text = raw_score if raw_score is String else LeaderboardUtils.format_metric(raw_score, score_format)
		score_label.modulate = (LeaderboardUtils.COLOR_GOLD if rank_value == 1 else LeaderboardUtils.COLOR_TEXT) if connected else LeaderboardUtils.COLOR_MUTED
		_rows.add_child(panel)
	reset_size()
