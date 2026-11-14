## Framework resource-loading surface. Layout, background and text are authored in the scene.
extends Control

## Consume input before GUI focus, shortcuts and underlying page controls can receive it.
func _input(_event: InputEvent) -> void:
	if is_visible_in_tree():
		get_viewport().set_input_as_handled()

func set_progress(value: float) -> void:
	%Progress.value = value
