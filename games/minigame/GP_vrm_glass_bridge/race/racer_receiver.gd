extends ParkourEffectReceiver

@onready var racer: VrmBridgeRacer = get_parent()


func is_active() -> bool:
	return racer.active


func launch(direction: Vector3, speed: float) -> void:
	var axis: Vector3 = direction.normalized()
	racer.velocity += axis * (speed - racer.velocity.dot(axis))


func damage(_amount: int, lethal: bool) -> bool:
	if lethal:
		racer.respawn()
	return not lethal


func collect_token() -> void:
	racer.tokens += 1
