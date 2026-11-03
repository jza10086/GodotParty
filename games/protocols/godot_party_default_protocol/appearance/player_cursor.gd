@tool
extends Node2D
## One white vector cursor, tinted per instance. The tip at (0, 0) is the hotspot.
const OUTLINE: Array[Vector2] = [
	Vector2(0, 0), Vector2(0, 30), Vector2(8, 23), Vector2(14, 36),
	Vector2(21, 33), Vector2(14, 20), Vector2(25, 20), Vector2(0, 0)
]

@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()

## Changes only this cursor; all protocol colors share the same white base shape.
func apply_color(value: Color) -> void:
	color = value

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array(OUTLINE), color)
	draw_polyline(PackedVector2Array(OUTLINE), Color.WHITE, 4.0, true)
	draw_polyline(PackedVector2Array(OUTLINE), Color("#141820"), 2.0, true)
