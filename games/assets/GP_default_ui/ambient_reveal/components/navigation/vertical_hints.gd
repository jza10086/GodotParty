@tool
extends MarginContainer
## Bottom-corner hint stack. Edit or duplicate the ActionPrompt children in the scene.
const Prompt = preload("res://core/ui/ambient_reveal/components/navigation/action_prompt.gd")
const BAR_PAD_X: float = 18.0
const BAR_PAD_Y: float = 10.0

@export_enum("Left", "Right") var side: int = 0:
	set(value):
		side = value
		_update_rows()
@export var gamepad: bool = false:
	set(value):
		gamepad = value
		_update_rows()
@export var follow_input_device: bool = true


func _ready() -> void:
	%Prompts.item_rect_changed.connect(queue_redraw)
	%Prompts.resized.connect(queue_redraw)
	resized.connect(queue_redraw)
	_update_rows()


func set_gamepad(enabled: bool) -> void:
	gamepad = enabled


func _update_rows() -> void:
	if not is_node_ready():
		return
	%Prompts.size_flags_horizontal = Control.SIZE_SHRINK_END if side == 1 else Control.SIZE_SHRINK_BEGIN
	for child: Node in %Prompts.get_children():
		if child is Prompt:
			var prompt: Prompt = child as Prompt
			prompt.alignment = BoxContainer.ALIGNMENT_END if side == 1 else BoxContainer.ALIGNMENT_BEGIN
			prompt.set_gamepad(gamepad)
	queue_redraw()


func _draw() -> void:
	if not is_node_ready() or not %Prompts.visible or %Prompts.get_child_count() == 0:
		return
	var prompts_rect: Rect2 = Rect2(%Prompts.position, %Prompts.size)
	if prompts_rect.size.x <= 0.0 or prompts_rect.size.y <= 0.0:
		return
	var style: StyleBox = get_theme_stylebox(&"panel", &"PromptBar")
	if style != null:
		var bar_rect: Rect2 = prompts_rect.grow_individual(BAR_PAD_X, BAR_PAD_Y, BAR_PAD_X, BAR_PAD_Y)
		draw_style_box(style, bar_rect)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not follow_input_device or not is_visible_in_tree():
		return
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		if not gamepad:
			set_gamepad(true)
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and not event.relative.is_zero_approx()):
		if gamepad:
			set_gamepad(false)
