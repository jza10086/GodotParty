extends Control
## Resolution-independent flat illustration for the formal frontend.
## Every motif is original vector geometry; it ignores input and owns no gameplay state.
var home_visible: bool = true:
	set(value):
		home_visible = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _shape(points: Array[Vector2], color: Color, offset: Vector2 = Vector2.ZERO) -> void:
	var vertices: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		vertices.append(point + offset)
	draw_colored_polygon(vertices, color)

func _tile(rect: Rect2, color: Color, radius: int = 24, depth: Vector2 = Vector2(8, 10)) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#bcb6cc")
	style.set_corner_radius_all(radius)
	style.corner_detail = 2
	draw_style_box(style, Rect2(rect.position + depth, rect.size))
	style.bg_color = color
	draw_style_box(style, rect)

func _diamond(center: Vector2, radius: float, color: Color) -> void:
	_shape([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)], color)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(1920, 1080))
	draw_rect(Rect2(0, 0, 1920, 1080), Color("#eeeaf2"))
	_shape([Vector2(1180, 0), Vector2(1920, 0), Vector2(1920, 620), Vector2(1510, 910), Vector2(850, 480)], Color("#e0dbea"))
	_shape([Vector2(0, 970), Vector2(1060, 830), Vector2(1920, 970), Vector2(1920, 1080), Vector2(0, 1080)], Color("#ded7e7"))
	draw_circle(Vector2(1730, 300), 92, Color("#d3deed"), true, -1, true)
	_diamond(Vector2(674, 134), 28, Color("#c9c1d8"))
	_diamond(Vector2(1818, 778), 20, Color("#c3d2e7"))

	if not home_visible:
		return
	_tile(Rect2(64, 160, 496, 742), Color("#e4dfed"), 28, Vector2(10, 12))
	# Four soft blocks replace the outlined engine icon in this appearance only.
	for index: int in range(4):
		_tile(Rect2(Vector2(438 + (index % 2) * 39, 258 + (index / 2) * 39), Vector2(30, 30)), Color("#b7cbe5") if index % 2 == 0 else Color("#c5bdd6"), 8, Vector2(3, 4))
	var font: Font = get_theme_default_font()
	draw_string(font, Vector2(760, 277), "LET'S PLAY TOGETHER", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("#77768b"))
	draw_string(font, Vector2(756, 356), "好朋友，好时光。", HORIZONTAL_ALIGNMENT_LEFT, -1, 62, Color("#45465e"))
	_tile(Rect2(760, 388, 270, 44), Color("#f1d8d3"), 14, Vector2(4, 5))
	draw_string(font, Vector2(783, 418), "ONLINE  /  PARTY", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#65576b"))
	# Offset cards and a solid, three-face die form the central party illustration.
	draw_set_transform(Vector2(910, 625) * size / Vector2(1920, 1080), -0.16, size / Vector2(1920, 1080))
	_tile(Rect2(-112, -135, 224, 294), Color("#faf4e9"), 24, Vector2(12, 14))
	_diamond(Vector2.ZERO, 60, Color("#b9cce4"))
	_diamond(Vector2(-72, -89), 15, Color("#b9cce4"))
	_diamond(Vector2(72, 110), 15, Color("#b9cce4"))
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(1920, 1080))
	_shape([Vector2(1140, 691), Vector2(1352, 592), Vector2(1547, 708), Vector2(1333, 817)], Color("#bbb4cc"), Vector2(16, 22))
	_shape([Vector2(1140, 548), Vector2(1333, 451), Vector2(1547, 565), Vector2(1352, 671)], Color("#fff9ef"))
	_shape([Vector2(1140, 548), Vector2(1352, 671), Vector2(1352, 812), Vector2(1140, 690)], Color("#b7cbe4"))
	_shape([Vector2(1352, 671), Vector2(1547, 565), Vector2(1547, 708), Vector2(1352, 812)], Color("#9998b6"))
	for point: Vector2 in [Vector2(1240, 555), Vector2(1340, 555), Vector2(1440, 570)]:
		draw_circle(point, 16, Color("#777795"), true, -1, true)
	for point: Vector2 in [Vector2(1194, 609), Vector2(1291, 716)]:
		draw_circle(point, 17, Color("#607895"), true, -1, true)
	for point: Vector2 in [Vector2(1406, 673), Vector2(1492, 628), Vector2(1406, 752), Vector2(1492, 707)]:
		draw_circle(point, 14, Color("#f0eaf4"), true, -1, true)
	# Small counters give the composition a board-game rhythm.
	_tile(Rect2(1594, 670, 108, 106), Color("#e8c8c4"), 36, Vector2(9, 12))
	draw_circle(Vector2(1648, 642), 46, Color("#f0d7cf"), true, -1, true)
	_diamond(Vector2(1070, 455), 22, Color("#d1c3d7"))
	draw_circle(Vector2(1717, 495), 14, Color("#c1cadd"), true, -1, true)
	draw_circle(Vector2(751, 765), 11, Color("#d7babc"), true, -1, true)
	draw_string(font, Vector2(1100, 875), "GODOT PARTY", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#77768b"))
