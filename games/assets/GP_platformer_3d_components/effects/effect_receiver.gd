@abstract
class_name ParkourEffectReceiver
extends Node3D

static func from_body(body: Node) -> ParkourEffectReceiver:
	return body.get_node_or_null("ParkourReceiver") as ParkourEffectReceiver

@abstract func is_active() -> bool
@abstract func launch(direction: Vector3, speed: float) -> void
@abstract func damage(amount: int, lethal: bool) -> bool
@abstract func collect_token() -> void
