@tool
extends ColorRect

@export_range(8.0, 24.0) var corner_radius: float = 20.0
@export_enum("Panel", "Button", "Input") var surface_role: int = 0


func _ready() -> void:
	name = "Surface"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = preload("res://core/ui/ambient_reveal/surface.gdshader")
	material.set_shader_parameter("radius", corner_radius)
	material.set_shader_parameter("surface_role", surface_role)
	material.set_shader_parameter("hover_amount", 0.0)
	material.set_shader_parameter("focus_amount", 0.0)
	resized.connect(_sync_size)
	_sync_size()
	if get_parent() is PanelContainer:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		get_parent().sort_children.connect(_fit_panel.call_deferred)
		_fit_panel.call_deferred()


func _fit_panel() -> void:
	position = Vector2.ZERO
	size = get_parent().size


func _sync_size() -> void:
	material.set_shader_parameter("rect_size", size)
