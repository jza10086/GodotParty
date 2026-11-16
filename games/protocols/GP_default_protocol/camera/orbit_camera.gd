@tool
extends Camera3D
## Local orbit camera. Forward pointer events from the playfield to handle_input().
## Only center picking needs physics bodies; focus_on() can track any Node3D.

## Optional authored focus; preserves the camera transform on startup.
@export var initial_focus: Node3D
@export_flags_3d_physics var focus_mask: int = 1
@export_range(0.05, 1.0, 0.01) var degrees_per_pixel: float = 0.25
@export_range(1.01, 2.0, 0.01) var zoom_ratio: float = 1.18
@export var minimum_zoom: float = 1.0
@export var maximum_zoom: float = 80.0

## Optional host predicate, evaluated again before queued input is applied.
var input_allowed: Callable
var _center: Vector3
var _target: Node3D
var _local_anchor: Vector3
var _unit_locked: bool = false
var _dragging: bool = false
var _events: Array[InputEventMouse] = []

func _ready() -> void:
	_center = initial_focus.global_position if initial_focus != null else global_position - global_basis.z.normalized() * 10.0
	set_physics_process(not Engine.is_editor_hint())
	if not Engine.is_editor_hint():
		get_window().focus_exited.connect(_cancel_drag)

## Set the starting composition in world space. Angles are in degrees above the XZ plane.
func set_orbit(center: Vector3, distance: float, yaw: float, pitch: float) -> void:
	_cancel_drag()
	_target = null
	_unit_locked = false
	_center = center
	_place(distance, deg_to_rad(yaw), deg_to_rad(clampf(pitch, 5.0, 85.0)))

## Center and follow the unit, preserving viewing direction and distance.
## The optional anchor is in the unit's local coordinates. Panning releases the lock.
func focus_on(unit: Node3D, local_anchor: Vector3 = Vector3.ZERO) -> void:
	_cancel_drag()
	_target = unit
	_local_anchor = local_anchor
	_unit_locked = true
	_follow()

## Returns true only for camera gestures. Pick in the physics tick so the camera
## also works with threaded physics. Keep input order when a whole drag fits in one tick.
func handle_input(event: InputEvent) -> bool:
	if input_allowed.is_valid() and not input_allowed.call():
		_cancel_drag()
		return false
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index != MOUSE_BUTTON_MIDDLE and not (button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]):
			return false
		_events.append(button)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		_events.append(event)
	else:
		return false
	return true

func _physics_process(_delta: float) -> void:
	_follow()
	if input_allowed.is_valid() and not input_allowed.call():
		_cancel_drag()
		return
	for event: InputEventMouse in _events:
		if event is InputEventMouseButton:
			var button: InputEventMouseButton = event
			if button.button_index == MOUSE_BUTTON_MIDDLE:
				_dragging = button.pressed
				if _dragging:
					_pick_center()
			else:
				if not _dragging:
					_pick_center()
				var steps: float = button.factor if button.factor > 0.0 else 1.0
				_zoom(pow(zoom_ratio, -steps if button.button_index == MOUSE_BUTTON_WHEEL_UP else steps))
		elif _dragging:
			var motion: InputEventMouseMotion = event
			if motion.shift_pressed:
				_pan(motion.relative)
			else:
				_rotate_view(motion.relative)
	_events.clear()

func _cancel_drag() -> void:
	_dragging = false
	_events.clear()

func _follow() -> void:
	if is_instance_valid(_target):
		var next_center: Vector3 = _target.to_global(_local_anchor)
		global_position += next_center - _center
		_center = next_center
	else:
		_unit_locked = false

func _pick_center() -> void:
	if _unit_locked:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().get_center()
	var origin: Vector3 = project_ray_origin(screen)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + project_ray_normal(screen) * far, focus_mask)
	query.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_center = hit.position
		_target = hit.collider
		_local_anchor = _target.to_local(_center)

func _rotate_view(delta: Vector2) -> void:
	var arm: Vector3 = global_position - _center
	var yaw: float = atan2(arm.x, arm.z) - deg_to_rad(delta.x * degrees_per_pixel)
	var pitch: float = atan2(arm.y, Vector2(arm.x, arm.z).length()) + deg_to_rad(delta.y * degrees_per_pixel)
	_place(arm.length(), yaw, clampf(pitch, deg_to_rad(5.0), deg_to_rad(85.0)))

func _place(distance: float, yaw: float, pitch: float) -> void:
	var direction: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	look_at_from_position(_center + direction * distance, _center, Vector3.UP)

func _zoom(factor: float) -> void:
	if projection == PROJECTION_ORTHOGONAL:
		size = clampf(size * factor, minimum_zoom, maximum_zoom)
	else:
		var arm: Vector3 = global_position - _center
		global_position = _center + arm.normalized() * clampf(arm.length() * factor, minimum_zoom, maximum_zoom)

func _pan(delta: Vector2) -> void:
	_target = null
	_unit_locked = false
	var depth: float = global_position.distance_to(_center)
	var screen: Vector2 = get_viewport().get_visible_rect().get_center()
	var scale_per_pixel: float = project_position(screen + Vector2.RIGHT, depth).distance_to(project_position(screen, depth))
	var forward: Vector3 = -global_basis.z
	var ground_forward: Vector3 = Vector3(forward.x, 0.0, forward.z).normalized()
	var shift: Vector3 = (-global_basis.x * delta.x + ground_forward * delta.y / absf(forward.y)) * scale_per_pixel
	_center += shift
	global_position += shift
