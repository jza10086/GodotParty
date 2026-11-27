@tool
extends Button
## A room identity card. The protocol owns the assigned color; this component displays
## the 2px player-color border, tinted player name, and flat status/latency pills.

const READY_BG: Color = Color(0.14, 0.58, 0.35, 0.94)
const HOST_BG: Color = Color(0.18, 0.37, 0.56, 0.92)
const WAIT_BG: Color = Color(0.14, 0.20, 0.28, 0.78)
const DANGER_BG: Color = Color(0.68, 0.20, 0.24, 0.92)
const BRIGHT_TEXT: Color = Color(0.96, 0.97, 0.99, 1.0)
const MUTED_TEXT: Color = Color(0.66, 0.74, 0.83, 1.0)
const EMPTY_TEXT: Color = Color(0.56, 0.62, 0.70, 0.75)

@export var player_color: Color = Color(0.58, 0.78, 0.94, 0.35):
	set(value):
		player_color = value
		if is_node_ready():
			_update_visuals()

var _occupied: bool = false


func _ready() -> void:
	_update_visuals()


func set_occupied(occupied: bool) -> void:
	_occupied = occupied
	disabled = not occupied
	modulate.a = 1.0 if occupied else 0.55
	if is_node_ready():
		_update_visuals()


func set_badges(status_text: String, status_kind: String, latency_text: String = "", latency_color: Color = Color(0.5843, 0.7804, 0.9255, 1.0)) -> void:
	if not is_node_ready():
		return
	var status_badge: PanelContainer = %StatusBadge
	var status_label: Label = %PlayerStatus
	var latency_badge: PanelContainer = %LatencyBadge
	var latency_label: Label = %LatencyLabel

	status_badge.visible = not status_text.is_empty()
	status_label.text = status_text
	var st_style: StyleBoxFlat = status_badge.get_theme_stylebox(&"panel") as StyleBoxFlat
	if st_style != null:
		match status_kind:
			"ready":
				st_style.bg_color = READY_BG
				status_label.add_theme_color_override(&"font_color", BRIGHT_TEXT)
			"host":
				st_style.bg_color = HOST_BG
				status_label.add_theme_color_override(&"font_color", BRIGHT_TEXT)
			"danger":
				st_style.bg_color = DANGER_BG
				status_label.add_theme_color_override(&"font_color", BRIGHT_TEXT)
			_:
				st_style.bg_color = WAIT_BG
				status_label.add_theme_color_override(&"font_color", MUTED_TEXT)

	latency_badge.visible = not latency_text.is_empty()
	latency_label.text = latency_text
	latency_label.add_theme_color_override(&"font_color", latency_color)


func _update_visuals() -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var style: StyleBoxFlat = get_theme_stylebox(state) as StyleBoxFlat
		if style != null:
			style.border_color = player_color
	var name_label: Label = %PlayerName
	if _occupied:
		name_label.add_theme_color_override(&"font_color", player_color)
	else:
		name_label.add_theme_color_override(&"font_color", EMPTY_TEXT)
