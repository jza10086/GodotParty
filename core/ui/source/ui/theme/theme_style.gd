@tool
extends StyleBoxFlat
## Semantic surfaces for the retained blue-and-white Godot theme.
const Config = preload("res://core/ui/source/ui/theme/ui_config.gd")
@export var use_global_colors: bool = true:
	set(value):
		use_global_colors = value
		notify_property_list_changed()
		_apply_colors()
@export_enum("surface", "muted_surface", "primary", "hover_surface", "focus", "toggle") var color_role: String = "surface":
	set(value):
		color_role = value
		_apply_colors()
@export var configuration: Config = preload("res://core/ui/source/ui/theme/ui_config.tres"):
	set(value):
		if configuration != null and configuration.changed.is_connected(_apply_colors):
			configuration.changed.disconnect(_apply_colors)
		configuration = value
		_connect_config()
		_apply_colors()

func _init() -> void:
	_connect_config()
	_apply_colors()

func _connect_config() -> void:
	if configuration != null and not configuration.changed.is_connected(_apply_colors):
		configuration.changed.connect(_apply_colors)

func _apply_colors() -> void:
	if not use_global_colors or configuration == null:
		return
	var fill: Color = Color.TRANSPARENT if color_role == "focus" else configuration.get("muted_surface" if color_role == "toggle" else color_role)
	var border: Color = configuration.focus if color_role == "focus" else (configuration.hover_border if color_role == "hover_surface" else (configuration.toggle_border if color_role == "toggle" else configuration.border))
	if bg_color != fill:
		bg_color = fill
	if border_color != border:
		border_color = border

func _validate_property(property: Dictionary) -> void:
	if use_global_colors and property.name in ["bg_color", "border_color"]:
		property.usage &= ~PROPERTY_USAGE_STORAGE
