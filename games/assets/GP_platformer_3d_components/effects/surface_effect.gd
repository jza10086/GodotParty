class_name ParkourSurface
extends Node

@export var effect: ParkourEffect
@export var top_only := false

func _ready() -> void:
	get_parent().add_to_group(&"parkour_effect_surface")

func accepts(normal: Vector3) -> bool:
	var body := get_parent() as Node3D
	return not top_only or normal.dot(body.global_basis.y.normalized()) > 0.7
