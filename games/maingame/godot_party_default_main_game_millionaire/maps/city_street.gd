@tool
extends Path3D
## One directed street. Its editable Curve3D and node_kinds define both road visuals and board nodes.
const COLORS: Dictionary[String, Color] = {
	"property": Color("#54748c"), "shop": Color("#d39a4c"),
	"event": Color("#a17aaf"), "diamond": Color("#4caaa1")
}
const FONT: Font = preload("res://games/protocols/godot_party_default_protocol/fonts/NotoSansSC-UI.otf")

@export var from_junction: Node3D
@export var to_junction: Node3D
@export var street_title: String = ""
@export var road_color: Color = Color("#748a96"):
	set(value):
		road_color = value
		if is_inside_tree():
			_queue_rebuild()
@export var node_kinds: PackedStringArray = []:
	set(value):
		node_kinds = value
		if is_inside_tree():
			_queue_rebuild()

var _rebuild_pending: bool = false
var _show_ids: bool = false

func _ready() -> void:
	assert(from_junction != null and to_junction != null, "Street requires both junction references.")
	assert(curve != null, "Street requires a Curve3D.")
	curve_changed.connect(_queue_rebuild)
	rebuild()

func _queue_rebuild() -> void:
	if not _rebuild_pending:
		_rebuild_pending = true
		rebuild.call_deferred()

## Rebuilds only generated presentation; the curve and node types remain the authoring source.
func rebuild() -> void:
	_rebuild_pending = false
	var previous: Node = get_node_or_null("Visual")
	if previous != null:
		remove_child(previous)
		previous.queue_free()
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var length: float = curve.get_baked_length()
	assert(length > 0.0 and not node_kinds.is_empty(), "Street must have length and at least one board node.")
	_ribbon(visual, "RoadBorder", 1.02, 0.0, Color("#435b68"))
	_ribbon(visual, "Road", 0.88, 0.006, road_color)
	for index: int in range(node_kinds.size()):
		var kind: String = node_kinds[index]
		assert(COLORS.has(kind), "Unknown city node kind: " + kind)
		var distance: float = length * float(index + 1) / float(node_kinds.size() + 1)
		var center: Vector3 = curve.sample_baked(distance, true)
		var marker: Node3D = Node3D.new()
		marker.name = "Node%02d" % (index + 1)
		marker.position = center
		visual.add_child(marker)
		_disc(marker, "Border", 0.36, 0.04, Color("#f8f6ee"))
		_disc(marker, "Token", 0.28, 0.065, COLORS[kind])
		if kind != "property":
			var symbol: String = {"shop":"商","event":"?","diamond":"◆"}[kind]
			_text(marker, "Symbol", symbol, Vector3(0,0.105,0), 0.007, Color.WHITE)
		var id: Label3D = _text(marker, "NodeId", "%s-%02d" % [name,index+1], Vector3(0,0.12,-0.55), 0.0035, Color("#304957"))
		id.visible = _show_ids
		if index % 3 == 0:
			_arrow(visual, minf(distance + length / float(node_kinds.size()+1) * 0.5, length-0.5))
	# Branch directions remain readable right after leaving a junction.
	_arrow(visual, minf(0.8, length*0.2))

func board_tiles() -> Array[Dictionary]:
	var tiles: Array[Dictionary] = []
	var length: float = curve.get_baked_length()
	for index: int in range(node_kinds.size()):
		var point: Vector3 = transform * curve.sample_baked(length * float(index+1) / float(node_kinds.size()+1), true)
		var next_id: String = node_id(index+1) if index+1 < node_kinds.size() else str(to_junction.name)
		tiles.append({"id":node_id(index),"kind":node_kinds[index],"x":point.x,"z":point.z,"next":[next_id],"property_cell":"","shop_cell":""})
	return tiles

func node_id(index: int) -> String:
	return "%s_%02d" % [name,index+1]

func show_ids(enabled: bool) -> void:
	_show_ids = enabled
	for marker: Node in get_node("Visual").get_children():
		if marker.has_node("NodeId"):
			marker.get_node("NodeId").visible = enabled

func _ribbon(parent: Node3D, title: String, width: float, elevation: float, color: Color) -> void:
	var mesh_builder: SurfaceTool = SurfaceTool.new()
	mesh_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length: float = curve.get_baked_length()
	var count: int = ceili(length/0.16)
	var pairs: Array[Vector3] = []
	for step: int in range(count+1):
		var distance: float = length*float(step)/float(count)
		var point: Vector3 = curve.sample_baked(distance,true)
		var tangent: Vector3 = (curve.sample_baked(minf(length,distance+0.05),true)-curve.sample_baked(maxf(0.0,distance-0.05),true)).normalized()
		var side: Vector3 = Vector3(-tangent.z,0,tangent.x)*width*0.5
		pairs.append(point+side+Vector3.UP*elevation)
		pairs.append(point-side+Vector3.UP*elevation)
	for step: int in range(count):
		for offset: int in [0,2,1,1,2,3]:
			mesh_builder.add_vertex(pairs[step*2+offset])
	mesh_builder.generate_normals()
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = title
	node.mesh = mesh_builder.commit()
	node.material_override = _material(color)
	parent.add_child(node)

func _arrow(parent: Node3D, distance: float) -> void:
	var center: Vector3 = curve.sample_baked(distance,true)+Vector3.UP*0.09
	var direction: Vector3 = (curve.sample_baked(distance+0.08,true)-curve.sample_baked(distance-0.08,true)).normalized()
	var side: Vector3 = Vector3(-direction.z,0,direction.x)
	var builder: SurfaceTool = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point: Vector3 in [center+direction*0.18,center-direction*0.13+side*0.16,center-direction*0.13-side*0.16]:
		builder.add_vertex(point)
	var arrow: MeshInstance3D = MeshInstance3D.new()
	arrow.mesh = builder.commit()
	arrow.material_override = _material(Color("#fbf5d5"))
	parent.add_child(arrow)

func _disc(parent: Node3D, title: String, radius: float, elevation: float, color: Color) -> void:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = title
	node.position.y = elevation
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.035
	mesh.radial_segments = 24
	node.mesh = mesh
	node.material_override = _material(color)
	parent.add_child(node)

func _text(parent: Node3D, title: String, content: String, pos: Vector3, pixels: float, color: Color) -> Label3D:
	var label: Label3D = Label3D.new()
	label.name = title
	label.text = content
	label.position = pos
	label.rotation_degrees.x = -90.0
	label.font = FONT
	label.font_size = 64
	label.pixel_size = pixels
	label.modulate = color
	label.outline_size = 0
	parent.add_child(label)
	return label

func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
