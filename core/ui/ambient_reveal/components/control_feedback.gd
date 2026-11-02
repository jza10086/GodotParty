extends Panel

const DURATION: float = 0.24

@onready var control: Control = get_parent()
static var _last_pointer: bool = true
var _pointer: bool
var _enabled: bool
var _reveal_tween: Tween
var _press_tween: Tween
var _hovered: bool = false


func _ready() -> void:
	add_to_group(&"ambient_feedback")
	_pointer = _last_pointer
	_enabled = _accepts_input()
	control.draw.connect(_check_enabled)
	visibility_changed.connect(_on_visibility_changed)
	control.focus_entered.connect(_update_frame)
	control.focus_exited.connect(_update_frame)
	if control is Button or control is Slider:
		control.mouse_entered.connect(_hover.bind(true))
		control.mouse_exited.connect(_hover.bind(false))
	var audio: Node = get_tree().get_first_node_in_group(&"ambient_menu_audio")
	if audio != null:
		if control is Button and not control.is_in_group(&"settings_category"):
			control.pressed.connect(audio.click)
		elif control is Slider:
			control.drag_ended.connect(func(changed: bool) -> void:
				if changed: audio.click())
	if control is Button:
		# Framed buttons draw their own native state. Only transparent buttons need the reveal layer.
		visible = control.get_theme_stylebox(&"normal") != get_theme_stylebox(&"panel", &"FrameAvailable")
		control.button_down.connect(_hover.bind(true, true))
		control.button_up.connect(func() -> void: _hover(control.is_hovered()))
	_update_frame()


func _input(event: InputEvent) -> void:
	# Standalone controls also support switching between pointer and focus navigation.
	if not is_visible_in_tree():
		return
	if (event is InputEventMouseMotion and not event.relative.is_zero_approx()) or (event is InputEventMouseButton and event.pressed):
		set_pointer_mode(true)
	elif event is InputEventKey or event is InputEventJoypadButton:
		set_pointer_mode(false)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		set_pointer_mode(false)


func set_pointer_mode(pointer: bool) -> void:
	_last_pointer = pointer
	if _pointer != pointer:
		_pointer = pointer
		refresh()


func refresh() -> void:
	_hovered = get_viewport().gui_get_hovered_control() == control
	_update_frame()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		set_pointer_mode(_last_pointer)

func _accepts_input() -> bool:
	if control is Button:
		return not control.disabled
	return control.editable

func _check_enabled() -> void:
	var enabled: bool = _accepts_input()
	if enabled != _enabled:
		_enabled = enabled
		refresh()

func _update_frame() -> void:
	if not visible:
		return
	var focus_active: bool = control.has_focus() and (control is Slider or not _pointer)
	var highlight: bool = _enabled and (focus_active or (_pointer and _hovered))
	if control is Slider:
		theme_type_variation = &"FrameDisabled" if not _enabled else (&"FrameFocused" if highlight else &"FrameAvailable")
		return
	if _reveal_tween:
		_reveal_tween.kill()
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(self, "self_modulate:a", float(highlight), DURATION).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _hover(over: bool, pressing: bool = false) -> void:
	_hovered = over
	_update_frame()
	if control is Button:
		if _press_tween:
			_press_tween.kill()
		control.pivot_offset = control.size * 0.5
		var target: Vector2 = Vector2.ONE * 0.985 if _enabled and pressing else Vector2.ONE
		_press_tween = create_tween()
		_press_tween.tween_property(control, "scale", target, DURATION).set_custom_interpolator(_button_ease)


func _button_ease(progress: float) -> float:
	# Existing button curve: cubic-bezier(0.16, 1, 0.3, 1).
	var low: float = 0.0
	var high: float = 1.0
	for iteration: int in 12:
		var t: float = (low + high) * 0.5
		var x: float = 3.0 * (1.0 - t) * (1.0 - t) * t * 0.16 + 3.0 * (1.0 - t) * t * t * 0.3 + t * t * t
		if x < progress:
			low = t
		else:
			high = t
	return 1.0 - pow(1.0 - (low + high) * 0.5, 3.0)
