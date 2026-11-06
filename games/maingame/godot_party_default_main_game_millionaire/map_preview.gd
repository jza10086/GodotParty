## 独立地图视觉原型：复用协议画质，不包含回合、经济或联机。
## 城市节点保存在场景内，供美术直接编辑。
extends Node3D
## 必填预览相机引用；仅控制此场景的观察视角。
@export var camera: Camera3D
## 必填整图诊断网格引用；G 键切换，默认隐藏。
@export var seam_grid: Node3D
## 必填地块编号节点引用；只作视觉辅助，不保存玩法状态。
@export var tile_labels: Node3D
## 当前地图的单行连接、地格类型与地产展示位置。
var board: Resource
## 由运行时地图编辑器设置；允许无效草稿并隐藏预览 HUD。
@export var editing_mode: bool = false
@export_group("场景美术")
## 相机垂直视野；这是地图构图参数，不随用户画质档位变化。
@export_range(30.0, 90.0, 1.0) var field_of_view: float = 45.0
@export var map_title: String = "城市冒险棋盘"
@export var map_description: String = "35 × 29 米城市棋盘  |  旧城 · 公园 · 湖畔 · 工业角  |  两处路线选择"
@export_range(10.0, 90.0) var overview_distance: float = 61.0
@export var overview_target: Vector3 = Vector3(0, 0.2, 2.0)
@export_range(-180.0, 180.0) var overview_yaw: float = 35.0
@export_range(20.0, 85.0) var overview_pitch: float = 48.0
@export_group("")
const Graphics = preload("res://games/protocols/godot_party_default_protocol/graphics_settings.gd")
var _graphics: RefCounted
var _preferences: PartyConfig
var _target: Vector3 = Vector3.ZERO
var _yaw: float = deg_to_rad(35.0)
var _pitch: float = deg_to_rad(48.0)
var _distance: float = 15.0
var _status: Label

func _ready() -> void:
	if camera == null or seam_grid == null or tile_labels == null:
		push_error("Millionaire preview requires camera, grid and labels")
		return
	$Cells.refresh()
	board = $Cells.definition
	if (board == null or board.tiles.is_empty()) and not editing_mode:
		push_error("Millionaire preview requires board layout")
		return
	if not _start_graphics():
		return
	if not editing_mode:
		_build_hud()
	_reset_camera()
	if "--millionaire-capture" in OS.get_cmdline_user_args():
		_capture_views.call_deferred()

func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for edge: String in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + edge, 28)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(margin)
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop: StyleBoxFlat = StyleBoxFlat.new()
	backdrop.bg_color = Color(0.07, 0.12, 0.16, 0.93)
	backdrop.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", backdrop)
	margin.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var title: Label = Label.new()
	title.text = map_title
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = map_description
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.modulate = Color("#b3c6d0")
	column.add_child(subtitle)
	var help: Label = Label.new()
	help.text = "单行棋盘 | 普通道路每格 1 点 · 路口免费 · 地产/事件停留结算 · 商店/钻石经过可交易 | MMB旋转 Shift+MMB平移 滚轮缩放 G网格 N编号 R重置"
	help.add_theme_font_size_override("font_size", 16)
	column.add_child(help)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 16)
	_status.modulate = Color("#ffe2a0")
	column.add_child(_status)

func _reset_camera() -> void:
	_target = overview_target
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = field_of_view
	camera.v_offset = 0.3
	_distance = overview_distance
	_yaw = deg_to_rad(overview_yaw)
	_pitch = deg_to_rad(overview_pitch)
	_refresh_camera()

## 原版协议登记点：正式运行时由设置作用域自动调用，不需要游戏自行应用画质。
func godot_party_graphics_targets() -> Dictionary:
	return {"world": $World, "sun": $Sun, "materials_root": $Cells}

## F6 原型尚未作为正式游戏包登记；只读取同一协议偏好并复用同一个 runtime。
## 不写偏好，不创建假 PartyAPI，也不接管房间或活动生命周期。
func _start_graphics() -> bool:
	var catalog: RefCounted = preload("res://core/content/party_catalog.gd").new()
	if catalog.scan() != OK:
		push_error(str(catalog.errors))
		return false
	var system: PartyInput = PartyInput.new()
	var store: RefCounted = preload("res://core/config/party_config_store.gd").new(system.settings_path.get_base_dir(), catalog)
	_preferences = PartyConfig.new()
	if _preferences.initialize(store, "", "godot_party_default_protocol", {}) != OK:
		push_error(_preferences.last_error)
		return false
	_graphics = Graphics.new()
	_graphics.configure_preferences(_preferences)
	_graphics.enter()
	var report: Dictionary = _graphics.attach_view(self)
	if not report.ok:
		push_error(report.get("message", "画质设置应用失败"))
		_graphics.leave()
	return report.ok

## 仅改变地产表现，不决定归属。后续大游戏在归属变化后传入玩家颜色；无主传中性灰。
func set_property_color(tile_id: String, color: Color) -> bool:
	var tile: Dictionary = board.find_tile(tile_id)
	if tile.is_empty() or tile.kind != "property":
		return false
	var band: MeshInstance3D = get_node_or_null("Cells/" + tile.property_cell + "/PropertyBand") as MeshInstance3D
	if band == null:
		return false
	var material: StandardMaterial3D = band.material_override.duplicate() as StandardMaterial3D
	material.albedo_color = color
	band.material_override = material
	return true

func _exit_tree() -> void:
	if _graphics != null:
		_graphics.leave()
	if _preferences != null:
		_preferences.close()

func _refresh_camera() -> void:
	camera.position = _target + Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	camera.look_at(_target)
	if _status == null:
		return
	_status.text = "GRID " + ("ON" if seam_grid.visible else "OFF") + "  |  Tile: 1 x 1  |  Spacing: 1.00  |  Perspective / LOD disabled"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R: _reset_camera()
			KEY_G:
				seam_grid.visible = not seam_grid.visible
				_refresh_camera()
			KEY_N: tile_labels.visible = not tile_labels.visible
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE and not event.shift_pressed:
			_yaw -= event.relative.x * 0.006
			_pitch = clampf(_pitch + event.relative.y * 0.006, 0.2, 1.567)
			_refresh_camera()
		elif event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			var factor: float = _distance / 900.0
			_target += (-camera.global_basis.x * event.relative.x + Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z).normalized() * -event.relative.y) * factor
			_refresh_camera()
	if event is InputEventMouseButton and event.pressed:
		var multiplier: float = 0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_distance = clampf(_distance * multiplier, 1.5, 82.0)
			_refresh_camera()

## 开发截图入口：等待时间性效果稳定，用真实渲染器截图后退出。
func _capture_views() -> void:
	for frame: int in range(64):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error: Error = get_viewport().get_texture().get_image().save_png("res://tmp/millionaire_perspective.png")
	if error != OK:
		push_error("Screenshot failed: " + error_string(error))
		get_tree().quit(1)
		return
	print("MILLIONAIRE_PREVIEW: perspective rendered; quality applied; mesh LOD disabled")
	get_tree().quit()
