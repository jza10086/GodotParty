class_name ParkourItem
extends Area3D

enum Activation { TOUCH, INTERACT }
enum Consumption { PER_RACER, SHARED, REUSABLE }
@export var activation := Activation.TOUCH
@export var consumption := Consumption.PER_RACER
@export var solid := false
@export var effect: ParkourEffect
@export var prompt := "Collect"
var claimed: Array[ParkourEffectReceiver] = []
var consumed := false
var phase := 0.0

func _ready() -> void:
	$Solid/Shape.disabled = not solid
	body_entered.connect(_on_enter)

func _physics_process(delta: float) -> void:
	phase += delta
	$Visual.position.y = 0.16 * sin(phase * 2.6)
	$Visual.rotation.y = phase

func available(racer: ParkourEffectReceiver) -> bool:
	return racer.is_active() and not consumed and racer not in claimed and overlaps_body(racer.get_parent())

func _on_enter(body: Node3D) -> void:
	var receiver: ParkourEffectReceiver = ParkourEffectReceiver.from_body(body)
	if activation == Activation.TOUCH and receiver != null and available(receiver):
		collect(receiver)

func collect(racer: ParkourEffectReceiver) -> void:
	if not available(racer):
		return
	match consumption:
		Consumption.PER_RACER:
			claimed.append(racer)
		Consumption.SHARED:
			consumed = true
			hide()
			$Solid/Shape.set_deferred("disabled", true)
	effect.apply(racer, global_basis)
