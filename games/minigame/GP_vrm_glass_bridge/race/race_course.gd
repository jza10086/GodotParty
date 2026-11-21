class_name VrmBridgeCourse
extends Node3D

const Settings = preload("../settings.gd")

enum Phase { COUNTDOWN, RUNNING, COMPLETE }
@export var course_title: String = "障碍竞速"
@export_range(1, 8) var player_count: int = 1
@export_range(0.0, 10.0) var countdown: float = 3.0
@export_range(0.0, 1200.0) var time_limit: float = 0.0
@export var racer_scene: PackedScene = preload("res://games/minigame/GP_vrm_glass_bridge/race/race_player.tscn")
@export var checkpoint_respawn_enabled: bool = false
@export var run_speed: float = Settings.DEFAULT_RUN_SPEED
@export var sprint_speed: float = Settings.DEFAULT_SPRINT_SPEED
@export var jump_height: float = Settings.DEFAULT_JUMP_HEIGHT

@onready var finish: ParkourGate = $FinishGate
var checkpoints: Array[ParkourGate] = []
var racers: Array[VrmBridgeRacer] = []
var results: Array[VrmBridgeRacer] = []
var phase: Phase = Phase.COUNTDOWN
var elapsed: float = 0.0
var remaining: float
var focused: int = 0
const OrbitCamera = preload("res://games/assets/GP_vrm_character_system/orbit_camera.gd")
const CAMERA_SCENE: PackedScene = preload("res://games/assets/GP_vrm_character_system/orbit_camera.tscn")
var view: OrbitCamera
var preview_actions: Array[StringName] = []

func _enter_tree() -> void:
	if api != null:
		return
	for action: String in Settings.KEYS:
		if InputMap.has_action(action):
			continue
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = Settings.KEYS[action]
		InputMap.add_action(action)
		InputMap.action_add_event(action, event)
		preview_actions.append(action)

func _exit_tree() -> void:
	for action: StringName in preview_actions:
		InputMap.erase_action(action)
	if view != null:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

signal completed()
signal race_started()
var api: PartyAPI
var roster: Array[Dictionary] = []
var local_index: int = -1
var playing: bool = false

func _ready() -> void:
	if api == null:
		playing = true
		_start_course()
		_focus(0)
	else:
		player_count = roster.size()
		_start_course()
		set_physics_process(false)

func start_round() -> void:
	playing = true
	_focus(maxi(0, local_index))

	if api.is_host():
		set_physics_process(true)

func stop_round() -> void:
	playing = false
	process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _start_course() -> void:
	process_physics_priority = 120
	remaining = countdown
	for gate: ParkourGate in $Checkpoints.get_children():
		checkpoints.append(gate)
	for i in player_count:
		var marker: Marker3D = $StartGrid.get_child(i)
		var racer: VrmBridgeRacer = racer_scene.instantiate()
		racer.name = "P%d" % (i + 1)
		racer.transform = global_transform.affine_inverse() * marker.global_transform
		racer.run_speed = run_speed
		racer.sprint_speed = sprint_speed
		racer.jump_height = jump_height
		add_child(racer)
		racer.set_paused(true)
		racer.get_node("Nameplate").text = racer.name if api == null else roster[i].name
		if api != null:
			if roster[i].is_local:
				local_index = i
			if not api.is_host():
				racer.collision_layer = 0
				racer.collision_mask = 0
				racer.set_physics_process(false)
		racers.append(racer)

func _focus(index: int) -> void:
	focused = index
	view = CAMERA_SCENE.instantiate()
	view.target = racers[index]
	add_child(view)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not playing or view == null or (api != null and api.input.input_blocked):
		return
	if api == null and event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			MOUSE_BUTTON_WHEEL_UP:
				view.zoom(1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				view.zoom(-1.0)
			_:
				return
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		view.orbit(event.relative)
	else:
		return
	get_viewport().set_input_as_handled()

## Finishers come first in crossing order, followed by personal score.
## Equal scores use entrant order for stable display; the HUD can show a shared place.
func ranked_racers() -> Array[VrmBridgeRacer]:
	var standings: Array[VrmBridgeRacer] = racers.duplicate()
	standings.sort_custom(func(a: VrmBridgeRacer, b: VrmBridgeRacer) -> bool:
		if a.withdrawn != b.withdrawn:
			return not a.withdrawn
		if a.rank > 0 and b.rank > 0:
			return a.rank < b.rank
		if a.rank > 0 or b.rank > 0:
			return a.rank > 0
		if a.tokens != b.tokens:
			return a.tokens > b.tokens
		return a.get_index() < b.get_index())
	return standings

## Finishers have unique places. Unfinished racers with equal scores share a place.
func standing_places(standings: Array[VrmBridgeRacer]) -> Array[int]:
	var places: Array[int] = []
	for i: int in standings.size():
		var racer: VrmBridgeRacer = standings[i]
		var place: int = i + 1
		if racer.withdrawn:
			place = 0
		elif i > 0 and racer.rank == 0 and standings[i - 1].rank == 0 and racer.tokens == standings[i - 1].tokens:
			place = places[i - 1]
		places.append(place)
	return places

func _physics_process(delta: float) -> void:
	if phase == Phase.COUNTDOWN:
		remaining -= delta
		if remaining <= 0.0:
			phase = Phase.RUNNING
			race_started.emit()
			for racer in racers:
				if racer.withdrawn:
					continue
				racer.active = true
				racer.set_paused(false)
		return
	if phase == Phase.COMPLETE:
		return
	var arrivals: Array[VrmBridgeRacer] = []
	for racer in racers:
		if not racer.active:
			continue
		if racer.checkpoint_count < checkpoints.size():
			var gate: ParkourGate = checkpoints[racer.checkpoint_count]
			if gate.crossing(racer.previous_position, racer.global_position) >= 0.0:
				racer.checkpoint_count += 1
				if checkpoint_respawn_enabled:
					racer.spawn_position = gate.get_node("Respawn").global_position
		if racer.checkpoint_count == checkpoints.size():
			var fraction: float = finish.crossing(racer.previous_position, racer.global_position)
			if fraction >= 0.0:
				var crossing_time: float = elapsed + fraction * delta
				if time_limit == 0.0 or crossing_time <= time_limit:
					racer.finish_time = crossing_time
					arrivals.append(racer)
	arrivals.sort_custom(func(a: VrmBridgeRacer, b: VrmBridgeRacer) -> bool:
		return a.finish_time < b.finish_time if a.finish_time != b.finish_time else a.get_index() < b.get_index())
	var slots: int = racers.size()
	for racer in arrivals:
		if results.size() == slots:
			break
		results.append(racer)
		racer.rank = results.size()
		racer.active = false
		racer.set_paused(true)
	elapsed += delta
	if not racers.any(func(racer: VrmBridgeRacer) -> bool: return racer.active) or results.size() == slots or (time_limit > 0.0 and elapsed >= time_limit):
		phase = Phase.COMPLETE
		for racer in racers:
			racer.active = false
			racer.set_paused(true)
		completed.emit()
		return
	if api == null and racers[focused].active:
		var movement: Vector2 = Input.get_vector(&"vrm_bridge_left", &"vrm_bridge_right", &"vrm_bridge_forward", &"vrm_bridge_back")
		racers[focused].set_motion_input(movement.rotated(-view.yaw), Input.is_action_pressed(&"vrm_bridge_sprint"), Input.is_action_just_pressed(&"vrm_bridge_jump"))
