@tool
extends Button
## A room identity card. The protocol owns the assigned color; this component only displays it.
@export var player_color: Color = Color(0.30, 0.35, 0.42):
	set(value):
		player_color = value
		if is_node_ready(): _update_border()

func _ready() -> void:
	_update_border()

func _update_border() -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var style: StyleBoxFlat = get_theme_stylebox(state)
		style.border_color = player_color
