extends Node3D

const WeakMissile = preload("res://games/assets/GP_platformer_3d_components/top_down/weak_missile.gd")
@export var projectile: PackedScene = preload("res://games/assets/GP_platformer_3d_components/obstacles/projectile.tscn")
@export_range(0.1, 3.0) var warning_seconds := 0.9
@export_range(0.1, 30.0) var speed := 7.0
@export_range(0.1, 12.0) var projectile_lifetime := 5.0
@export var guided := false
@export var effect: ParkourEffect = preload("res://games/assets/GP_platformer_3d_components/effects/damage.tres")
var target: ParkourEffectReceiver
var remaining := 0.0
var armed := false
var shots_fired := 0

func arm(racer: ParkourEffectReceiver) -> void:
	if armed:
		return
	target = racer
	var aim := racer.global_position
	aim.y = global_position.y
	look_at(aim)
	remaining = warning_seconds
	armed = true
	$Warning.show()

func reset() -> void:
	armed = false
	remaining = 0.0
	shots_fired = 0
	target = null
	$Warning.hide()

func _physics_process(delta: float) -> void:
	if not armed:
		return
	remaining -= delta
	if remaining > 0.0:
		return
	armed = false
	$Warning.hide()
	var shot: ParkourProjectile = projectile.instantiate()
	shot.effect = effect
	shot.lifetime = projectile_lifetime
	if guided:
		var missile := shot as WeakMissile
		missile.target = target
	# Projectiles share the round-owned container so ending a round removes all of them.
	get_parent().get_parent().get_node("Attacks").add_child(shot)
	shot.global_transform = $Muzzle.global_transform.orthonormalized()
	shot.velocity = -shot.global_basis.z*speed
	shots_fired += 1
