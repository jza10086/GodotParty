## Keyboard/mouse capture for settings drafts; no configuration changes until Apply.
extends Button
signal binding_changed(value: Dictionary)
var binding: Dictionary = {}
var capturing: bool = false
var allow_combinations: bool = true
var _modifier_candidate: Dictionary = {}

func configure(value: Dictionary) -> void:
	binding = value.duplicate()
	text = label_for(binding)

func _ready() -> void:
	pressed.connect(func() -> void:
		capturing = true
		text = "请按键 · Esc 取消")
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			cancel())

func cancel() -> void:
	capturing = false
	_modifier_candidate = {}
	text = label_for(binding)

func _input(event: InputEvent) -> void:
	if not capturing or not is_visible_in_tree() or event.is_echo():
		return
	if event is InputEventKey:
		if not event.pressed:
			if not _modifier_candidate.is_empty() and event.keycode == _modifier_candidate.code:
				binding = _modifier_candidate.duplicate()
				cancel()
				get_viewport().set_input_as_handled()
				binding_changed.emit(binding.duplicate())
			return
		if event.keycode == KEY_ESCAPE:
			cancel()
			get_viewport().set_input_as_handled()
			return
		if event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			_modifier_candidate = {"kind": "key", "physical": false, "code": event.keycode}
			return
		if not allow_combinations and (event.ctrl_pressed or event.alt_pressed or event.shift_pressed or event.meta_pressed):
			return
		binding = {"kind": "key", "physical": true, "code": event.physical_keycode if event.physical_keycode != 0 else event.keycode}
		if allow_combinations:
			binding.merge({"ctrl": event.ctrl_pressed, "alt": event.alt_pressed, "shift": event.shift_pressed, "meta": event.meta_pressed})
	else:
		return
	cancel()
	get_viewport().set_input_as_handled()
	binding_changed.emit(binding.duplicate())

static func label_for(value: Dictionary) -> String:
	if value.is_empty():
		return "未绑定"
	if value.get("kind") == "mouse":
		return {1: "鼠标左键", 2: "鼠标右键", 3: "鼠标中键", 4: "滚轮向上", 5: "滚轮向下"}.get(value["code"], "鼠标 " + str(value["code"]))
	var parts: PackedStringArray = []
	for modifier: String in ["ctrl", "alt", "shift", "meta"]:
		if value.get(modifier, false):
			parts.append(modifier.capitalize())
	parts.append(OS.get_keycode_string(value["code"]))
	return " + ".join(parts)
