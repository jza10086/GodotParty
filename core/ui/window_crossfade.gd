## Retain the previous rendered frame briefly so closed dialogs can release input immediately.
extends TextureRect

var _surface_id: int = 0
var _was_page: bool = false
var _motion: Tween
var _opening: Tween
var _target: Control

func present(surface: Control, full_page: bool) -> void:
	var next_id: int = surface.get_instance_id() if surface != null else 0
	if next_id == _surface_id:
		return
	var closing_page: bool = _was_page
	clear_transition()
	_surface_id = next_id
	_was_page = full_page
	if DisplayServer.get_name() == "headless":
		return
	var frame: Image = get_viewport().get_texture().get_image()
	if frame == null or frame.is_empty():
		return
	texture = ImageTexture.create_from_image(frame)
	pivot_offset = size * 0.5
	modulate.a = 1.0
	show()
	var duration: float = 0.28 if full_page or closing_page else 0.25
	_motion = create_tween().set_parallel(true)
	_motion.tween_property(self, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
	if surface == null:
		_motion.tween_property(self, "scale", Vector2.ONE * (1.02 if closing_page else 0.98), duration)
	else:
		_target = surface
		surface.pivot_offset = surface.size * 0.5
		surface.scale = Vector2.ONE * (1.02 if full_page else 0.96)
		_opening = surface.create_tween()
		_opening.tween_property(surface, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.chain().tween_callback(_release_frame)

func _release_frame() -> void:
	hide()
	texture = null
	scale = Vector2.ONE

func clear_transition() -> void:
	if _motion:
		_motion.kill()
	if _opening:
		_opening.kill()
	if is_instance_valid(_target):
		_target.scale = Vector2.ONE
	_target = null
	_surface_id = 0
	_was_page = false
	_release_frame()
