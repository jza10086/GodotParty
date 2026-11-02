## 棋盘作者根节点：子 Cell 为唯一来源；运行数据与标记均由当前场景生成。
extends Node3D
const Routes = preload("res://games/maingame/godot_party_default_main_game_millionaire/editor/board_routes.gd")
const Cell = preload("res://games/maingame/godot_party_default_main_game_millionaire/editor/board_cell.gd")
const Definition = preload("res://games/maingame/godot_party_default_main_game_millionaire/board_definition.gd")
const Markers = preload("res://games/maingame/godot_party_default_main_game_millionaire/board_markers.gd")
signal rebuilt
var report: Dictionary = {}
var definition: Resource
var _markers: Node3D

func records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell: Node in get_children():
		if cell.get_script() == Cell:
			result.append(cell.record())
	return result

func refresh() -> void:
	report = Routes.solve(records())
	definition = Definition.new()
	if report.ok:
		definition.tiles = report.tiles
	for cell: Node in get_children():
		if cell.get_script() == Cell:
			var p: Vector2i = Vector2i(roundi(cell.position.x), roundi(cell.position.z))
			cell.rebuild(report.adjacent.get(p, []))
	if _markers == null:
		_markers = Markers.new()
		_markers.cells = self
		add_child(_markers)
	var visual_definition: Resource = Definition.new()
	visual_definition.tiles = report.tiles
	_markers.build(visual_definition)
	var numbers: Node3D = get_parent().get_node_or_null("Numbers")
	if numbers != null:
		for child: Node in numbers.get_children():
			numbers.remove_child(child)
			child.queue_free()
		for tile: Dictionary in report.tiles:
			var label: Label3D = Label3D.new()
			label.text = tile.id
			label.position = Vector3(tile.x, 0.035, tile.z)
			label.rotation.x = -PI / 2
			label.font_size = 32
			label.pixel_size = 0.003
			numbers.add_child(label)
	rebuilt.emit()

## 编辑器撤销重做使用差量重建，未变更 Cell 不重新实例化。
func apply_records(next: Array[Dictionary]) -> void:
	var wanted: Dictionary = {}
	for record: Dictionary in next:
		wanted[str(record.id)] = record
	for cell: Node in get_children():
		if cell.get_script() == Cell and not wanted.has(str(cell.data.id)):
			remove_child(cell)
			cell.queue_free()
	var existing: Dictionary = {}
	for cell: Node in get_children():
		if cell.get_script() == Cell:
			existing[str(cell.data.id)] = cell
	for record: Dictionary in next:
		var cell: Node3D = existing.get(str(record.id))
		if cell == null:
			cell = Cell.new()
			cell.name = str(record.node_name)
			add_child(cell)
			cell.owner = owner
		var data: Dictionary = record.duplicate(true)
		for key: String in ["position", "node_name", "decoration"]:
			data.erase(key)
		cell.data = data
		cell.decoration = record.get("decoration")
		cell.position = Vector3(record.position.x, 0, record.position.y)
	refresh()

func cell_at(point: Vector2i) -> Node3D:
	for cell: Node in get_children():
		if cell.get_script() == Cell and point in Routes.footprint(cell.record()):
			return cell
	return null
