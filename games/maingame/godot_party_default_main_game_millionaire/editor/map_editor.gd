## F6 运行的地图编辑器。编辑只发生在游戏进程，显式保存才写回作者场景。
extends Node3D
const Author = preload("res://games/maingame/godot_party_default_main_game_millionaire/editor/board_authoring.gd")
const Cell = preload("res://games/maingame/godot_party_default_main_game_millionaire/editor/board_cell.gd")
const Routes = preload("res://games/maingame/godot_party_default_main_game_millionaire/editor/board_routes.gd")
const KINDS: Array[String] = ["start", "property", "junction", "event", "shop", "diamond", "decor"]
var _dock: VBoxContainer
var _enabled: CheckButton
var _brush: OptionButton
var _kind: OptionButton
var _turn: OptionButton
var _junction: OptionButton
var _exit_layout: OptionButton
var _layers: SpinBox
var _layer_thickness: Array[SpinBox] = []
var _layer_insets: Array[SpinBox] = []
var _layer_inner: Array[SpinBox] = []
var _layer_panels: Array[VBoxContainer] = []
var _scale: SpinBox
var _model_layer: SpinBox
var _width: SpinBox
var _length: SpinBox
var _color: ColorPickerButton
var _layer_colors: Array[ColorPickerButton] = []
var _asset: LineEdit
var _status: Label
var _file: FileDialog
var _board: Node3D
var _selected: Node3D
var _batch_ids: Dictionary = {}
var _batch_kind: String = ""
var _batch_overlay: Node3D
var _batch_label: Label
var _preview: Node3D
var _hover: Vector2i
var _hover_valid: bool = false
var _copied_decoration: PackedScene
var _copied_turn: int = 0
var _last_mouse: Vector2
var _last_camera: Camera3D
var _stroke_active: bool = false
var _stroke_button: MouseButton = MOUSE_BUTTON_LEFT
var _stroke_before: Array[Dictionary] = []
var _stroke_visited: Dictionary = {}
var _stroke_last: Vector2i

const AFTER_GUI_INPUT_PASS: int = 0
const AFTER_GUI_INPUT_STOP: int = 1
const DEFAULT_MAP: String = "res://games/maingame/godot_party_default_main_game_millionaire/map_preview.tscn"
var _history: UndoRedo = UndoRedo.new()
var _map: Node3D
var _path: String = DEFAULT_MAP
var _file_action: String = "asset"
var _saved_records: Array[Dictionary] = []
var _confirm: ConfirmationDialog
var _pending_action: Callable

func _ready() -> void:
	_build_ui()
	_load_map(DEFAULT_MAP)
	get_tree().auto_accept_quit = false

func _build_ui() -> void:
	_dock = VBoxContainer.new()
	_dock.name = "棋盘地格"
	_dock.custom_minimum_size.x = 265
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel: VBoxContainer = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock.add_child(scroll)
	scroll.add_child(panel)
	_enabled = CheckButton.new()
	_enabled.text = "启用棋盘笔刷"
	panel.add_child(_enabled)
	_brush = _option(panel, "笔刷", ["放置", "删除", "复制（吸取后放置）"])
	_kind = _option(panel, "地格", ["起点", "地产（双格）", "分叉 / 汇流", "事件", "商店（双格）", "钻石", "装饰"])
	_turn = _option(panel, "方向：起点 / 建筑侧 / 路口唯一端或第一出口", ["+X 右", "+Z 下", "−X 左", "−Z 上"])
	_junction = _option(panel, "路口规则", ["T 型单入口", "T 型单出口", "十字单出口（三进一出）", "十字单入口（一进三出）", "十字双出入口（两进两出）"])
	_exit_layout = _option(panel, "双出口布局（指定方向为第一出口）", ["相邻：指定方向及顺时针侧", "相对：指定方向及反方向"])
	_width = _number(panel, "装饰宽度（格，局部 X）", 1, 32, 1, 1)
	_length = _number(panel, "装饰长度（格，局部 Z）", 1, 32, 1, 1)
	_layers = _number(panel, "地基层数", 1, 3, 1, 1)
	_color = _color_field(panel, "表面颜色", Color("#969ca8"))
	for index: int in range(3):
		var group: VBoxContainer = VBoxContainer.new()
		panel.add_child(group)
		_layer_panels.append(group)
		_label(group, "第 %d 层地基（从下往上）" % (index + 1))
		_layer_thickness.append(_number(group, "厚度（米）", 0.01, 1.0, 0.01, Cell.ROAD_THICKNESS))
		_layer_insets.append(_number(group, "外边距（米，距地格边缘）", 0, 0.45, 0.01, 0))
		_layer_inner.append(_number(group, "内边距（米，边框宽度；0 = 实心）", 0, 0.5, 0.01, 0))
		_layer_colors.append(_color_field(group, "颜色", Cell.ROAD_COLOR))
	_label(panel, "建筑 / 装饰场景（留空使用默认或已复制片段）")
	_asset = LineEdit.new()
	_asset.placeholder_text = "res://...glb / tscn"
	panel.add_child(_asset)
	var choose: Button = _button(panel, "选择建筑 / 装饰资源", func() -> void: _choose_file("asset"))
	choose.tooltip_text = "只接受 Node3D 根场景"
	_model_layer = _number(panel, "主模型所在层（从下往上）", 1, 3, 1, 1)
	_scale = _number(panel, "模型尺寸倍率", 0.1, 1.0, 0.05, 1.0)
	_button(panel, "全选当前类型（不含装饰）", _select_all)
	_button(panel, "应用到当前选中地格", _apply_batch)
	_batch_label = Label.new()
	panel.add_child(_batch_label)
	_label(panel, "Shift+左键加选 · Ctrl+左键减选\n有选择时右键清空；批量替换保留位置和朝向")
	_button(panel, "检查路线 / 生成运行数据", _validate)
	_button(panel, "保存地图（Ctrl+S）", func() -> void: save_map(_path))
	_button(panel, "另存为地图", func() -> void: _choose_file("save"))
	_button(panel, "打开地图", func() -> void: _guard_unsaved(func() -> void: _choose_file("open")))
	_button(panel, "清空地图（可撤销）", func() -> void: _commit(_board.records(), [], "清空地图"))
	_button(panel, "撤销 / Ctrl+Z", _undo)
	_button(panel, "重做 / Ctrl+Shift+Z", _redo)
	_button(panel, "重置视角", func() -> void: _map._reset_camera())
	_label(panel, "左键使用笔刷 · 长按右键删除 · R 顺时针 · Shift+R 逆时针\n中键旋转 · Shift+中键平移 · 滚轮缩放\n地图仅在点击保存后写入文件")
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_status)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var frame: PanelContainer = PanelContainer.new()
	layer.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	frame.offset_left = -360
	frame.offset_top = 8
	frame.offset_right = -8
	frame.offset_bottom = -8
	frame.add_child(_dock)
	_file = FileDialog.new()
	_file.access = FileDialog.ACCESS_RESOURCES
	add_child(_file)
	_file.file_selected.connect(_file_selected)
	_confirm = ConfirmationDialog.new()
	add_child(_confirm)
	_confirm.confirmed.connect(func() -> void:
		if _pending_action.is_valid():
			_pending_action.call())
	_kind.item_selected.connect(func(_index: int) -> void: _copied_decoration = null; _asset.text = ""; _update_preview())
	for field: OptionButton in [_turn, _junction, _exit_layout, _brush]:
		field.item_selected.connect(func(_index: int) -> void: _update_preview())
	for field: SpinBox in [_layers, _scale, _model_layer, _width, _length] + _layer_thickness + _layer_insets + _layer_inner:
		field.value_changed.connect(func(_value: float) -> void: _update_preview())
	for field: ColorPickerButton in _layer_colors:
		field.color_changed.connect(func(_value: Color) -> void: _update_preview())
	_color.color_changed.connect(func(_value: Color) -> void: _update_preview())
	_enabled.toggled.connect(func(_value: bool) -> void: _update_preview())


func _exit_tree() -> void:
	_history.clear_history()
	_history.free()

func _scene_changed(root: Node) -> void:
	_end_stroke()
	_clear_preview()
	_clear_batch()
	_selected = null
	_board = null
	_hover_valid = false
	if root != null:
		var candidate: Node = root.get_node_or_null("Cells")
		if candidate != null and candidate.get_script() == Author:
			_board = candidate
	_status.text = "地图缺少有效的 Cells"
	if _board != null:
		_board.rebuilt.connect(_refresh_batch)
		_status.text = "地图已载入；启用笔刷后编辑，Ctrl+S 保存"

## 即使鼠标在视图外松开或窗口失焦，也结束整笔事务。
func _process(_delta: float) -> void:
	if get_viewport().gui_get_hovered_control() != null:
		_end_stroke()
		_hover_valid = false
		_clear_preview()
	if _stroke_active and (not Input.is_mouse_button_pressed(_stroke_button) or not _enabled.button_pressed):
		_end_stroke()

func _point_camera(camera: Camera3D, point: Vector2) -> void:
	_last_camera = camera
	_last_mouse = point
	var hit: Variant = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
	_hover_valid = hit != null
	if hit != null:
		var local: Vector3 = _board.to_local(hit)
		_hover = Vector2i(roundi(local.x), roundi(local.z))

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not is_instance_valid(_board) or not _enabled.button_pressed:
		_end_stroke()
		return AFTER_GUI_INPUT_PASS
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE or event.alt_pressed or event.ctrl_pressed:
			_end_stroke()
			_hover_valid = false
			_update_preview()
			return AFTER_GUI_INPUT_PASS
		_point_camera(camera, event.position)
		if _stroke_active:
			if _hover_valid and event.button_mask & (MOUSE_BUTTON_MASK_RIGHT if _stroke_button == MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_LEFT):
				_drag_to(_hover)
			else:
				_end_stroke()
		_update_preview()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R and not event.ctrl_pressed and not event.alt_pressed:
		_end_stroke()
		_turn.select(posmod(_turn.selected + (-1 if event.shift_pressed else 1), 4))
		_update_preview()
		return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if not event.pressed:
			if event.button_index == _stroke_button:
				_end_stroke()
				_update_preview()
			return AFTER_GUI_INPUT_STOP
		if event.button_index == MOUSE_BUTTON_RIGHT and not _batch_ids.is_empty():
			_end_stroke()
			_clear_batch()
			return AFTER_GUI_INPUT_STOP
		if event.alt_pressed:
			return AFTER_GUI_INPUT_PASS
		_point_camera(camera, event.position)
		if event.button_index == MOUSE_BUTTON_LEFT and (event.shift_pressed or event.ctrl_pressed):
			_end_stroke()
			if _hover_valid:
				_select_batch(_board.cell_at(_hover), event.ctrl_pressed)
			return AFTER_GUI_INPUT_STOP
		if _hover_valid:
			if _brush.selected == 2 and event.button_index == MOUSE_BUTTON_LEFT:
				_act()
			else:
				_begin_stroke(event.button_index)
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS

func _begin_stroke(button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	_end_stroke()
	_stroke_button = button
	_stroke_active = true
	_stroke_before = _board.records()
	_stroke_visited.clear()
	_stroke_last = _hover
	_drag_to(_hover)
	_update_preview()

## 插补快速鼠标移动经过的网格，同一笔每个占地只操作一次。
func _drag_to(point: Vector2i) -> void:
	var origin: Vector2i = _stroke_last
	var distance: int = maxi(absi(point.x - origin.x), absi(point.y - origin.y))
	if distance > 256:
		origin = point
		distance = 0
	for index: int in range(distance + 1):
		var sample: Vector2 = Vector2(origin).lerp(Vector2(point), float(index) / maxf(distance, 1))
		_hover = Vector2i(roundi(sample.x), roundi(sample.y))
		if _stroke_visited.has(_hover):
			continue
		_stroke_visited[_hover] = true
		var target: Node3D = _board.cell_at(_hover)
		if _effective_brush() == 1 and target != null:
			for occupied: Vector2i in Routes.footprint(target.record()):
				_stroke_visited[occupied] = true
		_act()
	_stroke_last = point
	_hover = point

func _end_stroke() -> void:
	if not _stroke_active:
		return
	_stroke_active = false
	if is_instance_valid(_board):
		var after: Array[Dictionary] = _board.records()
		if after != _stroke_before:
			_commit(_stroke_before, after, "连续绘制 / 删除地格", false)
	_stroke_before = []
	_stroke_visited.clear()

func _settings() -> Dictionary:
	var result: Dictionary = {"kind": KINDS[_kind.selected], "turn": _turn.selected,
		"junction_mode": Routes.JUNCTION_MODES[_junction.selected], "exit_layout": "adjacent" if _exit_layout.selected == 0 else "opposite",
		"width": int(_width.value), "length": int(_length.value), "layers": int(_layers.value), "model_layer": int(_model_layer.value), "color": _color.color, "asset": _asset.text.strip_edges(), "model_scale": _scale.value, "decoration_turn": _copied_turn}
	for index: int in range(3):
		result["layer_" + str(index)] = _layer_colors[index].color
		result["thickness_" + str(index)] = _layer_thickness[index].value
		result["outer_margin_" + str(index)] = _layer_insets[index].value
		result["inner_margin_" + str(index)] = _layer_inner[index].value
	return result

func _asset_error() -> String:
	var path: String = _asset.text.strip_edges()
	if path.is_empty():
		return ""
	if not ResourceLoader.exists(path):
		return "资源不存在：" + path
	var resource: Resource = load(path)
	if not resource is PackedScene:
		return "请选择 GLB 或 TSCN 场景"
	var instance: Node = resource.instantiate()
	var valid: bool = instance is Node3D
	instance.free()
	return "" if valid else "模型必须使用 Node3D 根节点"

func _candidate(point: Vector2i) -> Dictionary:
	var result: Dictionary = _settings()
	result.merge({"id": "preview", "node_name": "Preview", "position": point, "decoration": _copied_decoration})
	return result

func _blocked(record: Dictionary, ignore: Node = null) -> bool:
	for point: Vector2i in Routes.footprint(record):
		var other: Node3D = _board.cell_at(point)
		if other != null and other != ignore and not other.is_empty_ground():
			return true
	return false

func _update_preview() -> void:
	_update_field_visibility()
	_clear_preview()
	if not is_instance_valid(_board) or not _enabled.button_pressed or not _hover_valid:
		return
	_preview = Node3D.new()
	_preview.name = "_BrushPreview"
	_board.add_child(_preview)
	var record: Dictionary = _candidate(_hover)
	var target: Node3D = _board.cell_at(_hover)
	# 已占用对象按完整组合显示，避免在建筑侧叠出另一组待放置模型。
	var highlight_existing: bool = target != null and not target.is_empty_ground()
	var blocked: bool = _blocked(record) if _effective_brush() == 0 else target == null
	if _effective_brush() != 0 or highlight_existing:
		record = target.record() if target != null else {"kind": "decor", "position": _hover}
	var tint: Color = Color(1, 0.2, 0.2, 0.42) if blocked or _effective_brush() == 1 else Color(0.3, 0.9, 1, 0.42)
	for point: Vector2i in Routes.footprint(record):
		var mesh: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.98, 0.08, 0.98)
		mesh.mesh = box
		mesh.position = Vector3(point.x, 0.09, point.y)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = tint
		material.no_depth_test = true
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_preview.add_child(mesh)
	if _effective_brush() == 0 and not highlight_existing:
		var ghost: Node3D = Cell.new()
		ghost.data = _settings()
		ghost.decoration = _copied_decoration
		ghost.position = Vector3(_hover.x, 0, _hover.y)
		_preview.add_child(ghost)
		ghost.rebuild([])
		_tint_preview(ghost, tint)
		var arrow: MeshInstance3D = MeshInstance3D.new()
		var factory: Node3D = preload("res://games/maingame/godot_party_default_main_game_millionaire/board_markers.gd").new()
		arrow.mesh = factory._arrow_mesh()
		factory.free()
		var d: Vector2i = Routes.direction(_turn.selected)
		arrow.position = Vector3(_hover.x + d.x * 0.25, 0.18, _hover.y + d.y * 0.25)
		arrow.rotation.y = atan2(-d.x, -d.y)
		var arrow_material: StandardMaterial3D = StandardMaterial3D.new()
		arrow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		arrow_material.albedo_color = Color.YELLOW
		arrow_material.no_depth_test = true
		arrow.material_override = arrow_material
		_preview.add_child(arrow)

func _tint_preview(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = tint
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_tint_preview(child, tint)

func _clear_preview() -> void:
	if is_instance_valid(_preview):
		_preview.get_parent().remove_child(_preview)
		_preview.queue_free()
	_preview = null

func _effective_brush() -> int:
	return 1 if _stroke_active and _stroke_button == MOUSE_BUTTON_RIGHT else _brush.selected

func _act() -> void:
	var target: Node3D = _board.cell_at(_hover)
	if _effective_brush() == 2:
		if target == null:
			return
		_selected = target
		_read(target.record())
		_brush.select(0)
		_status.text = "已吸取 " + str(target.data.id) + "；继续点击放置副本，或应用参数到该地格"
		_update_preview()
		return
	var before: Array[Dictionary] = _board.records()
	var after: Array[Dictionary] = before.duplicate(true)
	if _effective_brush() == 1:
		if target == null:
			return
		after = _without(after, str(target.data.id))
		_selected = null
	else:
		var asset_error: String = _asset_error()
		if not asset_error.is_empty():
			_status.text = asset_error
			return
		var record: Dictionary = _candidate(_hover)
		if _blocked(record):
			_status.text = "占地冲突：整组占地必须为空或可覆盖的单格地面"
			return
		for point: Vector2i in Routes.footprint(record):
			var ground: Node3D = _board.cell_at(point)
			if ground != null:
				after = _without(after, str(ground.data.id))
		var id: String = "C_" + str(Time.get_ticks_usec())
		record.id = id
		record.node_name = id
		after.append(record)
	if _stroke_active:
		_board.apply_records(after)
	else:
		_commit(before, after, "棋盘放置 / 删除")
		_update_preview()

func _clear_batch() -> void:
	_batch_ids.clear()
	_batch_kind = ""
	_refresh_batch()

func _select_batch(cell: Node3D, remove: bool = false) -> void:
	if cell == null:
		return
	var id: String = str(cell.data.id)
	if remove:
		_batch_ids.erase(id)
	elif cell.data.kind == "decor":
		_status.text = "装饰地格暂不支持批量调整"
		return
	elif not _batch_ids.is_empty() and cell.data.kind != _batch_kind:
		_status.text = "只能加选同类地格；右键先清空选择"
		return
	else:
		if _batch_ids.is_empty():
			_batch_kind = cell.data.kind
			_read(cell.record())
		_batch_ids[id] = true
	_refresh_batch()

func _select_all() -> void:
	_end_stroke()
	var kind: String = KINDS[_kind.selected]
	if kind == "decor":
		_status.text = "装饰地格暂不支持批量调整"
		return
	_batch_ids.clear()
	_batch_kind = kind
	for record: Dictionary in _board.records():
		if record.kind == kind:
			_batch_ids[str(record.id)] = true
	_refresh_batch()

func _refresh_batch() -> void:
	if is_instance_valid(_batch_overlay):
		_batch_overlay.get_parent().remove_child(_batch_overlay)
		_batch_overlay.queue_free()
	_batch_overlay = null
	if is_instance_valid(_board) and not _batch_ids.is_empty():
		_batch_overlay = Node3D.new()
		_batch_overlay.name = "_BatchSelection"
		_board.add_child(_batch_overlay)
		var found: Dictionary = {}
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		material.albedo_color = Color(1.0, 0.75, 0.1, 0.3)
		for record: Dictionary in _board.records():
			if not _batch_ids.has(str(record.id)) or record.kind != _batch_kind:
				continue
			found[str(record.id)] = true
			for point: Vector2i in Routes.footprint(record):
				var mesh: MeshInstance3D = MeshInstance3D.new()
				var box: BoxMesh = BoxMesh.new()
				box.size = Vector3(0.98, 0.04, 0.98)
				mesh.mesh = box
				mesh.position = Vector3(point.x, 0.13, point.y)
				mesh.material_override = material
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_batch_overlay.add_child(mesh)
		_batch_ids = found
	if _batch_ids.is_empty():
		_batch_kind = ""
	if is_instance_valid(_batch_label):
		_batch_label.text = "已选择 %d 个地格对象" % _batch_ids.size()

## 整批替换为一次撤销事务；保留身份、锚点和方向，因此不改变道路或建筑占地。
func _apply_batch() -> void:
	_end_stroke()
	if _batch_ids.is_empty():
		_status.text = "先 Shift+左键选择地格或全选当前类型"
		return
	if KINDS[_kind.selected] != _batch_kind or _batch_kind == "decor":
		_status.text = "面板类型必须与所选地格一致"
		return
	var error: String = _asset_error()
	if not error.is_empty():
		_status.text = error
		return
	var before: Array[Dictionary] = _board.records()
	var after: Array[Dictionary] = []
	for old: Dictionary in before:
		if not _batch_ids.has(str(old.id)):
			after.append(old)
			continue
		var replacement: Dictionary = _candidate(old.position)
		replacement.id = old.id
		replacement.node_name = old.node_name
		replacement.turn = old.get("turn", 0)
		after.append(replacement)
	_commit(before, after, "批量调整地格")
	_status.text = "已原地调整 %d 个地格，可整批撤销" % _batch_ids.size()

func _apply_selected() -> void:
	if not is_instance_valid(_board) or not is_instance_valid(_selected):
		_status.text = "先用复制笔刷点击要编辑的地格"
		return
	var asset_error: String = _asset_error()
	if not asset_error.is_empty():
		_status.text = asset_error
		return
	var old: Dictionary = _selected.record()
	var record: Dictionary = _candidate(old.position)
	record.id = old.id
	record.node_name = old.node_name
	if _blocked(record, _selected):
		_status.text = "修改后的占地与其他地格冲突"
		return
	var before: Array[Dictionary] = _board.records()
	var after: Array[Dictionary] = _without(before, str(old.id))
	for point: Vector2i in Routes.footprint(record):
		var ground: Node3D = _board.cell_at(point)
		if ground != null and ground != _selected:
			after = _without(after, str(ground.data.id))
	after.append(record)
	_commit(before, after, "修改地格参数")

func _commit(before: Array[Dictionary], after: Array[Dictionary], title: String, execute: bool = true) -> void:
	_history.create_action(title)
	_history.add_do_method(_board.apply_records.bind(after))
	_history.add_undo_method(_board.apply_records.bind(before))
	_history.commit_action(execute)
	_show_report()

func _validate() -> void:
	if not is_instance_valid(_board):
		return
	_board.refresh()
	_show_report()

func _show_report() -> void:
	var report: Dictionary = _board.report
	_status.text = "路线有效：%d 个玩法格。保存场景即可，运行时从 Cell 生成。 " % report.tiles.size() if report.ok else "无法运行（可继续编辑）：\n" + "\n".join(report.errors.slice(0, 10))

func _read(record: Dictionary) -> void:
	_kind.select(KINDS.find(record.kind))
	_turn.select(int(record.get("turn", 0)))
	_junction.select(maxi(0, Routes.JUNCTION_MODES.find(record.get("junction_mode", "split"))))
	_exit_layout.select(1 if record.get("exit_layout", "adjacent") == "opposite" else 0)
	_width.value = record.get("width", 1)
	_length.value = record.get("length", 1)
	_layers.value = record.get("layers", 1)
	_model_layer.max_value = _layers.value
	_model_layer.value = record.get("model_layer", 1)
	_scale.value = record.get("model_scale", 1)
	_color.color = record.get("color", Color("#969ca8"))
	_asset.text = record.get("asset", "")
	_copied_decoration = record.get("decoration")
	_copied_turn = int(record.get("decoration_turn", record.get("turn", 0)))
	for index: int in range(3):
		_layer_colors[index].color = record.get("layer_" + str(index), Cell.ROAD_COLOR)
		_layer_thickness[index].value = record.get("thickness_" + str(index), Cell.ROAD_THICKNESS)
		_layer_insets[index].value = record.get("outer_margin_" + str(index), 0.0)
		_layer_inner[index].value = record.get("inner_margin_" + str(index), 0.0)
	_update_field_visibility()

## 标题与字段同时隐藏，避免无关规则占据面板。
func _field_visible(field: Control, shown: bool) -> void:
	field.visible = shown
	var label: Control = field.get_parent().get_child(field.get_index() - 1) as Control
	label.visible = shown

func _update_field_visibility() -> void:
	if _layer_panels.size() != 3:
		return
	var kind: String = KINDS[_kind.selected]
	var layered: bool = kind in ["property", "shop", "decor"]
	_field_visible(_junction, kind == "junction")
	_field_visible(_exit_layout, kind == "junction" and _junction.selected == 4)
	_field_visible(_width, kind == "decor")
	_field_visible(_length, kind == "decor")
	_field_visible(_layers, layered)
	_field_visible(_model_layer, layered)
	_model_layer.max_value = _layers.value
	_field_visible(_color, kind in ["property", "shop", "decor", "start"])
	for index: int in range(3):
		_layer_panels[index].visible = layered and index < int(_layers.value)

func _without(records: Array[Dictionary], id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in records:
		if str(record.id) != id:
			result.append(record.duplicate(true))
	return result

func _label(parent: Node, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

func _option(parent: Node, title: String, items: Array[String]) -> OptionButton:
	_label(parent, title)
	var field: OptionButton = OptionButton.new()
	for item: String in items:
		field.add_item(item)
	parent.add_child(field)
	return field

func _number(parent: Node, title: String, minimum: float, maximum: float, step: float, value: float) -> SpinBox:
	_label(parent, title)
	var field: SpinBox = SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.value = value
	parent.add_child(field)
	return field

func _color_field(parent: Node, title: String, value: Color) -> ColorPickerButton:
	_label(parent, title)
	var field: ColorPickerButton = ColorPickerButton.new()
	field.custom_minimum_size.y = 32
	field.color = value
	parent.add_child(field)
	return field

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = title
	button.pressed.connect(action)
	parent.add_child(button)
	return button



## UI 消耗的输入不会到达笔刷；导航事件单独转交给地图相机。
func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_map):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed:
		match event.physical_keycode:
			KEY_S:
				_end_stroke()
				save_map(_path)
			KEY_Z:
				_redo() if event.shift_pressed else _undo()
			KEY_Y:
				_redo()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	var handled: int = _forward_3d_gui_input(_map.camera, event)
	if handled == AFTER_GUI_INPUT_STOP:
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		_map._unhandled_input(event)

func _undo() -> void:
	_end_stroke()
	_history.undo()
	_selected = null
	_clear_preview()
	_show_report()

func _redo() -> void:
	_end_stroke()
	_history.redo()
	_selected = null
	_clear_preview()
	_show_report()

func _choose_file(action: String) -> void:
	_end_stroke()
	_file_action = action
	_file.file_mode = FileDialog.FILE_MODE_SAVE_FILE if action == "save" else FileDialog.FILE_MODE_OPEN_FILE
	_file.filters = PackedStringArray(["*.tscn ; Map scene"]) if action != "asset" else PackedStringArray(["*.tscn,*.glb,*.gltf ; 3D scenes"])
	_file.current_dir = _path.get_base_dir()
	_file.popup_centered_ratio(0.7)

func _file_selected(path: String) -> void:
	match _file_action:
		"save":
			save_map(path)
		"open":
			_load_map(path)
		"asset":
			_asset.text = path
			_copied_decoration = null
			_update_preview()

func _load_map(path: String) -> bool:
	var packed: Resource = load(path)
	if not packed is PackedScene:
		_status.text = "不是地图场景"
		return false
	var candidate: Node = packed.instantiate()
	var cells: Node = candidate.get_node_or_null("Cells")
	if not candidate is Node3D or cells == null or cells.get_script() != Author or candidate.get_script() != preload("res://games/maingame/godot_party_default_main_game_millionaire/map_preview.gd"):
		candidate.free()
		_status.text = "请选择 Millionaire 地图场景"
		return false
	_end_stroke()
	_clear_preview()
	_history.clear_history()
	if is_instance_valid(_map):
		remove_child(_map)
		_map.free()
	_map = candidate
	_map.editing_mode = true
	_map.position = Vector3.ZERO
	add_child(_map)
	_map.set_process_unhandled_input(false)
	_path = path
	_scene_changed(_map)
	_saved_records = _board.records()
	_enabled.button_pressed = true
	return true

## 使用干净模板重新打包 Cell 数据；不保存 UI、悬停预览和生成的 Visual 节点。
## 先完整写入项目 tmp/（同文件系统），备份原文件后替换；失败时保留当前编辑数据。
func save_map(path: String) -> Error:
	_end_stroke()
	if not path.ends_with(".tscn") or not (path.begins_with("res://games/maingame/godot_party_default_main_game_millionaire/") or path.begins_with("res://tmp/")):
		_status.text = "地图只能保存到本玩法目录或 tmp/，格式为 .tscn"
		return ERR_INVALID_PARAMETER
	if path.ends_with("/map_editor.tscn"):
		_status.text = "不能覆盖地图编辑器入口"
		return ERR_INVALID_PARAMETER
	var template: Node3D = load(_path).instantiate()
	template.editing_mode = false
	var old: Node = template.get_node("Cells")
	template.remove_child(old)
	old.free()
	var cells: Node3D = Author.new()
	cells.name = "Cells"
	template.add_child(cells)
	cells.owner = template
	var records: Array[Dictionary] = _board.records()
	for record: Dictionary in records:
		var cell: Node3D = Cell.new()
		cell.name = record.node_name
		cell.position = Vector3(record.position.x, 0, record.position.y)
		cell.data = record.duplicate(true)
		for key: String in ["position", "node_name", "decoration"]:
			cell.data.erase(key)
		cell.decoration = record.get("decoration")
		cells.add_child(cell)
		cell.owner = template
	var numbers: Node = template.get_node("Numbers")
	for child: Node in numbers.get_children():
		numbers.remove_child(child)
		child.free()
	var result: PackedScene = PackedScene.new()
	var error: Error = result.pack(template)
	template.free()
	DirAccess.make_dir_recursive_absolute("res://tmp/map_writes")
	var temp: String = "res://tmp/map_writes/" + str(Time.get_ticks_usec()) + ".tscn"
	if error == OK:
		error = ResourceSaver.save(result, temp)
	if error == OK and FileAccess.file_exists(path):
		DirAccess.make_dir_recursive_absolute("res://tmp/map_backups")
		var backup: String = "res://tmp/map_backups/" + path.get_file().get_basename() + "_" + str(Time.get_ticks_usec()) + ".tscn"
		error = DirAccess.copy_absolute(path, backup)
	if error == OK:
		error = DirAccess.rename_absolute(temp, path)
	if error != OK:
		_status.text = "保存失败，编辑数据仍在内存：" + error_string(error)
		return error
	# 同进程再次打开时读取新文件，避免 ResourceLoader 的旧 PackedScene 缓存。
	ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	_path = path
	_saved_records = records
	_status.text = "已保存：" + path + ("（路线无效，仍是编辑草稿）" if not _board.report.ok else "")
	return OK

func _guard_unsaved(action: Callable) -> void:
	_end_stroke()
	if _board.records() == _saved_records:
		action.call()
	else:
		_pending_action = action
		_confirm.dialog_text = "有未保存修改。放弃这些修改并继续？"
		_confirm.popup_centered()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(_board):
		_guard_unsaved(func() -> void: get_tree().quit())

