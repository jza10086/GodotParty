extends HBoxContainer

## InputMap action; composite gestures such as stick movement can use explicit captions.
@export var action: StringName = &"ui_accept"
@export var description: String = "确认":
	set(next):
		description = next
		if is_node_ready():
			$Action.text = next
@export var keyboard_caption: String = ""
@export var pad_caption: String = ""
@export var pad_icon: Texture2D
@export var gamepad: bool = true

const BUTTON_NAMES: Array[String] = ["A", "B", "X", "Y", "View", "Guide", "Menu", "LS", "RS", "LB", "RB", "↑", "↓", "←", "→"]
const FACE_COLORS: Array[Color] = [Color(0.63, 0.87, 0.58), Color(1, 0.58, 0.55), Color(0.51, 0.76, 1), Color(1, 0.84, 0.42)]
const FACE = preload("res://core/ui/ambient_reveal/theme/materials/prompt_face.tres")
const SHOULDER = preload("res://core/ui/ambient_reveal/theme/materials/prompt_shoulder.tres")


func _ready() -> void:
	$Action.text = description
	set_gamepad(gamepad)


func set_gamepad(enabled: bool) -> void:
	gamepad = enabled
	var key: Label = $Key
	var caption: String = pad_caption if enabled else keyboard_caption
	var index: int = -1
	if action != &"" and InputMap.has_action(action):
		var keyboard_names: PackedStringArray = PackedStringArray()
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and index == -1:
				index = event.button_index
			elif event is InputEventKey:
				var label: String = event.as_text()
				if label not in keyboard_names:
					keyboard_names.append(label)
		if caption.is_empty():
			if enabled and index >= 0:
				caption = BUTTON_NAMES[index] if index < BUTTON_NAMES.size() else str(index)
			elif not enabled:
				caption = " / ".join(keyboard_names)
	$Symbol.texture = pad_icon
	$Symbol.visible = enabled and pad_icon != null
	key.visible = not $Symbol.visible and not caption.is_empty()
	key.text = caption
	var badge: bool = enabled and (index >= 0 or caption in ["A", "X"])
	key.custom_minimum_size = Vector2.ZERO
	key.remove_theme_stylebox_override(&"normal")
	key.remove_theme_color_override(&"font_color")
	if badge:
		var face: int = ["A", "B", "X", "Y"].find(caption)
		key.custom_minimum_size = Vector2(38, 38) if face >= 0 else Vector2(50, 32)
		key.add_theme_stylebox_override(&"normal", FACE if face >= 0 else SHOULDER)
		key.add_theme_color_override(&"font_color", FACE_COLORS[face] if face >= 0 else Color(0.84, 0.91, 0.97))
