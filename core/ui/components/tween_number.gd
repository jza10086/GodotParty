class_name PartyTweenNumber
extends Control
## Integer interpolation with a deadline or frame-rate-independent exponential pursuit.
enum Mode { FIXED_DURATION, SMOOTH_FOLLOW }
@export var mode: Mode = Mode.FIXED_DURATION
@export_range(0.1, 30.0) var follow_speed: float = 5.0
@export var number_font: Font
@export var fit_to_width: bool = true
@export var font_size: int = 88
@export var number_color: Color = Color(0.96, 0.97, 0.99, 1.0)
@export_range(0.1, 10.0) var duration_seconds: float = 1.8
@export var separators: bool = true
@export_enum("Left", "Center", "Right") var alignment: int = 1
@export var horizontal_padding: float = 0.0
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

## Set the initial number without animation.
func reset(next: int = 0) -> void:
	value = next
	display_value = next
	_from = next
	_moving = false
	set_process(false)
	queue_redraw()

## New targets continue from the current value; fixed mode starts a fresh duration.
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
	if mode == Mode.FIXED_DURATION:
		display_value = lerpf(_from, float(value), smoothstep(0.0, 1.0, t))
	else:
		display_value = lerpf(display_value, float(value), 1.0 - exp(-follow_speed * delta))
	if (mode == Mode.FIXED_DURATION and t >= 1.0) or (mode == Mode.SMOOTH_FOLLOW and absf(value - display_value) < 0.01):
		display_value = value
		_moving = false
		set_process(false)
	queue_redraw()

func is_settled() -> bool:
	return not _moving

func formatted_value() -> String:
	var current: int = roundi(display_value)
	var raw: String = str(absi(current))
	var result: String = ""
	for index: int in raw.length():
		if separators and index > 0 and (raw.length() - index) % 3 == 0:
			result += ","
		result += raw[index]
	return ("−" if current < 0 else "") + result

func _draw() -> void:
	var text: String = formatted_value()
	var width: float = number_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var draw_size: int = font_size if not fit_to_width else maxi(1, mini(font_size, int(minf(size.y / 1.35, font_size * size.x / maxf(1.0, width)))))
	var baseline: float = (size.y - number_font.get_height(draw_size)) * 0.5 + number_font.get_ascent(draw_size)
	draw_string(number_font, Vector2(horizontal_padding, baseline), text, alignment, maxf(1.0, size.x - horizontal_padding * 2.0), draw_size, number_color)

