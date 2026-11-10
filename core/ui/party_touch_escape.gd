## Android touch uses the framework's native mouse emulation. The wake gesture is never an ESC.
extends MarginContainer

@export var android_only: bool = true
@export_range(0.5, 10.0, 0.5) var idle_hide_seconds: float = 3.0
@onready var _button: Button = %Escape
@onready var _hide_timer: Timer = %HideTimer
var _pointer_down: bool = false
var _armed: bool = false

func _ready() -> void:
	visible = not android_only or OS.has_feature("android")
	_hide_timer.timeout.connect(_hide_button)
	_hide_button()

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	# Child button ignores mouse input, so one gesture always stays with this wake area.
	accept_event()
	var over_button: bool = _button.get_rect().has_point(event.position)
	if event.pressed:
		_pointer_down = true
		_armed = _button.visible and over_button
		_hide_timer.stop()
		_button.show()
		_button.modulate.a = 0.7 if _armed else 1.0
	elif _pointer_down:
		_pointer_down = false
		var activate: bool = _armed and over_button
		_armed = false
		_button.modulate.a = 1.0
		if activate:
			_hide_button()
			_send_escape.call_deferred()
		else:
			_hide_timer.start(idle_hide_seconds)

func _hide_button() -> void:
	_button.hide()
	_button.modulate.a = 1.0
	_hide_timer.stop()
	_pointer_down = false
	_armed = false

func _notification(what: int) -> void:
	if is_node_ready() and what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_hide_button()

## Preserve the normal Escape routing, including focused controls and the current modal.
func _send_escape() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	get_viewport().push_input(event, true)
	var released: InputEventKey = event.duplicate()
	released.pressed = false
	get_viewport().push_input(released, true)
