extends AnimatableBody3D

## 绕本地 X 轴倾斜，每名选手按距支点的本地 Z 距离贡献同等重量。
@export_range(0.0, 40.0, 0.5, "suffix:°") var max_tilt := 22.0
## 每名选手离支点一米产生的目标倾角，多人站在同侧时会叠加。
@export_range(0.0, 30.0, 0.1, "suffix:°/m") var load_response := 8.0
@export_range(0.1, 90.0, 0.1, "suffix:°/s") var tilt_speed := 25.0
@export_range(0.0, 90.0, 0.1, "suffix:°/s") var return_speed := 12.0

@onready var rest_basis := basis
var tilt_degrees := 0.0
var _loads: Dictionary[int, float] = {}

func report_support(racer_id: int, world_position: Vector3) -> void:
	# One load per racer even when a slide reports several contact points.
	_loads[racer_id] = to_local(world_position).z

func _physics_process(delta: float) -> void:
	var lever_sum := 0.0
	for lever: float in _loads.values():
		lever_sum += lever
	var occupied := not _loads.is_empty()
	_loads.clear()
	var target := clampf(lever_sum * load_response, -max_tilt, max_tilt)
	var speed := tilt_speed if occupied else return_speed
	tilt_degrees = move_toward(tilt_degrees, target, speed * delta)
	basis = rest_basis * Basis(Vector3.RIGHT, deg_to_rad(tilt_degrees))
