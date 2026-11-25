extends Node3D
## An arcade relay defense round. Targets and pulse feedback live in world space.
signal completed(metrics: Dictionary)

const Controls = preload("res://games/protocols/GP_default_protocol/solo_controls.gd")
const Settings = preload("res://games/minigame/GP_ac130/settings.gd")
const TOTAL: int = 18
var controls: Controls = Controls.new(Settings.schema())
var elapsed: float = 0.0
var spawned: int = 0
var score: int = 0
var shield: int = 6
var next_spawn: float = 2.0
var cooldown: float = 0.0
var zoomed: bool = false
var black_hot: bool = false
var active: bool = false
var targets: Array[MeshInstance3D] = []
var propellers: Array[Node] = []
var focus: Vector3 = Vector3.ZERO
@onready var camera: Camera3D = $Camera
@onready var plane: Node3D = $Aircraft
@onready var sensor: ColorRect = $Hud/Sensor
@onready var status: Label = $Hud/Status
@onready var mode: Label = $Hud/Mode
@onready var sight: Label = $Hud/Sight

func solo_setup(input: PartyInput, _text_source: RefCounted) -> void:
	controls.bind(input)

func solo_graphics_targets() -> Dictionary:
	return {"world": $World, "sun": $Sun}

func solo_audio_target() -> PartyGameAudio:
	return null

func _ready() -> void:
	propellers = plane.find_children("Propeller*", "MeshInstance3D", true, false)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 130
	_block(Vector3(0,-1,0), Vector3(360,1,360), 0.24)
	for lane: int in range(-3,4):
		_block(Vector3(lane*24,-0.42,0), Vector3(3,0.1,300), 0.16)
		_block(Vector3(0,-0.42,lane*24), Vector3(300,0.1,3), 0.16)
	for row: int in range(-4,4):
		for col: int in range(-4,4):
			var pos: Vector3 = Vector3(col*20+9,0,row*20+9)
			if pos.length() < 27 or rng.randf() < 0.25:
				continue
			var h: float = rng.randf_range(1.4,5.2)
			var footprint: Vector3 = Vector3(rng.randf_range(4,11),h,rng.randf_range(4,9))
			var facade_heat: float = rng.randf_range(0.24,0.44)
			_block(pos + Vector3.UP*h*0.5, footprint, facade_heat)
			_block(pos + Vector3.UP*h, Vector3(footprint.x+0.35,0.26,footprint.z+0.35), facade_heat+0.06)
			_block(pos + Vector3(footprint.x*0.25,h+0.37,0),Vector3(1.3,0.5,1.8),facade_heat+0.12)
	_ring(Vector3.ZERO, 4.0, 4.5, 0.7)
	_block(Vector3.UP, Vector3(2.4,2.8,2.4), 0.58)
	if controls.context == null:
		solo_start()
	else:
		$Hud.hide()

func solo_start() -> void:
	active = true
	controls.enabled = true
	$Hud.show()
	_update_view(0.0)

func solo_stop() -> void:
	active = false
	controls.enabled = false
	if is_node_ready():
		$Hud.hide()

func _mesh(shape: PrimitiveMesh, pos: Vector3, heat: float) -> MeshInstance3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(heat,heat,heat)
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = shape
	part.material_override = mat
	$Terrain.add_child(part)
	part.position = pos
	return part

func _block(pos: Vector3, dimensions: Vector3, heat: float) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = dimensions
	var part: MeshInstance3D = _mesh(box,pos,heat)
	(part.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

func _ring(pos: Vector3, inside: float, outside: float, heat: float) -> MeshInstance3D:
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = inside
	ring.outer_radius = outside
	return _mesh(ring,pos+Vector3.UP*0.35,heat)

func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	cooldown = maxf(0.0, cooldown-delta)
	_update_view(delta)
	if elapsed < 2.0:
		return
	if spawned < TOTAL and elapsed >= next_spawn:
		var shape: SphereMesh = SphereMesh.new()
		shape.radius = 1.15
		shape.height = 2.3
		var angle: float = spawned * 2.4
		targets.append(_mesh(shape, Vector3(cos(angle)*23,1.3,sin(angle)*23),0.99))
		spawned += 1
		next_spawn += 3.0 if spawned % 6 == 0 else 1.15
	for i: int in range(targets.size()-1,-1,-1):
		var orb: MeshInstance3D = targets[i]
		orb.position = orb.position.move_toward(Vector3.UP*1.3, delta*(2.2 + floorf(float(spawned-1)/6)*0.45))
		if Vector2(orb.position.x,orb.position.z).length() < 3.3:
			orb.queue_free()
			targets.remove_at(i)
			shield -= 1
			if shield == 0:
				break
	if shield == 0 or (spawned == TOTAL and targets.is_empty()):
		active = false
		controls.enabled = false
		status.text = "拦截 %d / %d   ·   护盾 %d" % [score,TOTAL,shield]
		completed.emit({"score":score,"shield":shield})

func _update_view(delta: float) -> void:
	var angle: float = elapsed*0.13
	var radial: Vector3 = Vector3(cos(angle),0,sin(angle))
	plane.position = radial*52 + Vector3.UP*38
	plane.rotation.y = -angle
	sensor.visible = elapsed >= 2.0
	sight.visible = sensor.visible
	if not sensor.visible:
		for propeller: Node3D in propellers:
			propeller.rotate_object_local(Vector3.FORWARD, delta*16.0)
		camera.position = plane.position + radial*36 + Vector3(0,17,22)
		camera.look_at(plane.position)
		status.text = "AC-130J"
		mode.text = ""
		return
	camera.position = plane.position - radial*4
	plane.visible = false
	var mouse: Vector2 = get_viewport().get_mouse_position()
	sight.position = mouse - sight.size*0.5
	if zoomed and controls.allowed():
		var offset: Vector2 = (mouse / get_viewport().get_visible_rect().size - Vector2(0.5,0.5))*2.0
		var right: Vector3 = Vector3(radial.z,0,-radial.x)
		focus = (right * offset.x + radial * offset.y)*15
	else:
		focus = Vector3.ZERO
	camera.look_at(focus)
	camera.fov = move_toward(camera.fov, 34.0 if zoomed else 57.0, delta*75.0)
	status.text = "中继站   %d / 6     ·     拦截   %02d" % [shield,score]
	mode.text = "%s   /   %s     ·     %d / 3" % ["黑热" if black_hot else "白热","2×" if zoomed else "1×",mini(3,1+floori(float(maxi(0,spawned-1))/6))]

func _unhandled_input(event: InputEvent) -> void:
	if not active or elapsed < 2.0:
		return
	if controls.matches(event,&"ac130_polarity"):
		black_hot = not black_hot
		(sensor.material as ShaderMaterial).set_shader_parameter("black_hot", black_hot)
	elif controls.matches(event,&"ac130_zoom"):
		zoomed = not zoomed
	elif controls.matches(event,&"ac130_pulse") and cooldown <= 0.0:
		var pixel: Vector2 = get_viewport().get_mouse_position()
		var spot: Variant = Plane(Vector3.UP,1.3).intersects_ray(camera.project_ray_origin(pixel),camera.project_ray_normal(pixel))
		if spot == null:
			return
		cooldown = 0.32
		var center: Vector3 = spot
		var flash: MeshInstance3D = _ring(center,0.78,1.0,0.96)
		var tween: Tween = create_tween()
		tween.tween_property(flash,"scale",Vector3(3,1,3),0.22)
		tween.tween_callback(flash.queue_free)
		for i: int in range(targets.size()-1,-1,-1):
			if targets[i].position.distance_to(center) <= 3.0:
				targets[i].queue_free()
				targets.remove_at(i)
				score += 1
