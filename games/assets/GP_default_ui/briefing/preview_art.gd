@tool
extends Control

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var middle: Vector2 = size * Vector2(0.5, 0.48)
	var radius: float = minf(size.x * 0.21, size.y * 0.34)
	draw_arc(middle, radius * 1.75, 0.0, TAU, 80, Color(0.6, 0.65, 0.8, 0.1), 2.0, true)
	draw_arc(middle, radius * 1.24, 0.0, TAU, 60, Color(0.6, 0.65, 0.8, 0.13), 2.0, true)
	var colors: Array[Color] = [Color("ffd18f"), Color("9fc9e8"), Color("b8a7e5"), Color("9fd5b4")]
	for index: int in range(4):
		var angle: float = -0.68 + float(index) * TAU / 4.0
		var center: Vector2 = middle + Vector2(cos(angle), sin(angle)) * radius * 0.88
		var side: float = radius * 0.54
		var corners: PackedVector2Array = []
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			corners.append(center + (corner * side).rotated(angle * 0.17))
		draw_colored_polygon(corners, colors[index])
		var eye_offset: float = side * 0.28
		draw_circle(center + Vector2(-eye_offset, -side * 0.08), side * 0.07, Color("292b36"))
		draw_circle(center + Vector2(eye_offset, -side * 0.08), side * 0.07, Color("292b36"))
		draw_line(center + Vector2(-eye_offset * 0.5, side * 0.30), center + Vector2(eye_offset * 0.5, side * 0.30), Color("292b36"), maxf(2.0, side * 0.04), true)
	var star: Vector2 = middle + Vector2(radius * 1.70, -radius * 0.80)
	draw_line(star - Vector2(10, 0), star + Vector2(10, 0), Color("ffd18f"), 3.0, true)
	draw_line(star - Vector2(0, 10), star + Vector2(0, 10), Color("ffd18f"), 3.0, true)
