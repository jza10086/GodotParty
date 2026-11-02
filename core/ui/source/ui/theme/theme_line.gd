@tool
extends Line2D
const Config = preload("res://core/ui/source/ui/theme/ui_config.gd")
## Turn Use Global Color off before editing the native local color property.
@export var use_global_color := true:
	set(value):
		use_global_color = value
		notify_property_list_changed()
		_apply_color()
@export_enum("text", "text_hover", "text_disabled", "text_on_primary", "error", "success", "demo_inactive", "info", "surface", "muted_surface", "primary", "hover_surface", "border", "hover_border", "focus", "divider", "selection", "toggle_border", "toggle_active_text", "toggle_off", "toggle_on", "toggle_thumb", "page_background", "menu_backdrop", "rooms_backdrop", "lobby_backdrop", "status_backdrop", "modal_overlay", "capture_overlay", "ruler", "display_background", "display_far_left", "display_far_center", "display_far_right", "display_near_left", "display_near_right", "display_ground", "display_horizon", "display_text", "display_caption") var color_role := "divider":
	set(value):
		color_role = value
		_apply_color()
@export var configuration: Config = preload("res://core/ui/source/ui/theme/ui_config.tres"):
	set(value):
		if configuration != null and configuration.changed.is_connected(_apply_color): configuration.changed.disconnect(_apply_color)
		configuration = value
		_connect_config()
		_apply_color()

func _ready() -> void:
	_connect_config()
	_apply_color()

func _connect_config() -> void:
	if configuration != null and not configuration.changed.is_connected(_apply_color): configuration.changed.connect(_apply_color)

func _apply_color() -> void:
	if use_global_color and configuration != null:
		default_color = configuration.get(color_role)

func _validate_property(property: Dictionary) -> void:
	if use_global_color and property.name == "default_color": property.usage &= ~PROPERTY_USAGE_STORAGE
