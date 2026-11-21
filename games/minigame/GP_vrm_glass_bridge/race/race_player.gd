class_name VrmBridgeRacer
extends "res://games/assets/GP_vrm_character_system/vrm_player.gd"

const Pane = preload("res://games/assets/GP_platformer_3d_components/obstacles/one_shot_platform.gd")
const PlatformScore = preload("res://games/assets/GP_platformer_3d_components/items/platform_score.gd")

signal pane_broken(pane: StaticBody3D)
@onready var receiver: ParkourEffectReceiver = $ParkourReceiver
var tokens: int = 0
var checkpoint_count: int = 0
var rank: int = 0
var finish_time: float = 0.0
var withdrawn: bool = false
var active: bool = false
var previous_position: Vector3


func _ready() -> void:
	super()
	previous_position = global_position
	respawned.connect(_on_respawned)


func _on_respawned() -> void:
	previous_position = global_position


func _physics_process(delta: float) -> void:
	previous_position = global_position
	super(delta)
	if not active or not is_on_floor():
		return
	for i: int in get_slide_collision_count():
		_check_support(get_slide_collision(i))
	# A grounded idle racer may only have a floor-snap contact.
	var support: KinematicCollision3D = move_and_collide(-up_direction * 0.03, true)
	if support != null:
		_check_support(support)


func _check_support(hit: KinematicCollision3D) -> void:
	for i: int in hit.get_collision_count():
		var tile: Node3D = hit.get_collider(i) as Node3D
		var normal: Vector3 = hit.get_normal(i)
		if normal.dot(up_direction) < cos(floor_max_angle) or normal.dot(tile.global_basis.y.normalized()) < 0.7:
			continue
		if tile.is_in_group(&"parkour_scoring_platform"):
			var score: PlatformScore = tile.get_node("Score")
			score.collect(receiver)
		if tile is Pane and tile.visible:
			tile.stepped_on()
			if not tile.visible:
				lose_ground_support()
				pane_broken.emit(tile)
