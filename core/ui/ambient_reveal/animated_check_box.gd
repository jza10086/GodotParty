extends CheckBox

const MARK_COLOR: Color = Color("#95c7ec")
const DURATION: float = 0.18

var _transition: Tween
var _progress: float = 0.0:
	set(value):
		_progress = value
		queue_redraw()


func _ready() -> void:
	# The native icon keeps the outline and reserves space beside the label.
	for prefix: String in ["", "radio_"]:
		for suffix: String in ["", "_disabled"]:
			var outline: Texture2D = get_theme_icon(prefix + "unchecked" + suffix)
			add_theme_icon_override(prefix + "checked" + suffix, outline)
	_progress = float(button_pressed)
	toggled.connect(_animate_mark)


func _animate_mark(selected: bool) -> void:
	if _transition:
		_transition.kill()
	_transition = create_tween()
	_transition.tween_property(self, "_progress", float(selected), DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _draw() -> void:
	if _progress <= 0.0:
		return
	var style: StyleBox = get_theme_stylebox(&"normal")
	var x: float = style.get_margin(SIDE_LEFT) + 16.0
	if is_layout_rtl():
		x = size.x - style.get_margin(SIDE_RIGHT) - 16.0
	var center: Vector2 = Vector2(x, floorf(size.y * 0.5) + get_theme_constant(&"check_v_offset"))
	var color: Color = Color(MARK_COLOR, _progress)
	if button_group != null:
		draw_circle(center, 4.0 * _progress, color, true, -1.0, true)
	else:
		var start: Vector2 = center + Vector2(-6, 0)
		var bend: Vector2 = center + Vector2(-2, 4)
		var end: Vector2 = center + Vector2(6, -4)
		var distance: float = _progress * 3.0
		draw_line(start, start.lerp(bend, minf(distance, 1.0)), color, 2.0, true)
		if distance > 1.0:
			draw_line(bend, bend.lerp(end, (distance - 1.0) * 0.5), color, 2.0, true)
