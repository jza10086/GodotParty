extends AnimatableBody3D

@export var travel := Vector3(4, 0, 0)
@export_range(0.05, 10.0) var warning_seconds := 1.2
@export_range(0.05, 10.0) var extend_seconds := 0.5
@export_range(0.05, 10.0) var hold_seconds := 0.65
@export_range(0.05, 10.0) var retract_seconds := 1.3
@export_range(0.0, 1.0) var phase := 0.0
@onready var origin := position
var elapsed := 0.0

func _physics_process(delta: float) -> void:
	elapsed += delta
	var cycle := warning_seconds + extend_seconds + hold_seconds + retract_seconds
	var t := fposmod(elapsed + phase * cycle, cycle)
	$Warning.visible = t < warning_seconds and fmod(t, 0.25) < 0.15
	var stretch := clampf((t - warning_seconds) / extend_seconds, 0.0, 1.0)
	var retract := clampf((t - warning_seconds - extend_seconds - hold_seconds) / retract_seconds, 0.0, 1.0)
	position = origin + travel * (stretch - retract)
