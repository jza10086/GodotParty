extends Node3D
## One sortie runs three target exercises. The solo-round protocol publishes its result.
signal completed(metrics: Dictionary)
const Controls = preload("res://games/protocols/GP_default_protocol/solo_controls.gd")
const Settings = preload("res://games/minigame/GP_ac130/settings.gd")
const RangeArt = preload("res://games/minigame/GP_ac130/test_range.gd")
const STAGES: Array[String] = ["固定靶", "移动靶", "集群靶"]
const WEAPONS: Array[String] = ["点射器", "震荡炮"]
const CAPACITY: Array[int] = [6, 2]
const RADIUS: Array[float] = [1.65, 4.25]
const RELOAD_TIME: Array[float] = [1.1, 2.0]
const INTERVAL: Array[float] = [0.17, 0.72]
const TARGET_Y: float = 1.5
const TARGET_COUNT: int = 15

var controls: Controls = Controls.new(Settings.schema())
var magazine: Array[int] = [6,2]
var reserve: Array[int] = [18,4]
var selected: int = 0
var stage: int = -1
var elapsed: float = 0.0
var stage_time: float = 0.0
var cooldown: float = 0.0
var reload_left: float = 0.0
var shots: int = 0
var score: int = 0
var zoomed: bool = false
var thermal: bool = false
var active: bool = false
var targets: Array[MeshInstance3D] = []
var propellers: Array[Node] = []
@onready var camera: Camera3D = $Camera
@onready var plane: Node3D = $Aircraft
@onready var field: RangeArt = $Terrain
@onready var sight: Label = $Hud/Sight
@onready var status: Label = $Hud/Status
@onready var mode: Label = $Hud/Mode
@onready var weapon: Label = $Hud/Weapon
@onready var ammo: Label = $Hud/Ammo

func solo_setup(input: PartyInput, _text_source: RefCounted) -> void:
	controls.bind(input)

func solo_graphics_targets() -> Dictionary:
	return {"world": $World, "sun": $Sun}

func solo_audio_target() -> PartyGameAudio:
	return null

func _ready() -> void:
	propellers = plane.find_children("Propeller*", "MeshInstance3D", true, false)
	if controls.context == null:
		solo_start()
	else:
		$Hud.hide()

func solo_start() -> void:
	active = true
	controls.enabled = true
	$Hud.show()
	_update_view(0.0)
	_update_hud()

func solo_stop() -> void:
	active = false
	controls.enabled = false
	if is_node_ready():
		$Hud.hide()

func _start_stage() -> void:
	stage += 1
	stage_time = 0.0
	var x: float = float(stage-1)*18.0
	for row: int in range(3):
		var center: Vector3 = Vector3(x, TARGET_Y, (row-1)*11)
		if stage == 2:
			for offset: Vector3 in [Vector3(-1.7,0,0.6),Vector3(1.7,0,0.6),Vector3(0,0,-1.7)]:
				_target(center+offset,row)
		else:
			_target(center,row)

func _target(origin: Vector3, row: int) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.75
	mesh.bottom_radius = 1.35
	mesh.height = 1.55
	var target: MeshInstance3D = field.shape(mesh,origin,Color("#ec7135"),0.98)
	target.set_meta(&"origin",origin)
	target.set_meta(&"row",row)
	targets.append(target)

func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	cooldown = maxf(0.0,cooldown-delta)
	if reload_left > 0.0:
		reload_left = maxf(0.0,reload_left-delta)
		if reload_left == 0.0:
			var transfer: int = mini(CAPACITY[selected]-magazine[selected],reserve[selected])
			magazine[selected] += transfer
			reserve[selected] -= transfer
	if elapsed >= 2.0:
		if targets.is_empty() and stage == STAGES.size()-1:
			_finish(true)
			return
		if magazine[0]+magazine[1]+reserve[0]+reserve[1] == 0:
			_finish(false)
			return
		if targets.is_empty():
			_start_stage()
		stage_time += delta
		if stage == 1:
			for target: MeshInstance3D in targets:
				var origin: Vector3 = target.get_meta(&"origin")
				target.position.x = origin.x + sin(stage_time*0.85+float(target.get_meta(&"row")))*4.5
	_update_view(delta)
	_update_hud()

func _finish(cleared: bool) -> void:
	active = false
	controls.enabled = false
	sight.hide()
	status.text = ("测试完成" if cleared else "弹药耗尽") + "   ·   %d / %d" % [score,TARGET_COUNT]
	ammo.text = "消耗   %d 发" % shots
	completed.emit({"score":score,"rounds":shots})

func _update_view(delta: float) -> void:
	var angle: float = elapsed*0.10
	var radial: Vector3 = Vector3(cos(angle),0,sin(angle))
	plane.position = radial*62 + Vector3.UP*49
	plane.rotation.y = -angle
	if stage < 0:
		for propeller: Node3D in propellers:
			propeller.rotate_object_local(Vector3.FORWARD,delta*16)
		camera.position = plane.position+radial*36+Vector3(0,17,22)
		camera.look_at(plane.position)
		return
	plane.hide()
	camera.position = plane.position
	var focus: Vector3 = Vector3((stage-1)*18.0,0,0)
	camera.look_at(focus)
	camera.fov = move_toward(camera.fov,28.0 if zoomed else 53.0,delta*90)
	sight.position = get_viewport().get_mouse_position()-sight.size*0.5

func _update_hud() -> void:
	sight.visible = stage >= 0
	$Hud/Sensor.visible = thermal and stage >= 0
	if stage < 0:
		status.text = "AC-130J    /    盐滩四号测试场"
		return
	status.text = "RANGE 04    /    %02d   %s\n靶标   %02d / %02d" % [stage+1,STAGES[stage],score,TARGET_COUNT]
	mode.text = "%s    /    %s" % ["WHT  白热" if thermal else "TV  彩色","2×" if zoomed else "1×"]
	weapon.text = "WPN   %02d\n%s" % [selected+1,WEAPONS[selected]]
	var state: String = "就绪"
	if reload_left > 0.0:
		state = "装填   %.1f s" % reload_left
	elif magazine[selected] == 0:
		state = "待装填" if reserve[selected] > 0 else "无弹"
	elif cooldown > 0.0:
		state = "冷却"
	ammo.text = "%s\n弹匣   %02d    /    备弹   %02d" % [state,magazine[selected],reserve[selected]]
	sight.modulate = Color("#ffbf67") if reload_left > 0 or magazine[selected] == 0 else Color.WHITE

func _unhandled_input(event: InputEvent) -> void:
	if not active or stage < 0:
		return
	if controls.matches(event,&"ac130_polarity"):
		thermal = not thermal
		field.set_thermal(thermal)
	elif controls.matches(event,&"ac130_zoom"):
		zoomed = not zoomed
	elif controls.matches(event,&"ac130_needle"):
		_select(0)
	elif controls.matches(event,&"ac130_wave"):
		_select(1)
	elif controls.matches(event,&"ac130_reload"):
		if reload_left == 0.0 and magazine[selected] < CAPACITY[selected] and reserve[selected] > 0:
			reload_left = RELOAD_TIME[selected]
	elif controls.matches(event,&"ac130_pulse"):
		_fire()
	_update_hud()

func _select(slot: int) -> void:
	if selected != slot:
		reload_left = 0.0
		selected = slot
		sight.text = "◎" if slot == 1 else "╶┼╴"

func _fire() -> void:
	if cooldown > 0.0 or reload_left > 0.0 or magazine[selected] == 0:
		return
	var pixel: Vector2 = get_viewport().get_mouse_position()
	var spot: Variant = Plane(Vector3.UP,TARGET_Y).intersects_ray(camera.project_ray_origin(pixel),camera.project_ray_normal(pixel))
	if spot == null:
		return
	var center: Vector3 = spot
	magazine[selected] -= 1
	shots += 1
	cooldown = INTERVAL[selected]
	var pulse: MeshInstance3D = field.ring(center,0.85,1.0,Color("#ffd969"),1.0)
	var tween: Tween = create_tween()
	var radius: float = RADIUS[selected]
	tween.tween_property(pulse,"scale",Vector3(radius,1,radius),0.16)
	tween.tween_callback(pulse.queue_free)
	for i: int in range(targets.size()-1,-1,-1):
		if targets[i].position.distance_to(center) <= radius:
			targets[i].queue_free()
			targets.remove_at(i)
			score += 1
