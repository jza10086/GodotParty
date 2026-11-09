@tool
extends HBoxContainer
## One icon group followed by its description. Explicit icons describe gestures such as WASD.
const Icons = preload("res://core/ui/ambient_reveal/components/navigation/prompt_icons.gd")
const IconScene: PackedScene = preload("res://core/ui/ambient_reveal/components/navigation/prompt_icon.tscn")

@export var action: StringName = &"ui_accept":
	set(value):
		action = value
		refresh()
@export var description: String = "确认":
	set(value):
		description = value
		if is_node_ready(): %Action.text = value
@export var keyboard_icons: Array[Texture2D] = []:
	set(value):
		keyboard_icons = value
		refresh()
@export var gamepad_icons: Array[Texture2D] = []:
	set(value):
		gamepad_icons = value
		refresh()
@export var gamepad: bool = false:
	set(value):
		gamepad = value
		refresh()
@export_range(20, 96, 1) var icon_size: int = 40:
	set(value):
		icon_size = value
		refresh()

func _ready() -> void:
	refresh()

func set_gamepad(enabled: bool) -> void:
	gamepad = enabled

## Call after changing an InputMap binding while the prompt is already visible.
func refresh() -> void:
	if not is_node_ready():
		return
	%Action.text = description
	for child: Node in %Icons.get_children():
		%Icons.remove_child(child)
		child.queue_free()
	var explicit_icons: Array[Texture2D] = gamepad_icons if gamepad else keyboard_icons
	if not explicit_icons.is_empty():
		for texture: Texture2D in explicit_icons:
			_add_icon(texture)
		return
	if action == &"" or not InputMap.has_action(action):
		return
	var shown: PackedStringArray = []
	for event: InputEvent in InputMap.action_get_events(action):
		var is_pad: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
		if is_pad != gamepad:
			continue
		var textures: Array[Texture2D] = Icons.for_event(event)
		var caption: String = event.as_text()
		if textures.is_empty() or caption in shown:
			continue
		if not shown.is_empty():
			_add_separator("/")
		shown.append(caption)
		for index: int in textures.size():
			if index > 0: _add_separator("+")
			var icon: TextureRect = _add_icon(textures[index])
			icon.tooltip_text = caption

func _add_icon(texture: Texture2D) -> TextureRect:
	var icon: TextureRect = IconScene.instantiate()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(float(icon_size) * texture.get_width() / texture.get_height(), icon_size)
	%Icons.add_child(icon)
	return icon

func _add_separator(text: String) -> void:
	var separator: Label = Label.new()
	separator.text = text
	separator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Icons.add_child(separator)
