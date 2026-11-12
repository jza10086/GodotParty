## Framework-local transient feedback. Replacing a notice restarts its three-second lifetime.
extends CanvasLayer

const DISPLAY_SECONDS: float = 3.0
const ENTER_SECONDS: float = 0.2
const EXIT_SECONDS: float = 0.2
var _animation: Tween
@onready var _motion: Control = %Motion
@onready var _message: Label = %Message

func _ready() -> void:
	_motion.hide()

## Never captures input or changes focus. All layout and styling live in the scene/theme.
func show_notice(message: String) -> void:
	if _animation != null:
		_animation.kill()
	_message.text = message
	_motion.modulate.a = 0.0
	_motion.position.y = -16.0
	_motion.show()
	_animation = create_tween()
	_animation.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_animation.tween_property(_motion, "modulate:a", 1.0, ENTER_SECONDS)
	_animation.parallel().tween_property(_motion, "position:y", 0.0, ENTER_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_animation.tween_interval(DISPLAY_SECONDS - ENTER_SECONDS - EXIT_SECONDS)
	_animation.tween_property(_motion, "modulate:a", 0.0, EXIT_SECONDS)
	_animation.parallel().tween_property(_motion, "position:y", -12.0, EXIT_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_animation.tween_callback(_motion.hide)
