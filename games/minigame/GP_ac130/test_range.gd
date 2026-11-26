extends Node3D
## Art and thermal material pairs for the salt-flat range.
var surfaces: Dictionary[Color, StandardMaterial3D] = {}
var cold: Dictionary[Color, StandardMaterial3D] = {}
var white_hot: bool = false

func _ready() -> void:
	block(Vector3(0,-1.2,0), Vector3(430,2,430), Color("#b7a47c"), 0.36)
	for lane: int in range(3):
		var x: float = float(lane-1)*18.0
		block(Vector3(x,-0.15,0),Vector3(14,0.3,36), Color("#53666a"),0.24)
		for side: int in [-1,1]:
			block(Vector3(x+side*6.5,0.04,0), Vector3(0.22,0.08,33), Color("#edbc64"),0.4)
		for z: int in [-11,0,11]:
			ring(Vector3(x,0.14,z), 2.6, 2.78, Color("#e2d8b3"),0.43)
	for side: int in [-1,1]:
		var road_z: float = side*22.0
		block(Vector3(0,-0.08,road_z),Vector3(105,0.22,4.5),Color("#59605d"),0.22)
		for mark: int in range(-8,9):
			block(Vector3(mark*5.5,0.06,road_z),Vector3(2.5,0.04,0.12),Color("#e2d8b3"),0.43)
		for i: int in range(4):
			var pos: Vector3 = Vector3((i-1.5)*14,0,side*34)
			block(pos+Vector3.UP*2,Vector3(9,4,6),Color("#bcae8d"),0.32)
			block(pos+Vector3.UP*4.12,Vector3(9.7,0.4,6.7),Color("#657d81"),0.25)
			block(pos+Vector3(1.5,4.65,0),Vector3(1.6,0.7,2),Color("#805f52"),0.38)
	for i: int in range(8):
		var x: float = 35.0 + 4.2*float(i%2)
		var z: float = -14.0 + 8.0*floorf(i/2.0)
		block(Vector3(x,1.2,z),Vector3(3.2,2.6,6.4),Color("#a65e44") if i%3==0 else Color("#547773"),0.3)
	for i: int in range(16):
		var angle: float = i*TAU/16.0
		var hill: SphereMesh = SphereMesh.new()
		var ridge: MeshInstance3D = shape(hill, Vector3(cos(angle)*91,-4,sin(angle)*91),Color("#94896a"),0.27)
		ridge.scale = Vector3(39,18+i%4*4,32)

func block(pos: Vector3, dimensions: Vector3, tint: Color, heat: float) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	return shape(mesh,pos,tint,heat)

func ring(pos: Vector3, inner: float, outer: float, tint: Color, heat: float) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	return shape(mesh,pos,tint,heat)

func shape(mesh: PrimitiveMesh, pos: Vector3, tint: Color, heat: float) -> MeshInstance3D:
	if not surfaces.has(tint):
		var day: StandardMaterial3D = StandardMaterial3D.new()
		day.albedo_color = tint
		surfaces[tint] = day
		var thermal: StandardMaterial3D = StandardMaterial3D.new()
		thermal.albedo_color = Color(heat,heat,heat)
		thermal.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if heat > 0.9 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		cold[tint] = thermal
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = mesh
	part.set_meta(&"tint",tint)
	part.material_override = cold[tint] if white_hot else surfaces[tint]
	add_child(part)
	part.position = pos
	return part

func set_thermal(enabled: bool) -> void:
	white_hot = enabled
	for part: MeshInstance3D in get_children():
		var tint: Color = part.get_meta(&"tint")
		part.material_override = cold[tint] if enabled else surfaces[tint]
