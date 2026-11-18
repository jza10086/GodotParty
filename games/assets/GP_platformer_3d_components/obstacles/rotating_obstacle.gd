extends AnimatableBody3D

@export var axis := Vector3.UP
@export var degrees_per_second := 65.0
@export var initial_degrees := 0.0
@onready var rest := basis
var elapsed := 0.0

func _physics_process(delta: float) -> void:
	elapsed += delta
	basis = rest * Basis(axis.normalized(), deg_to_rad(initial_degrees + elapsed * degrees_per_second))
