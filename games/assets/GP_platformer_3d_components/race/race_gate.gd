class_name ParkourGate
extends Node3D

@export_range(0.2, 60) var width := 7.0
@export_range(0.2, 20) var height := 4.0

## Gates face local -Z. Return the fraction of this tick at which the feet crossed.
func crossing(from: Vector3, to: Vector3) -> float:
	var a := to_local(from)
	var b := to_local(to)
	if a.z <= 0.0 or b.z > 0.0:
		return -1.0
	var fraction := a.z / (a.z - b.z)
	var point := a.lerp(b, fraction)
	return fraction if absf(point.x) <= width * 0.5 and point.y >= -0.15 and point.y <= height else -1.0
