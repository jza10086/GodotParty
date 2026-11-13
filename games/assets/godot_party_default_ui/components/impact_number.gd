class_name PartyImpactNumber
extends Control
## Reusable presentation-only integer display; each change triggers the same per-glyph impact wave.
@export var fit_to_width: bool = true
@export var font_size: int = 80
@export_range(0.5, 1.0) var glyph_width_ratio: float = 0.74
@export var number_font: Font
@export_enum("Left", "Center", "Right") var alignment: int = 1
@export var number_color: Color = Color(0.96, 0.97, 0.99, 1.0)
@export var increase_color: Color = Color("#79e5ad")
@export var decrease_color: Color = Color("#ff787c")
@export var shadow_color: Color = Color("#0a101b")
@export_range(0, 8) var outline_size: int = 2
## Signed amounts keep profit/loss colors; ordinary totals return to the neutral color.
@export var signed_value: bool = false
## A parent animation may own the clock; otherwise playback advances automatically.
@export var manual_clock: bool = false
@export_range(0.1, 1.5) var bounce_seconds: float = 0.28
@export_range(0.0, 0.1) var digit_delay: float = 0.008
var value: int = 0
var _age: float = 10.0
var _strength: float = 0.0
var _change: int = 0

func _ready() -> void:
	assert(number_font != null)
	clip_contents = true
	set_process(not manual_clock)

func _process(delta: float) -> void:
	advance(delta)

## Keyframe envelope estimated from the supplied GIF: impact, recoil, overshoot, settle.
func _impact(age: float) -> float:
	if age < 0.0 or age >= bounce_seconds:
		return 0.0
	var times: Array[float] = [0.0, 0.12, 0.28, 0.46, 0.67, 1.0]
	var amplitudes: Array[float] = [1.0, 1.12, -0.22, 0.17, -0.06, 0.0]
	var t: float = age / bounce_seconds
	for index: int in range(1, times.size()):
		if t <= times[index]:
			var fraction: float = inverse_lerp(times[index - 1], times[index], t)
			return lerpf(amplitudes[index - 1], amplitudes[index], smoothstep(0.0, 1.0, fraction))
	return 0.0


## Change the displayed value and restart the impact from its peak.
func set_value(next: int, impact_scale: float = 1.0) -> void:
	if next == value:
		return
	_change = next - value
	set_process(not manual_clock)
	_strength = clampf(0.9 + log(1.0 + absi(next - value)) * 0.025, 0.95, 1.2) * impact_scale
	value = next
	_age = 0.0
	queue_redraw()

## Set an initial value without animating a fictional gain or loss.
func reset(next: int = 0) -> void:
	value = next
	_change = 0
	_age = bounce_seconds + formatted_value().length() * digit_delay
	set_process(false)
	queue_redraw()

## Advance in seconds when manual_clock is enabled.
func advance(delta: float) -> void:
	_age += delta
	queue_redraw()
	if is_settled():
		set_process(false)

func get_value_color() -> Color:
	if signed_value:
		return increase_color if value > 0 else (decrease_color if value < 0 else number_color)
	var pulse: float = 1.0 - smoothstep(0.0, bounce_seconds + formatted_value().length() * digit_delay, _age)
	return number_color.lerp(increase_color if _change > 0 else decrease_color, pulse) if _change != 0 else number_color

func is_settled() -> bool:
	return _age >= bounce_seconds + formatted_value().length() * digit_delay

func formatted_value() -> String:
	var raw: String = str(absi(value))
	var output: String = ""
	for index: int in raw.length():
		if index > 0 and (raw.length() - index) % 3 == 0:
			output += ","
		output += raw[index]
	return ("−" if value < 0 else "") + output

func _draw() -> void:
	var text: String = formatted_value()
	var tint: Color = get_value_color()
	var font: Font = number_font
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * glyph_width_ratio
	var draw_size: int = font_size if not fit_to_width else maxi(12, mini(font_size, int(font_size * (size.x - 64.0) / maxf(1.0, text_width))))
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size).x * glyph_width_ratio
	var x: float = 24.0 if alignment == 0 else ((size.x - width) * 0.5 if alignment == 1 else size.x - width - 24.0)
	var center_y: float = size.y * 0.5
	var baseline: float = font.get_ascent(draw_size) - font.get_height(draw_size) * 0.5
	for index: int in text.length():
		var glyph: String = text[index]
		var glyph_width: float = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size).x
		var age: float = _age - index * digit_delay
		var wave: float = _impact(age)
		var strength: float = _strength * (0.25 if glyph == "," else 1.0)
		var scale_factor: Vector2 = Vector2.ONE * (1.0 + wave * strength * 0.95)
		var rotation: float = wave * strength * (0.17 if index % 2 == 0 else -0.22)
		var position: Vector2 = Vector2(x + glyph_width * glyph_width_ratio * 0.5 + wave * sin(index * 2.1 + 0.7) * 4.0, center_y - wave * strength * 8.0)
		scale_factor.x *= glyph_width_ratio
		draw_set_transform(position, rotation, scale_factor)
		var origin: Vector2 = Vector2(-glyph_width * 0.5, baseline)
		draw_string(font, origin + Vector2(draw_size * 0.045, draw_size * 0.06), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, shadow_color)
		if outline_size > 0:
			draw_string_outline(font, origin, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, outline_size, tint)
		draw_string(font, origin, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, tint)
		x += glyph_width * glyph_width_ratio
	draw_set_transform(Vector2.ZERO)

