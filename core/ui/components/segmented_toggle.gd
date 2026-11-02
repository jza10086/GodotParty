## Script-created framework toggles compose the source scene's visual children.
## Scene-authored settings instantiate the source component directly.
extends "res://core/ui/source/settings/segmented_toggle.gd"

func _ready() -> void:
	var source: Button = preload("res://core/ui/source/settings/components/segmented_toggle.tscn").instantiate()
	for child: Node in source.get_children():
		child.owner = null
		source.remove_child(child)
		add_child(child)
	theme = source.theme
	theme_type_variation = source.theme_type_variation
	toggle_mode = true
	custom_minimum_size = source.custom_minimum_size
	for style: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style, source.get_theme_stylebox(style))
	source.free()
	super._ready()
