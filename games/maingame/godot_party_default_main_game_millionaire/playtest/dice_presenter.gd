## 仅表现预定点数。刚体翻滚后受控收尾，不从物理姿态重新抽取结果。
extends Node3D
signal landed(value: int)
const MODEL: PackedScene = preload("res://games/maingame/godot_party_default_main_game_millionaire/assets/kaykit/D6_A.gltf")
# KayKit D6_A 点窝几何核对：-Y=1、+X=2、+Z=3、-Z=4、-X=5、+Y=6。
const NORMALS: Array[Vector3] = [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.UP]
@export_range(0.1, 4.0) var tumble_seconds: float = 1.8
@export_range(0.05, 2.0) var settle_seconds: float = 0.65
var body: RigidBody3D
var busy: bool = false
var result: int = 0
var _elapsed: float = 0.0
var _settling: bool = false
var _tween: Tween

func _ready() -> void:
	_solid(Vector3(3, 0.2, 2.6), Vector3(0, -0.1, 0), Color("#334756"))
	_solid(Vector3(3.2, 0.35, 0.15), Vector3(0, 0.2, -1.35), Color("#7997a6"))
	_solid(Vector3(3.2, 0.35, 0.15), Vector3(0, 0.2, 1.35), Color("#7997a6"))
	_solid(Vector3(0.15, 0.35, 2.6), Vector3(-1.55, 0.2, 0), Color("#7997a6"))
	_solid(Vector3(0.15, 0.35, 2.6), Vector3(1.55, 0.2, 0), Color("#7997a6"))
	body = RigidBody3D.new()
	body.name = "WhiteD6"
	body.mass = 0.25
	body.collision_layer = 2
	body.collision_mask = 2
	body.continuous_cd = true
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.bounce = 0.38
	body.physics_material_override.friction = 0.65
	body.freeze = true
	add_child(body)
	body.add_child(MODEL.instantiate())
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3.ONE * 0.75
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, 0.375, 0)

func _solid(size: Vector3, at: Vector3, color: Color) -> void:
	var node: StaticBody3D = StaticBody3D.new()
	node.position = at
	node.collision_layer = 2
	node.collision_mask = 2
	add_child(node)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	node.add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var geometry: BoxMesh = BoxMesh.new()
	geometry.size = size
	mesh.mesh = geometry
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	node.add_child(mesh)

## 返回 false 表示忙或非法点数；结果只由调用方确定。seed 仅影响视觉。
func roll(value: int, visual_seed: int) -> bool:
	if busy or value < 1 or value > 6:
		return false
	busy = true
	_settling = false
	result = value
	_elapsed = 0.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = visual_seed
	body.freeze = true
	body.position = Vector3(-0.8, 1.5, 0)
	body.rotation = Vector3(rng.randf_range(-PI, PI), rng.randf_range(-PI, PI), rng.randf_range(-PI, PI))
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.freeze = false
	body.sleeping = false
	body.linear_velocity = Vector3(2.2, 1.5, rng.randf_range(-0.8, 0.8))
	body.angular_velocity = Vector3(rng.randf_range(6, 12), rng.randf_range(3, 8), rng.randf_range(5, 10))
	return true

func _physics_process(delta: float) -> void:
	if not busy or _settling:
		return
	_elapsed += delta
	if _elapsed >= tumble_seconds or body.position.y < -1 or absf(body.position.x) > 3 or absf(body.position.z) > 2.5:
		_settle()

func _settle() -> void:
	_settling = true
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	var target: Quaternion = Quaternion(NORMALS[result - 1], Vector3.UP)
	var initial: Quaternion = body.quaternion
	var start: Vector3 = body.position
	var end: Vector3 = Vector3(clampf(start.x, -0.95, 0.95), 0.375, clampf(start.z, -0.75, 0.75))
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(func(weight: float) -> void:
		body.quaternion = initial.slerp(target, weight)
		# 翻面时先抬离台面，避免旋转角点穿过骰盘。
		body.position = start.lerp(end, weight) + Vector3.UP * sin(weight * PI) * 0.5
	, 0.0, 1.0, settle_seconds)
	_tween.tween_interval(0.35)
	_tween.tween_callback(func() -> void:
		busy = false
		landed.emit(result))

func _exit_tree() -> void:
	if _tween != null:
		_tween.kill()
