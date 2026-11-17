## Framework resource-loading surface. Layout, background and text are authored in the scene.
extends Control

## Consume input before GUI focus, shortcuts and underlying page controls can receive it.
func _input(_event: InputEvent) -> void:
	if is_visible_in_tree():
		get_viewport().set_input_as_handled()

## Unknown progress covers scene initialization and the technical peer barrier.
func set_progress(value: float) -> void:
	%Progress.indeterminate = value < 0.0
	%Progress.show_percentage = value >= 0.0
	if value >= 0.0:
		%Progress.value = value
