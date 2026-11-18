extends AnimatableBody3D

## 摆动轴使用预制体本地 Z，旋转整个预制体可改变摆动平面。
@export_range(0.0, 85.0, 0.5, "suffix:°") var swing_angle := 48.0
## 完成一次来回摆动的秒数。
@export_range(0.2, 30.0, 0.05, "or_greater", "suffix:s") var period := 3.0
## 0 从中央出发，0.25 从一侧最高点出发。
@export_range(0.0, 1.0, 0.01) var initial_phase := 0.0

@onready var rest_basis := basis
var elapsed := 0.0

func _physics_process(delta: float) -> void:
	elapsed += delta
	var angle := deg_to_rad(swing_angle) * sin(TAU * (elapsed / period + initial_phase))
	basis = rest_basis * Basis(Vector3.BACK, angle)
