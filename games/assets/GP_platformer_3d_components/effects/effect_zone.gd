extends Area3D

@export var effect: ParkourEffect

func _ready() -> void:
	body_entered.connect(_on_enter)

func _on_enter(body: Node3D) -> void:
	var receiver: ParkourEffectReceiver = ParkourEffectReceiver.from_body(body)
	if receiver != null and receiver.is_active():
		effect.apply(receiver, global_basis)
