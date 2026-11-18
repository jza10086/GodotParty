extends Node3D

enum Phase { WARNING, FALLING, ACTIVE }
@export_range(0.3, 5.0) var warning_seconds := 1.6
@export_range(0.1, 2.0) var fall_seconds := 0.45
@export_range(0.2, 5.0) var active_seconds := 1.1
@export_range(0.4, 4.0) var radius := 1.25
@export_range(1.0, 20.0) var drop_height := 7.0
@export var effect: ParkourEffect = preload("res://games/assets/GP_platformer_3d_components/effects/damage.tres")
var phase := Phase.WARNING
var remaining := 0.0
var query := PhysicsShapeQueryParameters3D.new()

func _ready() -> void:
	remaining = warning_seconds
	$Warning.scale = Vector3(radius,1,radius)
	$Blade.scale = Vector3(radius,1,radius)
	$Blade.position.y = drop_height
	$Blade.hide()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 2.0
	query.shape = shape
	query.collision_mask = 2

func _physics_process(delta: float) -> void:
	remaining -= delta
	$Blade.rotation.y += delta*12.0
	match phase:
		Phase.WARNING:
			if remaining <= 0.0:
				phase = Phase.FALLING
				remaining = fall_seconds
				$Blade.show()
		Phase.FALLING:
			$Blade.position.y = lerpf(0.35,drop_height,maxf(0.0,remaining/fall_seconds))
			if remaining <= 0.0:
				phase = Phase.ACTIVE
				remaining = active_seconds
				$Warning.hide()
		Phase.ACTIVE:
			query.transform = Transform3D(Basis.IDENTITY,global_position+Vector3.UP)
			for hit in get_world_3d().direct_space_state.intersect_shape(query,8):
				var runner := ParkourEffectReceiver.from_body(hit.collider)
				if runner != null and runner.is_active():
					effect.apply(runner,global_basis)
			if remaining <= 0.0:
				queue_free()
