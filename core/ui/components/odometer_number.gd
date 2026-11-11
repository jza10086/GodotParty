class_name PartyOdometerNumber
extends Control
## Mechanical decimal wheels: higher places turn only as the lower places carry.
@export var number_font: Font
@export var font_size: int = 88
@export var number_color: Color = Color(0.96, 0.97, 0.99, 1.0)
@export_range(0.1, 10.0) var duration_seconds: float = 1.8
@export_range(1, 12) var minimum_digits: int = 1
@export var separators: bool = true
@export var manual_clock: bool = false
var value: int = 0
var display_value: float = 0.0
var _from: float = 0.0
var _elapsed: float = 0.0
var _moving: bool = false

func _ready() -> void:
	assert(number_font != null)
	clip_contents = true
	set_process(false)

## Initialize without spinning. No leading zeroes unless minimum_digits requests them.
func reset(next: int = 0) -> void:
	value = next
	display_value = next
	_from = next
	_moving = false
	set_process(false)
	queue_redraw()

## Retarget from the current wheel position without jumping back to the previous integer.
func set_value(next: int) -> void:
	if next == value:
		return
	_from = display_value
	value = next
	_elapsed = 0.0
	_moving = true
	set_process(not manual_clock)
	queue_redraw()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not _moving:
		return
	_elapsed += delta
	var t: float = clampf(_elapsed / duration_seconds, 0.0, 1.0)
	display_value = lerpf(_from, float(value), smoothstep(0.0, 1.0, t))
	if t >= 1.0:
		display_value = value
		_moving = false
		set_process(false)
	queue_redraw()

func is_settled() -> bool:
	return not _moving

func _draw() -> void:
	var magnitude: float = absf(display_value)
	var length: int = maxi(minimum_digits, str(floori(magnitude)).length())
	var negative: bool = display_value < 0.0
	var commas: int = (length - 1) / 3 if separators else 0
	var slots: float = length + commas * 0.45 + (1.0 if negative else 0.0)
	var draw_size: int = mini(font_size, int(minf(size.y / 1.35, size.x / (slots * 0.66))))
	var width: float = number_font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size).x
	var x: float = (size.x - width * slots) * 0.5
	var baseline: float = (size.y - number_font.get_height(draw_size)) * 0.5 + number_font.get_ascent(draw_size)
	if negative:
		draw_string(number_font, Vector2(x, baseline), "−", HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, number_color)
		x += width
	for index: int in length:
		if index > 0 and separators and (length - index) % 3 == 0:
			draw_string(number_font, Vector2(x, baseline), ",", HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, number_color)
			x += width * 0.45
		var place: float = pow(10.0, length - index - 1)
		var whole: int = floori(magnitude / place)
		var carry: float = clampf(fposmod(magnitude, place) - (place - 1.0), 0.0, 1.0)
		var offset: float = carry * size.y
		for neighbor: int in range(0, 2):
			var digit: int = posmod(whole + neighbor, 10)
			draw_string(number_font, Vector2(x, baseline - offset + neighbor * size.y), str(digit), HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, number_color)
		x += width
