extends RefCounted
## Shared input boundary for single-participant games. Preview reads authored defaults
## without installing actions or saving preferences; formal input belongs to PartyInput.
var context: PartyInput
var enabled: bool = true
var _bindings: Dictionary[StringName, Array] = {}

func _init(schema: Dictionary) -> void:
	for field: Dictionary in schema.fields.values():
		if field.get("control") == "binding" and not field.get("readonly", false):
			_bindings[StringName(field.action)] = field.default

func bind(input: PartyInput) -> void:
	context = input
	enabled = false

func allowed() -> bool:
	return enabled and (context == null or (not context.input_blocked and not context.spectator))

func is_pressed(action: StringName) -> bool:
	if not allowed():
		return false
	if context != null:
		return context.is_pressed(action)
	for binding: Dictionary in _bindings[action]:
		if binding.kind == "mouse":
			if Input.is_mouse_button_pressed(binding.code):
				return true
		elif Input.is_physical_key_pressed(binding.code) if binding.physical else Input.is_key_pressed(binding.code):
			return true
	return false

func matches(event: InputEvent, action: StringName) -> bool:
	if not allowed() or event.is_echo():
		return false
	if context != null:
		return context.event_matches(event, action)
	for binding: Dictionary in _bindings[action]:
		if binding.kind == "mouse":
			if event is InputEventMouseButton and event.pressed and event.button_index == binding.code:
				return true
		elif event is InputEventKey and event.pressed and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
			var code: int = event.physical_keycode if binding.physical and event.physical_keycode != 0 else event.keycode
			if code == binding.code:
				return true
	return false

func get_axis(negative: StringName, positive: StringName) -> float:
	return float(is_pressed(positive)) - float(is_pressed(negative))

func get_vector(left: StringName, right: StringName, up: StringName, down: StringName) -> Vector2:
	return Vector2(get_axis(left, right), get_axis(up, down)).normalized()
