class_name ParkourEffect
extends Resource

enum Kind { LAUNCH, DAMAGE, TOKEN }
@export var kind := Kind.LAUNCH
@export var direction := Vector3.UP
@export_range(0.1, 60.0) var speed := 12.0
@export_range(1, 20) var damage_amount := 1
@export var lethal := false

## False means this contact respawned the racer.
func apply(racer: ParkourEffectReceiver, basis: Basis) -> bool:
	match kind:
		Kind.LAUNCH:
			racer.launch(basis.orthonormalized() * direction, speed)
		Kind.DAMAGE:
			return racer.damage(damage_amount, lethal)
		Kind.TOKEN:
			racer.collect_token()
	return true
