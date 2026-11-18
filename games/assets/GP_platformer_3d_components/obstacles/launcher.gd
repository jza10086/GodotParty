extends Node3D

@export var projectile: PackedScene
@export_range(0.1, 20.0) var interval := 2.0
@export_range(0.0, 20.0) var initial_delay := 0.5
@export_range(0.1, 80.0) var speed := 10.0
@onready var remaining := initial_delay
@onready var muzzle: Marker3D = $Muzzle

func _physics_process(delta: float) -> void:
	remaining -= delta
	if remaining > 0.0:
		return
	remaining += interval
	var shot: ParkourProjectile = projectile.instantiate()
	get_parent().add_child(shot)
	shot.global_transform = muzzle.global_transform.orthonormalized()
	shot.velocity = -shot.global_basis.z * speed
	shot.reset_physics_interpolation()
