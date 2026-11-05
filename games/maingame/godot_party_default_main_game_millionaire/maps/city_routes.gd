extends Node3D
## Free-angle route study. Junctions and directed Curve3D streets are the authoring source.
## Reuses the existing board definition without a wallet, event execution or network session.
const DEFINITION: GDScript = preload("res://games/maingame/godot_party_default_main_game_millionaire/board_definition.gd")
@export var camera: Camera3D
@export var starting_node: Node3D
var board: Resource
var _target: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _pitch: float = deg_to_rad(72.0)
var _zoom: float = 37.0
var _show_ids: bool = false

func _ready() -> void:
	assert(camera != null and starting_node != null, "Route preview requires a camera and starting node.")
	board = build_board()
	var choices: int = 0
	for tile: Dictionary in board.tiles:
		choices += int(tile.next.size() > 1)
	$Overlay/Count.text = "%d 个节点   ·   %d 处路线选择" % [board.tiles.size(), choices]
	_refresh_camera()

## Builds logical connections from the current street endpoints and node types.
func build_board() -> Resource:
	var result: Resource = DEFINITION.new()
	var incoming: Dictionary[String, int] = {}
	var exits: Dictionary[String, Array] = {}
	for junction: Node3D in %Junctions.get_children():
		incoming[str(junction.name)] = 0
		exits[str(junction.name)] = []
	for street: Path3D in %Streets.get_children():
		assert(street.from_junction.get_parent() == %Junctions and street.to_junction.get_parent() == %Junctions, "Street endpoint is outside this map.")
		assert(street.to_global(street.curve.get_point_position(0)).distance_to(street.from_junction.global_position) < 0.01, "Street start does not meet its junction.")
		assert(street.to_global(street.curve.get_point_position(street.curve.point_count-1)).distance_to(street.to_junction.global_position) < 0.01, "Street end does not meet its junction.")
		exits[str(street.from_junction.name)].append(street.node_id(0))
		incoming[str(street.to_junction.name)] += 1
		result.tiles.append_array(street.board_tiles())
	for junction: Node3D in %Junctions.get_children():
		var id: String = str(junction.name)
		assert(not exits[id].is_empty(), "Dead-end junction: " + id)
		var kind: String = "junction" if exits[id].size()+incoming[id] > 2 else "property"
		if junction == starting_node:
			kind = "start"
			assert(incoming[id] == 0, "Starting node cannot be reentered.")
		var point: Vector3 = junction.position
		result.tiles.append({"id":id,"kind":kind,"x":point.x,"z":point.z,"next":exits[id],"property_cell":"","shop_cell":""})
	return result

func _refresh_camera() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _zoom
	camera.position = _target+Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),cos(_yaw)*cos(_pitch))*55.0
	camera.look_at(_target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				_target = Vector3.ZERO
				_yaw = 0.0
				_pitch = deg_to_rad(72.0)
				_zoom = 37.0
				_refresh_camera()
			KEY_TAB:
				_pitch = deg_to_rad(89.9) if _pitch < deg_to_rad(80.0) else deg_to_rad(72.0)
				_refresh_camera()
			KEY_N:
				_show_ids = not _show_ids
				for street: Path3D in %Streets.get_children():
					street.show_ids(_show_ids)
				for junction: Node3D in %Junctions.get_children():
					junction.get_node("NodeId").visible = _show_ids
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		if event.shift_pressed:
			_target += (-camera.global_basis.x*event.relative.x+Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()*-event.relative.y)*_zoom/1000.0
		else:
			_yaw -= event.relative.x*0.006
			_pitch = clampf(_pitch+event.relative.y*0.006,0.4,deg_to_rad(89.9))
		_refresh_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom = clampf(_zoom*(0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1),12.0,65.0)
			_refresh_camera()
