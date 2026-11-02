@tool
extends StyleBoxFlat
## Shared semantic surfaces. Soft mode uses beveled corners and offset matte shadows.
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

var _authored_geometry: Dictionary[String, Variant] = {}
var _geometry_ready: bool = false
const GEOMETRY: Array[String] = [
	"border_width_left", "border_width_top", "border_width_right", "border_width_bottom",
	"corner_radius_top_left", "corner_radius_top_right", "corner_radius_bottom_left", "corner_radius_bottom_right",
	"expand_margin_left", "expand_margin_top", "expand_margin_right", "expand_margin_bottom",
	"shadow_color", "shadow_size", "shadow_offset", "corner_detail"
]

func _init() -> void:
	_connect_config()
	_finish_loading.call_deferred()

func _finish_loading() -> void:
	for key: String in GEOMETRY:
		_authored_geometry[key] = get(key)
	_geometry_ready = true
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
	if not _geometry_ready:
		return
	if configuration.visual_style == "sage":
		set_border_width_all(0)
		set_corner_radius_all(12)
		corner_detail = 8
		set_expand_margin_all(0)
		shadow_size = 0
		shadow_offset = Vector2.ZERO
		if color_role == "focus":
			bg_color = Color(0.45, 0.53, 0.35, 0.22)
		return
	if configuration.visual_style != "soft":
		for key: String in _authored_geometry:
			if get(key) != _authored_geometry[key]:
				set(key, _authored_geometry[key])
		return
	set_border_width_all(0)
	set_corner_radius_all(14 if color_role != "toggle" else 10)
	corner_detail = 1
	set_expand_margin_all(0)
	shadow_color = Color("#b9b3ca")
	shadow_size = 1 if color_role not in ["focus", "toggle", "muted_surface"] else 0
	shadow_offset = Vector2(5, 7) if color_role != "hover_surface" else Vector2(3, 4)
	if color_role == "focus":
		# A translucent filled highlight keeps keyboard focus visible without an outline.
		bg_color = Color(0.55, 0.65, 0.82, 0.24)

func _validate_property(property: Dictionary) -> void:
	if use_global_colors and property.name in ["bg_color", "border_color"]:
		property.usage &= ~PROPERTY_USAGE_STORAGE
