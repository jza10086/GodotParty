extends CheckButton

@onready var slide: Control = $Slide
@onready var shader: ShaderMaterial = slide.material
var _motion: Tween
var _rest_style: StringName

func _ready() -> void:
	toggled.connect(_slide_to)

func _slide_to(enabled: bool) -> void:
	if slide.visible:
		_motion.kill()
	else:
		_rest_style = theme_type_variation
		theme_type_variation = &"SlidingSwitch"
		shader.set_shader_parameter(&"amount", float(not enabled))
		slide.show()
	shader.set_shader_parameter(&"mirrored", is_layout_rtl())
	_motion = create_tween()
	_motion.tween_property(shader, "shader_parameter/amount", float(enabled), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_callback(_finish_slide)

func _finish_slide() -> void:
	theme_type_variation = _rest_style
	slide.hide()

func set_value_silently(value: bool) -> void:
	set_pressed_no_signal(value)
	if _motion and slide.visible:
		_motion.kill()
		_finish_slide()
