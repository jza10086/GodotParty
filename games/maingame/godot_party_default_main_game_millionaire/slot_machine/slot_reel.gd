@tool
extends Control
## Draws one continuous five-symbol reel; the machine owns its animation and result.

const SYMBOL_COUNT: int = 5
const SYMBOL_NAMES: PackedStringArray = ["樱桃", "柠檬", "铃铛", "钻石", "幸运七"]

@export_range(0.0, 1000.0) var reel_position: float = 0.0:
	set(value):
		reel_position = value
		queue_redraw()
@export var symbol_font: Font

func _ready() -> void:
	assert(symbol_font != null, "Slot reel requires a symbol font.")
	clip_contents = true
	resized.connect(queue_redraw)

func _draw() -> void:
	var cell_height: float = size.y * 0.64
	var base_index: int = int(floor(reel_position))
	var fraction: float = reel_position - floor(reel_position)
	for row: int in range(-2, 3):
		var symbol: int = posmod(base_index + row, SYMBOL_COUNT)
		var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.5 + (float(row) - fraction) * cell_height)
		draw_set_transform(center, 0.0, Vector2.ONE * minf(size.x / 240.0, cell_height / 240.0))
		_draw_symbol(symbol)
	draw_set_transform(Vector2.ZERO)

func _draw_symbol(symbol: int) -> void:
	match symbol:
		0:
			draw_polyline(PackedVector2Array([Vector2(-35, 10), Vector2(-15, -58), Vector2(19, -66), Vector2(37, 22)]), Color("#3e7556"), 9.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(-12, -56), Vector2(-47, -77), Vector2(-53, -58), Vector2(-19, -47)]), Color("#66a66a"))
			draw_circle(Vector2(-37, 24), 36.0, Color("#a93248"), true, -1.0, true)
			draw_circle(Vector2(38, 39), 36.0, Color("#d95359"), true, -1.0, true)
			draw_circle(Vector2(-47, 12), 9.0, Color("#ffb2a3"), true, -1.0, true)
			draw_circle(Vector2(28, 26), 9.0, Color("#ffd0b6"), true, -1.0, true)
		1:
			draw_colored_polygon(PackedVector2Array([Vector2(-75, 15), Vector2(-52, -35), Vector2(-5, -52), Vector2(48, -25), Vector2(75, -15), Vector2(54, 32), Vector2(5, 52), Vector2(-45, 32)]), Color("#edbd48"))
			draw_arc(Vector2.ZERO, 42.0, 3.3, 4.9, 16, Color("#fff0aa"), 8.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(42, -35), Vector2(49, -75), Vector2(74, -72), Vector2(67, -42)]), Color("#5c9672"))
		2:
			draw_circle(Vector2(0, -60), 12.0, Color("#c78b32"), true, -1.0, true)
			draw_circle(Vector2(0, 55), 15.0, Color("#aa6c2b"), true, -1.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(-62, 45), Vector2(-44, 18), Vector2(-39, -29), Vector2(-23, -49), Vector2(23, -49), Vector2(39, -29), Vector2(44, 18), Vector2(62, 45)]), Color("#e8ac3d"))
			draw_line(Vector2(-55, 44), Vector2(55, 44), Color("#ffe6a0"), 9.0, true)
			draw_line(Vector2(-23, -24), Vector2(-28, 16), Color("#ffe6a0"), 9.0, true)
		3:
			draw_colored_polygon(PackedVector2Array([Vector2(-73, -23), Vector2(-39, -57), Vector2(39, -57), Vector2(73, -23), Vector2(0, 66)]), Color("#398caa"))
			draw_colored_polygon(PackedVector2Array([Vector2(-73, -23), Vector2(0, -23), Vector2(-39, -57)]), Color("#9ce4e7"))
			draw_colored_polygon(PackedVector2Array([Vector2(-39, -57), Vector2(39, -57), Vector2(0, -23)]), Color("#c4f2ed"))
			draw_colored_polygon(PackedVector2Array([Vector2(0, -23), Vector2(73, -23), Vector2(39, -57)]), Color("#6cc5d4"))
			draw_colored_polygon(PackedVector2Array([Vector2(-73, -23), Vector2(0, -23), Vector2(0, 66)]), Color("#68c7d6"))
		4:
			draw_string(symbol_font, Vector2(-45, 60), "7", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 155, Color("#c44e4d"))
			draw_line(Vector2(-38, 8), Vector2(31, 8), Color("#f4c574"), 7.0, true)
