## Animate the rendered menu without delaying native selection, dismissal or focus restoration.
extends TextureRect

const RevealScene: PackedScene = preload("res://core/ui/ambient_reveal/components/parts/dropdown_reveal.tscn")
const OPEN_SECONDS: float = 0.16
const CLOSE_SECONDS: float = 0.12
@export var open_upwards: bool = false
@onready var button: OptionButton = get_parent()
@onready var popup: PopupMenu = button.get_popup()
var reveal: CanvasLayer
var mask: ShaderMaterial
var motion: Tween
var upwards: bool

func _ready() -> void:
	reveal = RevealScene.instantiate()
	popup.add_child(reveal)
	mask = reveal.get_node("Reveal").material
	popup.about_to_popup.connect(hide)
	popup.visibility_changed.connect(_visibility_changed)
	button.visibility_changed.connect(_owner_visibility_changed)

func _visibility_changed() -> void:
	if motion:
		motion.kill()
	hide()
	if popup.visible:
		# Native popup sizing is complete here; position it before the reveal starts.
		if open_upwards:
			var top: int = roundi(button.get_screen_transform().origin.y)
			var screen_top: int = 0 if popup.is_embedded() else DisplayServer.screen_get_usable_rect(button.get_window().current_screen).position.y
			popup.max_size.y = mini(popup.max_size.y, maxi(1, top - screen_top))
			popup.size.y = mini(popup.size.y, popup.max_size.y)
			popup.position.y = top - popup.size.y
		texture = null
		upwards = popup.position.y < button.get_screen_transform().origin.y
		mask.set_shader_parameter(&"upwards", upwards)
		mask.set_shader_parameter(&"progress", 0.0)
		reveal.show()
		motion = create_tween()
		motion.tween_property(mask, "shader_parameter/progress", 1.0, OPEN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		motion.tween_callback(_finish_open)
	else:
		reveal.hide()
		if texture and button.is_visible_in_tree():
			_fade_closed_menu()

func _finish_open() -> void:
	reveal.hide()
	# The native window releases its render target on hide. Keep one menu-sized
	# frame after the reveal finishes so dismissal can release input immediately.
	RenderingServer.frame_post_draw.connect(_capture_open_menu, CONNECT_ONE_SHOT)

func _capture_open_menu() -> void:
	if popup.visible and not reveal.visible:
		texture = ImageTexture.create_from_image(popup.get_texture().get_image())

func _fade_closed_menu() -> void:
	var screen_to_canvas: Transform2D = button.get_global_transform() * button.get_screen_transform().affine_inverse()
	var rect: Rect2 = screen_to_canvas * Rect2(popup.position, popup.size)
	position = rect.position
	size = rect.size
	pivot_offset = Vector2(0.0, size.y if upwards else 0.0)
	scale = Vector2.ONE
	self_modulate.a = 1.0
	show()
	motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	motion.tween_property(self, "self_modulate:a", 0.0, CLOSE_SECONDS)
	motion.tween_property(self, "scale:y", 0.94, CLOSE_SECONDS)
	motion.chain().tween_callback(_clear_image)

func _clear_image() -> void:
	hide()
	texture = null

func _owner_visibility_changed() -> void:
	if not button.is_visible_in_tree():
		if motion:
			motion.kill()
		_clear_image()
		reveal.hide()
