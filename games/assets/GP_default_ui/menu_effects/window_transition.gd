extends Control

@export var fullscreen_page: bool = false
@onready var content: Control = %Content
var _motion: Tween
var _amount: float = 0.0
var _opening: bool = false

func _ready() -> void:
	hide()
	_apply(0.0)

func open() -> void:
	show()
	_animate(true)

func close() -> void:
	_animate(false)

func _animate(opening: bool) -> void:
	_opening = opening
	if _motion:
		_motion.kill()
	var target: float = float(opening)
	var duration: float = 0.28 if fullscreen_page else 0.25
	_motion = create_tween()
	_motion.tween_method(_apply, _amount, target, duration * absf(target - _amount)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not opening:
		_motion.tween_callback(hide)

func _apply(amount: float) -> void:
	_amount = amount
	%Backdrop.material.set_shader_parameter(&"reveal", amount)
	content.pivot_offset = content.size * 0.5
	var progress: float = 1.0 - pow(1.0 - amount, 3.0) if _opening else pow(amount, 3.0)
	content.scale = Vector2.ONE * lerpf(1.02 if fullscreen_page else 0.96, 1.0, progress)
	%Offset.position.y = 0.0 if fullscreen_page else 8.0 * (1.0 - progress)
	content.modulate.a = amount
