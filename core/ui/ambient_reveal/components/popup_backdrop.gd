extends CanvasLayer

const SURFACE = preload("res://core/ui/ambient_reveal/components/parts/button_surface.tscn")
@export var inset: Vector2 = Vector2(24, 24)
@onready var window: Window = get_parent()
@onready var _surface: Panel = $Surface


func _ready() -> void:
	window.transparent = true
	window.transparent_bg = true
	window.borderless = true
	if window is AcceptDialog:
		window.get_ok_button().add_child(SURFACE.instantiate())
	if window is ConfirmationDialog:
		window.get_cancel_button().add_child(SURFACE.instantiate())
	window.about_to_popup.connect(_capture)
	window.size_changed.connect(_fit)
	_fit()


func _capture() -> void:
	var source: Viewport = window.get_parent().get_viewport()
	if DisplayServer.get_name() == "headless":
		return
	var image: Image = source.get_texture().get_image()
	image.generate_mipmaps()
	var shader: ShaderMaterial = _surface.material
	shader.set_shader_parameter("use_backdrop", true)
	shader.set_shader_parameter("backdrop", ImageTexture.create_from_image(image))
	shader.set_shader_parameter("backdrop_extent", source.get_visible_rect().size)
	_fit.call_deferred()


func _fit() -> void:
	_surface.offset_left = inset.x
	_surface.offset_top = inset.y
	_surface.offset_right = -inset.x
	_surface.offset_bottom = -inset.y
	_surface.material.set_shader_parameter("backdrop_origin", Vector2(window.position) + inset)
