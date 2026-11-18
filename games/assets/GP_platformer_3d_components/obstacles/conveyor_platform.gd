extends StaticBody3D

## 表面沿本地 -Z 方向运动。负数反向，0 停止；旋转整个预制体可调整方向。
@export_range(-15.0, 15.0, 0.1, "or_less", "or_greater", "suffix:m/s") var belt_speed := 2.0

func _physics_process(delta: float) -> void:
	constant_linear_velocity = -global_basis.z.normalized() * belt_speed
	$Direction.rotation.y = PI if belt_speed < 0.0 else 0.0
	$Direction.position.z = wrapf($Direction.position.z - belt_speed * delta, -1.5, 1.5)
