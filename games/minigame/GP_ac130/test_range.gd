extends Node3D
## Art and thermal material pairs for the salt-flat range.
var surfaces: Dictionary[Color, StandardMaterial3D] = {}
var cold: Dictionary[Color, StandardMaterial3D] = {}
var white_hot: bool = false

func _ready() -> void:
	block(Vector3(0,-1.2,0), Vector3(2400,2,2400), Color("#b7a47c"), 0.36)
	var salt: NoiseTexture2D = NoiseTexture2D.new()
	var fractures: FastNoiseLite = FastNoiseLite.new()
	fractures.noise_type = FastNoiseLite.TYPE_CELLULAR
	fractures.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	fractures.frequency = 0.085
	salt.noise = fractures
	salt.seamless = true
	var tones: Gradient = Gradient.new()
	tones.colors = PackedColorArray([Color("#b3a087"),Color("#e0d3af")])
	salt.color_ramp = tones
	var ground: StandardMaterial3D = surfaces[Color("#b7a47c")]
	ground.albedo_texture = salt
	ground.uv1_scale = Vector3(45,45,1)
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
			block(pos+Vector3(-1,1.35,-3.02*side),Vector3(3.6,2.7,0.18),Color("#4f585e"),0.26)
			block(pos+Vector3(2.7,2.4,-3.12*side),Vector3(1.5,0.9,0.12),Color("#6498a1"),0.21)
			for beam: int in [-1,0,1]:
				block(pos+Vector3(beam*3.7,4.38,0),Vector3(0.15,0.16,6.6),Color("#829596"),0.31)
	for i: int in range(8):
		var x: float = 35.0 + 4.2*float(i%2)
		var z: float = -14.0 + 8.0*floorf(i/2.0)
		block(Vector3(x,1.2,z),Vector3(3.2,2.6,6.4),Color("#a65e44") if i%3==0 else Color("#547773"),0.3)
		for rib: int in range(7):
			block(Vector3(x,2.57,z-2.65+rib*0.85),Vector3(3.0,0.1,0.14),Color("#77837d"),0.31)
	_build_landscape()
	_build_beacon(Vector3(-33,0,-15))
	_build_beacon(Vector3(30,0,17))
	for row: int in [-11,0,11]:
		for rail: float in [-0.88,0.88]:
			block(Vector3(0,0.11,row+rail),Vector3(12,0.16,0.13),Color("#403f3a"),0.29)
		for step: int in range(-5,6,2):
			block(Vector3(step,0.08,row),Vector3(0.36,0.12,2.3),Color("#836e58"),0.34)

func _build_landscape() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1403
	for i: int in range(24):
		var a: float = TAU*i/24.0
		var pos: Vector3 = Vector3(cos(a),0,sin(a))*rng.randf_range(96,142)
		var width: float = rng.randf_range(12,26)
		var h: float = rng.randf_range(7,23)
		_outcrop(pos,width,h,rng)
	for i: int in range(85):
		var a: float = rng.randf_range(0,TAU)
		var pos: Vector3 = Vector3(cos(a),0,sin(a))*rng.randf_range(50,94)
		var radius: float = rng.randf_range(0.5,3.0)
		var slab: MeshInstance3D = drum(pos,radius,radius*0.7,radius*0.8,Color("#998c6c"),0.32,5)
		slab.rotation.y = a
		slab.scale.z = 0.62

## Irregular stepped sandstone, with a shared silhouette across all strata.
func _outcrop(pos: Vector3, width: float, height: float, rng: RandomNumberGenerator) -> void:
	var footprint: PackedVector2Array = PackedVector2Array()
	var relief: PackedFloat32Array = PackedFloat32Array()
	var stretch: float = rng.randf_range(0.45,0.88)
	for i: int in range(10):
		var a: float = TAU*i/10 + rng.randf_range(-0.12,0.12)
		footprint.append(Vector2(cos(a),sin(a)*stretch)*width*rng.randf_range(0.8,1.18))
		relief.append(rng.randf_range(0.78,1.15))
	var top_scale: float = rng.randf_range(0.14,0.49)
	var scales: Array[float] = [1.15,0.83,0.70,top_scale]
	var heights: Array[float] = [-0.04,0.4,0.53,1.0]
	var colors: Array[Color] = [Color("#a58869"),Color("#bd9c76"),Color("#b39776")]
	for band: int in range(3):
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i: int in range(10):
			var j: int = (i+1)%10
			var corners: PackedVector3Array = PackedVector3Array()
			for index: int in [i,j]:
				for layer: int in [band,band+1]:
					var pt: Vector2 = footprint[index]*scales[layer]
					corners.append(Vector3(pt.x+heights[layer]*width*0.28,heights[layer]*height*relief[index],pt.y))
			for vertex: int in [0,2,1,2,3,1]:
				surface.add_vertex(corners[vertex])
			if band == 2:
				for point: Vector3 in [corners[1],corners[3],Vector3(width*0.28,height*1.03,0)]:
					surface.add_vertex(point)
		surface.generate_normals()
		var ridge: MeshInstance3D = shape(surface.commit(),pos,colors[band],0.32+band*0.015)
		ridge.rotation.y = pos.x

func _build_beacon(pos: Vector3) -> void:
	block(pos+Vector3.UP*0.3,Vector3(4,0.7,4),Color("#b5afa0"),0.35)
	for x: int in [-1,1]:
		for z: int in [-1,1]:
			block(pos+Vector3(x,3.5,z),Vector3(0.25,7,0.25),Color("#53666a"),0.24)
	block(pos+Vector3.UP*6.8,Vector3(3.4,0.45,3.4),Color("#e2d8b3"),0.43)
	block(pos+Vector3.UP*7.8,Vector3(2.6,1.65,2.6),Color("#476e78"),0.28)
	block(pos+Vector3.UP*8.75,Vector3(3.5,0.3,3.5),Color("#9e6450"),0.35)
	drum(pos+Vector3.UP*9.55,0.11,0.07,1.5,Color("#687377"),0.3)

func drum(pos: Vector3, bottom: float, top: float, height: float, tint: Color, heat: float, sides: int = 12) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return shape(mesh,pos,tint,heat)

## Separate silhouettes identify each exercise. Material pairs follow children through both views.
func target_model(pos: Vector3, stage: int) -> MeshInstance3D:
	var body: MeshInstance3D = drum(pos,1.12,0.92,0.62,Color("#d55b32"),0.84,8)
	var insert: MeshInstance3D = drum(pos+Vector3.UP*0.45,0.62,0.46,0.38,Color("#ffb344"),0.99,12)
	insert.reparent(body)
	var collar: MeshInstance3D = ring(pos+Vector3.UP*0.24,0.84,1.02,Color("#453f3a"),0.32)
	collar.reparent(body)
	if stage == 0:
		drum(pos-Vector3.UP*0.85,0.5,0.33,1.25,Color("#687377"),0.3).reparent(body)
	elif stage == 1:
		block(pos-Vector3.UP*0.68,Vector3(3.2,0.43,1.8),Color("#465358"),0.38).reparent(body)
		for x: int in [-1,1]:
			for z: int in [-1,1]:
				var wheel: MeshInstance3D = drum(pos+Vector3(x,-1.05,z*0.9),0.43,0.43,0.28,Color("#343d42"),0.26)
				wheel.rotation.x = PI/2
				wheel.reparent(body)
	else:
		for i: int in range(3):
			var arm: Vector3 = Vector3(cos(TAU*i/3),0,sin(TAU*i/3))
			ring(pos+arm*1.04,0.25,0.39,Color("#576973"),0.47).reparent(body)
	return body

func impact(pos: Vector3) -> void:
	for i: int in range(5):
		var angle: float = TAU*i/5.0
		var chip: MeshInstance3D = block(pos,Vector3(0.28,0.23,0.48),Color("#ffc471"),0.97)
		var offset: Vector3 = Vector3(cos(angle)*2,1.4+0.3*(i%2),sin(angle)*2)
		var tween: Tween = chip.create_tween()
		tween.tween_property(chip,"position",pos+offset,0.21).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(chip,"scale",Vector3.ONE*0.01,0.19)
		tween.tween_callback(chip.queue_free)

func block(pos: Vector3, dimensions: Vector3, tint: Color, heat: float) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	return shape(mesh,pos,tint,heat)

func ring(pos: Vector3, inner: float, outer: float, tint: Color, heat: float) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	return shape(mesh,pos,tint,heat)

func shape(mesh: Mesh, pos: Vector3, tint: Color, heat: float) -> MeshInstance3D:
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
	for part: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		var tint: Color = part.get_meta(&"tint")
		part.material_override = cold[tint] if enabled else surfaces[tint]
