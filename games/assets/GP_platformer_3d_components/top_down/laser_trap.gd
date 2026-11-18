extends Node3D

enum Phase { IDLE, WARNING, FIRING }
@export_range(1.0, 40.0) var beam_length := 16.0
@export_range(0.1, 2.0) var beam_width := 0.45
@export_range(0.2, 5.0) var warning_seconds := 1.5
@export_range(0.1, 4.0) var firing_seconds := 0.65
@export_range(0.2, 20.0) var cooldown_seconds := 6.0
@export_range(0.0, 20.0) var initial_delay := 2.0
@export var effect: ParkourEffect = preload("res://games/assets/GP_platformer_3d_components/effects/damage.tres")
var phase := Phase.IDLE
var remaining := 0.0
var pulses := 0
var query := PhysicsShapeQueryParameters3D.new()

func _ready() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(beam_width,1.8,beam_length)
	query.shape = shape
	query.collision_mask = 2
	$Beam.scale = Vector3(beam_width,1,beam_length)
	$Warning.scale = Vector3(beam_width+0.25,1,beam_length)
	reset()

func reset() -> void:
	phase = Phase.IDLE
	remaining = initial_delay
	pulses = 0
	$Beam.hide()
	$Warning.hide()

func _physics_process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		match phase:
			Phase.IDLE:
				phase = Phase.WARNING
				remaining = warning_seconds
				$Warning.show()
			Phase.WARNING:
				phase = Phase.FIRING
				remaining = firing_seconds
				pulses += 1
				$Warning.hide()
				$Beam.show()
			Phase.FIRING:
				phase = Phase.IDLE
				remaining = cooldown_seconds
				$Beam.hide()
	if phase == Phase.FIRING:
		query.transform = global_transform
		for hit in get_world_3d().direct_space_state.intersect_shape(query,8):
			var runner := ParkourEffectReceiver.from_body(hit.collider)
			if runner != null and runner.is_active():
				effect.apply(runner,global_basis)
