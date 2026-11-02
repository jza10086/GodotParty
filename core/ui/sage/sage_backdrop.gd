extends Control
## A quiet paper composition; the character is artwork, never an interactive avatar.
var home_visible: bool = true:
	set(value):
		home_visible = value
		if is_instance_valid(_portrait):
			_portrait.visible = value
		queue_redraw()

var _portrait: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait = TextureRect.new()
	_portrait.name = "Illustration"
	_portrait.texture = preload("res://core/ui/sage/sage_character.png")
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.anchor_left = 0.46
	_portrait.anchor_top = 0.25
	_portrait.anchor_right = 0.88
	_portrait.anchor_bottom = 0.82
	_portrait.visible = home_visible
	resized.connect(queue_redraw)

func _leaf(center: Vector2, scale_factor: float, flip: float = 1.0) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in [Vector2(-20, 12), Vector2(-20, -12), Vector2(-4, -28), Vector2(35, -33), Vector2(27, -5), Vector2(8, 13)]:
		points.append(center + Vector2(point.x * flip, point.y) * scale_factor)
	draw_colored_polygon(points, Color("#c5ceb4"))

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(1920, 1080))
	draw_rect(Rect2(0, 0, 1920, 1080), Color("#f5f3e9"))
	draw_rect(Rect2(0, 1020, 1920, 60), Color("#e8eadc"))
	if not home_visible:
		return
	var font: Font = get_theme_default_font()
	draw_circle(Vector2(1285, 600), 318, Color("#e2e6d5"), true, -1, true)
	draw_circle(Vector2(1590, 366), 64, Color("#ece4d5"), true, -1, true)
	draw_circle(Vector2(957, 767), 36, Color("#e6d0c0"), true, -1, true)
	_leaf(Vector2(1630, 715), 1.3)
	_leaf(Vector2(1682, 758), 0.8, -1.0)
	draw_string(font, Vector2(96, 167), "G O D O T   P A R T Y", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#7d8072"))
	draw_string(font, Vector2(96, 904), "把日常，留一点给快乐。", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#7d8072"))
	draw_string(font, Vector2(930, 220), "今天，也一起玩吧。", HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color("#4d5144"))
	draw_string(font, Vector2(933, 258), "A LITTLE TIME, A LITTLE JOY.", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#7d8072"))

