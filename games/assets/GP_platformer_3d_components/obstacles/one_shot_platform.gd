extends StaticBody3D

## 第一名选手踩到顶面后，到平台消失的时间。0 表示立即消失，离开不会取消倒计时。
@export_range(0.0, 60.0, 0.05, "or_greater", "suffix:s") var stand_duration := 1.0
@export var respawn_enabled := true
## 平台消失后，到重新出现的时间。
@export_range(0.05, 120.0, 0.05, "or_greater", "suffix:s") var respawn_interval := 3.0
@export var warning_material: Material

@onready var timer: Timer = $Timer
@onready var visual: MeshInstance3D = $Visual
@onready var ready_material := visual.material_override
@onready var collision: CollisionShape3D = $Collision

func _ready() -> void:
	timer.timeout.connect(_on_timeout)

func stepped_on() -> void:
	if visible and timer.is_stopped():
		if stand_duration == 0.0:
			_on_timeout()
			return
		visual.material_override = warning_material
		timer.start(stand_duration)

func _on_timeout() -> void:
	if visible:
		hide()
		collision.disabled = true
		if respawn_enabled:
			timer.start(respawn_interval)
	else:
		visual.material_override = ready_material
		collision.disabled = false
		show()
