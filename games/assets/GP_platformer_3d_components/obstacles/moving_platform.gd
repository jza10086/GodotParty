extends AnimatableBody3D

@export var travel := Vector3(3, 0, 0)
@export_range(0.1, 20.0) var speed := 2.0
@export_range(0.0, 5.0) var dwell := 0.4
@export_range(0.0, 1.0) var phase := 0.0
@onready var origin := position
var time := 0.0

func _physics_process(delta: float) -> void:
	time += delta
	var duration := travel.length() / speed
	var half_cycle := duration + dwell
	var cycle_time := fposmod(time + phase * 2.0 * half_cycle, 2.0 * half_cycle)
	var forward := cycle_time < half_cycle
	var progress := clampf((fmod(cycle_time, half_cycle) - dwell) / duration, 0.0, 1.0)
	position = origin + travel * (progress if forward else 1.0 - progress)
