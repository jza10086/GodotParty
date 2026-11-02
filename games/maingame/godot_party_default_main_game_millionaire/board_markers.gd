## 编辑器和运行时共用路线标记。地产由路旁 PropertyBand 标识，商店由独立建筑标识。
extends Node3D
@export var board: Resource
@export var cells: Node3D

func _ready() -> void:
	if board != null and cells != null:
		build(board)

func build(definition: Resource) -> void:
	if cells == null:
		push_error("BoardMarkers 缺少 Cells 引用")
		return
	var cell_lookup: Dictionary = {}
	for cell: Node3D in cells.get_children():
		if not cell.has_method("record"):
			continue
		cell_lookup[Vector2i(roundi(cell.position.x), roundi(cell.position.z))] = cell
		var previous: Node = cell.get_node_or_null("Markers")
		if previous != null:
			cell.remove_child(previous)
			previous.queue_free()
	var lookup: Dictionary = {}
	for entry: Dictionary in definition.tiles:
		lookup[entry.id] = entry
	var arrow: ArrayMesh = _arrow_mesh()
	var junction_color: StandardMaterial3D = _material(Color("#ffd35d"))
	for tile: Dictionary in definition.tiles:
		if tile.kind not in ["start", "event", "diamond", "junction"]:
			continue
		var cell: Node3D = cell_lookup.get(Vector2i(roundi(tile.x), roundi(tile.z)))
		if cell == null:
			push_error("找不到标记地格：" + str(tile.id))
			continue
		var markers: Node3D = Node3D.new()
		markers.name = "Markers"
		cell.add_child(markers)
		var origin: Vector3 = Vector3(0, 0.055, 0)
		if tile.kind == "start":
			_build_flag(markers)
		if tile.kind == "event":
			var label: Label3D = Label3D.new()
			label.name = "Event"
			label.text = "?"
			label.position = origin + Vector3(0, 0, 0.16)
			label.rotation.x = -PI / 2
			label.font_size = 72
			label.pixel_size = 0.004
			label.modulate = Color("#de9eff")
			markers.add_child(label)
		if tile.kind == "diamond":
			var gem: MeshInstance3D = MeshInstance3D.new()
			gem.name = "Diamond"
			var shape: PlaneMesh = PlaneMesh.new()
			shape.size = Vector2(0.30, 0.30)
			gem.mesh = shape
			gem.rotation.y = PI / 4
			gem.position = origin + Vector3(0, 0, 0.12)
			gem.material_override = _material(Color("#43ecf4"))
			gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			markers.add_child(gem)
		if tile.kind == "junction":
			for port: Vector2i in tile.ports:
				var outgoing: bool = tile.ports[port]
				var direction: Vector3 = Vector3(port.x, 0, port.y)
				var tip: Vector3 = direction if outgoing else -direction
				var marker: MeshInstance3D = MeshInstance3D.new()
				marker.name = ("Exit_" if outgoing else "Entry_") + str(port.x) + "_" + str(port.y)
				marker.mesh = arrow
				marker.material_override = junction_color if outgoing else _material(Color("#65dfee"))
				marker.position = origin + direction * 0.30
				marker.rotation.y = atan2(-tip.x, -tip.z)
				marker.scale = Vector3.ONE * 0.70
				marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				markers.add_child(marker)
			continue
		if tile.kind != "start":
			continue
		for target_id: String in tile.next:
			var target: Dictionary = lookup[target_id]
			var direction: Vector3 = Vector3(target.x - tile.x, 0, target.z - tile.z).normalized()
			var marker: MeshInstance3D = MeshInstance3D.new()
			marker.name = "To_" + tile.id + "_" + target_id
			marker.mesh = arrow
			marker.material_override = junction_color
			marker.position = origin + direction * 0.23
			marker.rotation.y = atan2(-direction.x, -direction.z)
			marker.scale = Vector3.ONE * 0.85
			marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			markers.add_child(marker)

## 旗帜与出发箭头错开；所有几何体都保持在单个 1 米地格内。
func _build_flag(parent: Node3D) -> void:
	var pole: MeshInstance3D = MeshInstance3D.new()
	pole.name = "FlagPole"
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.012
	cylinder.bottom_radius = 0.012
	cylinder.height = 0.55
	pole.mesh = cylinder
	pole.position = Vector3(-0.22, 0.325, -0.10)
	pole.material_override = _material(Color("#eeeeee"))
	parent.add_child(pole)
	var flag: MeshInstance3D = MeshInstance3D.new()
	flag.name = "RedFlag"
	var cloth: BoxMesh = BoxMesh.new()
	cloth.size = Vector3(0.25, 0.16, 0.012)
	flag.mesh = cloth
	flag.position = Vector3(-0.083, 0.51, -0.10)
	flag.material_override = _material(Color("#ee3746"))
	parent.add_child(flag)

func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	return material

func _arrow_mesh() -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = [Vector3(-0.055, 0, 0.10), Vector3(0.055, 0, 0.10), Vector3(0.055, 0, 0), Vector3(-0.055, 0, 0), Vector3(-0.12, 0, 0), Vector3(0, 0, -0.13), Vector3(0.12, 0, 0)]
	for index: int in [0, 1, 2, 0, 2, 3, 4, 5, 6]:
		tool.add_vertex(points[index])
	tool.generate_normals()
	return tool.commit()

