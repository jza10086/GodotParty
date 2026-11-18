## One-meter cube, feet at origin, front is -Z. Games own collision and movement.
extends Node3D
var _material: StandardMaterial3D

func _ready() -> void:
	if _material == null:
		apply_color(Color("#478cbf"))

## Material overrides are per instance; coloring one player never changes another.
func apply_color(value: Color) -> void:
	var body: MeshInstance3D = get_node_or_null("%Body")
	if body == null:
		push_error("GodotPartyDefault 3D placeholder requires Body")
		return
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.roughness = 0.8
		body.material_override = _material
	_material.albedo_color = value
