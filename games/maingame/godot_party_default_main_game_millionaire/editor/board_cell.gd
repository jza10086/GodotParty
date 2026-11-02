## 单个作者地格。data 是编辑来源；Visual 为可重建表现，不写入场景。
extends Node3D
const Routes = preload("res://games/maingame/godot_party_default_main_game_millionaire/editor/board_routes.gd")
const ROAD_THICKNESS: float = 0.12
const ROAD_COLOR: Color = Color("#b9bdc6")
const ASSETS: String = "res://games/maingame/godot_party_default_main_game_millionaire/assets/"
@export var data: Dictionary = {}
## 自定义建筑/装饰片段，可包含多个模型；不承担路线与占地。
@export var decoration: PackedScene
var _visual_key: int = 0

func record() -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	result["position"] = Vector2i(roundi(position.x), roundi(position.z))
	result["node_name"] = str(name)
	result["decoration"] = decoration
	return result

func is_empty_ground() -> bool:
	return data.get("kind", "decor") == "decor" and decoration == null and str(data.get("asset", "")).is_empty() and int(data.get("width", 1)) == 1 and int(data.get("length", 1)) == 1

## 仅在参数或邻接道路变化时重建；相邻等高地基保持整米对齐。
func rebuild(neighbors: Array = []) -> void:
	var key: int = hash([data, decoration, neighbors])
	if key == _visual_key and has_node("Visual"):
		return
	_visual_key = key
	var old: Node = get_node_or_null("Visual")
	if old != null:
		remove_child(old)
		old.queue_free()
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var kind: String = data.get("kind", "decor")
	if kind == "decor":
		var size: Vector2 = _ground_size()
		visual.rotation.y = -int(data.get("turn", 0)) * PI / 2
		visual.position = Vector3((size.x - 1.0) * 0.5, 0, (size.y - 1.0) * 0.5).rotated(Vector3.UP, visual.rotation.y)
	var ground: Color = data.get("color", Color("#969ca8"))
	_ground(visual, ground, kind != "decor", kind in ["decor", "start"])
	if kind not in ["decor", "start"]:
		_road(visual, neighbors)
	if kind in ["property", "shop"]:
		var side: Node3D = Node3D.new()
		side.name = "Side"
		var offset: Vector2i = Routes.direction(int(data.get("turn", 0)))
		side.position = Vector3(offset.x, 0, offset.y)
		visual.add_child(side)
		var elevation: float = _ground(side, ground)
		_build_decoration(side, _model_top(side), true)
		var band: MeshInstance3D = MeshInstance3D.new()
		band.name = "PropertyBand" if kind == "property" else "ShopBand"
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.92, 0.015, 0.07)
		band.mesh = box
		band.position = Vector3(-offset.x * 0.455, elevation + 0.035, -offset.y * 0.455)
		band.rotation.y = PI / 2 if offset.x != 0 else 0.0
		band.material_override = _material(Color("#d1d6de") if kind == "property" else Color("#ff9430"))
		side.add_child(band)
	elif kind == "decor":
		_build_decoration(visual, _model_top(visual), false)

## 道路固定一层；其他地基从同一底面向上累加，边距为各层相对地格边缘的距离。
func _ground_size() -> Vector2:
	if data.get("kind") == "decor":
		return Vector2(clampi(int(data.get("width", 1)), 1, 32), clampi(int(data.get("length", 1)), 1, 32))
	return Vector2.ONE

func _ground(parent: Node3D, color: Color, road: bool = false, surface_enabled: bool = true) -> float:
	var dimensions: Vector2 = Vector2.ONE if road else _ground_size()
	var layers: int = 1 if road else clampi(int(data.get("layers", 1)), 1, 3)
	var top: float = -ROAD_THICKNESS
	var final_inset: float = 0.0
	var final_ring: bool = false
	for index: int in range(layers):
		var thickness: float = ROAD_THICKNESS if road else clampf(float(data.get("thickness_" + str(index), ROAD_THICKNESS)), 0.01, 1.0)
		var inset: float = 0.0 if road else clampf(float(data.get("outer_margin_" + str(index), 0.0)), 0.0, 0.45)
		var base: MeshInstance3D = MeshInstance3D.new()
		base.name = "Base" + str(index)
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(dimensions.x - inset * 2.0, thickness, dimensions.y - inset * 2.0)
		var inner: float = 0.0 if road else maxf(0.0, float(data.get("inner_margin_" + str(index), 0.0)))
		final_ring = inner > 0.0 and inner < minf(box.size.x, box.size.z) * 0.5
		base.mesh = _border_mesh(box.size.x, box.size.z, thickness, inner) if final_ring else box
		base.position.y = top + thickness * 0.5
		base.material_override = _material(ROAD_COLOR if road else data.get("layer_" + str(index), ROAD_COLOR))
		parent.add_child(base)
		top += thickness
		final_inset = inset
	# 边框顶层不加实心盖板，让中央露出下层颜色。
	if surface_enabled and not final_ring:
		var surface: Node3D = load(ASSETS + "roads/tile-low.glb").instantiate()
		surface.name = "Surface"
		surface.position.y = top
		surface.scale = Vector3(dimensions.x - final_inset * 2.0, 1.0, dimensions.y - final_inset * 2.0)
		parent.add_child(surface)
		_tint(surface, _material(color))
	return top

## 四条无重叠长方体组成闭合边框；内边距从外轮廓向中央量取。
func _border_mesh(width: float, length: float, height: float, border: float) -> ArrayMesh:
	var builder: SurfaceTool = SurfaceTool.new()
	var offset: float = (width - border) * 0.5
	for index: int in range(4):
		var box: BoxMesh = BoxMesh.new()
		var position: Vector3
		if index < 2:
			box.size = Vector3(width, height, border)
			position = Vector3(0, 0, (length - border) * 0.5 * (-1 if index == 0 else 1))
		else:
			box.size = Vector3(border, height, length - border * 2.0)
			position = Vector3(offset * (-1 if index == 2 else 1), 0, 0)
		builder.append_from(box, 0, Transform3D(Basis.IDENTITY, position))
	return builder.commit()

func _road(parent: Node3D, neighbors: Array) -> void:
	var local: Array[Vector2i] = []
	var p: Vector2i = Vector2i(roundi(position.x), roundi(position.z))
	for q: Vector2i in neighbors:
		local.append(q - p)
	if data.get("kind") == "junction":
		local.assign(Routes.junction_ports(record(), neighbors).keys())
	var shapes: Dictionary = {"crossroad": [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN], "straight": [Vector2i.LEFT, Vector2i.RIGHT], "bend": [Vector2i.LEFT, Vector2i.DOWN],
		"intersection-path": [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]}
	for shape: String in shapes:
		for turn: int in range(4):
			var expected: Array[Vector2i] = []
			for direction: Vector2i in shapes[shape]:
				var d: Vector2i = direction
				for step: int in range(turn):
					d = Vector2i(d.y, -d.x)
				expected.append(d)
			if expected.size() != local.size():
				continue
			var matches: bool = true
			for d: Vector2i in local:
				matches = matches and d in expected
			if matches:
				var road: Node3D = load(ASSETS + "roads/road-" + shape + ".glb").instantiate()
				road.name = "Road"
				road.rotation.y = turn * PI / 2
				parent.add_child(road)
				return

## 所选层顶面；最上层如有饰面，贴合饰面的实际顶面。
func _model_top(parent: Node3D) -> float:
	var count: int = clampi(int(data.get("layers", 1)), 1, 3)
	var selected: int = clampi(int(data.get("model_layer", 1)), 1, count)
	var top: float = -ROAD_THICKNESS
	for index: int in range(selected):
		top += clampf(float(data.get("thickness_" + str(index), ROAD_THICKNESS)), 0.01, 1.0)
	if selected == count and parent.has_node("Surface"):
		var surface_bounds: AABB = _bounds(parent, parent.get_node("Surface"))
		top = surface_bounds.end.y
	return top

func _build_decoration(parent: Node3D, elevation: float, paired: bool) -> void:
	var model: Node3D
	var path: String = str(data.get("asset", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var resource: Resource = load(path)
		if resource is PackedScene:
			var instance: Node = resource.instantiate()
			if instance is Node3D:
				model = instance
			else:
				instance.free()
	elif decoration != null:
		model = decoration.instantiate() as Node3D
	elif paired:
		model = load(ASSETS + "suburban/building-type-" + ("b" if data.kind == "shop" else "a") + ".glb").instantiate()
	if model == null:
		return
	model.name = "Decoration"
	parent.add_child(model)
	if not paired:
		# 地标按米制原尺寸建模，根原点对齐整组中心；不按单格包围盒归一化。
		model.position = Vector3.ZERO
		model.scale *= float(data.get("model_scale", 1.0))
		var bounds: AABB = _bounds(parent, model)
		model.position.y += elevation - bounds.position.y
		return
	model.position.y += elevation
	if decoration != null and path.is_empty():
		model.scale *= float(data.get("model_scale", 1.0))
		model.rotation.y = -float(int(data.get("turn", 0)) - int(data.get("decoration_turn", data.get("turn", 0)))) * PI / 2
	# 导入的片段保留精确变换；新选择的素材按 0.76 米占地归一化。
	if decoration == null or not path.is_empty():
		var bounds: AABB = _bounds(model, model)
		var extent: float = maxf(bounds.size.x, bounds.size.z)
		var factor: float = 0.76 / maxf(extent, 0.01) * float(data.get("model_scale", 1.0))
		model.scale = Vector3.ONE * factor
		var offset: Vector2i = Routes.direction(int(data.get("turn", 0)))
		model.rotation.y = atan2(-offset.x, -offset.y) if paired else float(data.get("model_turn", 0)) * PI / 2
		var center: Vector3 = bounds.get_center()
		var shift: Vector3 = Vector3(-center.x, -bounds.position.y, -center.z) * factor
		model.position = Vector3(0, elevation, 0) + shift.rotated(Vector3.UP, model.rotation.y)
	# 包括复制的组合模型：保留水平变换，按最终缩放、旋转后的实际底面对齐。
	var placed_bounds: AABB = _bounds(parent, model)
	model.position.y += elevation - placed_bounds.position.y

func _bounds(root: Node3D, node: Node3D) -> AABB:
	var result: AABB = AABB()
	if node is MeshInstance3D:
		result = (root.global_transform.affine_inverse() * node.global_transform) * node.get_aabb()
	for child: Node in node.get_children():
		if child is Node3D:
			var box: AABB = _bounds(root, child)
			if box.size != Vector3.ZERO:
				result = box if result.size == Vector3.ZERO else result.merge(box)
	return result

func _tint(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child: Node in node.get_children():
		_tint(child, material)

func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


