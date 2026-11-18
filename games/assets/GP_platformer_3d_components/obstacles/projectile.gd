class_name ParkourProjectile
extends CharacterBody3D

@export var effect: ParkourEffect
@export_range(0.1, 30.0) var lifetime := 3.0

func _physics_process(delta: float) -> void:
	var hit := move_and_collide(velocity * minf(lifetime, delta))
	lifetime -= delta
	if hit:
		var target: ParkourEffectReceiver = ParkourEffectReceiver.from_body(hit.get_collider())
		if effect and target != null and target.is_active():
			effect.apply(target, global_basis)
	if hit or lifetime <= 0.0:
		queue_free()
