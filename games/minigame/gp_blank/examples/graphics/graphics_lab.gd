extends Node3D
## Scene nodes own art settings. Only standalone previews apply experimental quality.
const OrbitCamera = preload("res://games/protocols/godot_party_default_protocol/camera/orbit_camera.gd")
@onready var orbit_camera: OrbitCamera = %Camera
var protocol_managed: bool = false
var _saved_viewport: Dictionary[StringName, Variant] = {}
var _viewport: Viewport

@export_group("F6 Preview Rendering / 仅预览画质")
## MSAA 几何边缘抗锯齿；与 TAA 可叠加。
@export_enum("关闭:0", "2×:1", "4×:2", "8×:3") var msaa: int = Viewport.MSAA_4X
## 时间抗锯齿；Forward+ 有效，FSR2 自带时间抗锯齿。
@export var taa: bool = false
## 屏幕空间抗锯齿。
@export_enum("关闭:0", "FXAA:1", "SMAA:2") var screen_space_aa: int = Viewport.SCREEN_SPACE_AA_DISABLED
## 三维升频算法；不会缩放上层 UI。
@export_enum("Bilinear:0", "FSR 1:1", "FSR 2:2", "Nearest:5") var scaling_mode: int = Viewport.SCALING_3D_MODE_BILINEAR
## 三维内部渲染比例；1 为原生，超过 1 为超采样。
@export_range(0.5, 2.0, 0.05) var render_scale: float = 1.0
## FSR 锐化参数。
@export_range(0.0, 2.0, 0.05) var fsr_sharpness: float = 0.2
## 减少颜色渐变条带。
@export var debanding: bool = true
## 各向异性过滤等级；用于支持此过滤方式的材质。
@export_enum("关闭:0", "2×:1", "4×:2", "8×:3", "16×:4") var anisotropic_filtering: int = Viewport.ANISOTROPY_8X
## 纹理 mipmap 偏移；负数更锐利，也可能增加闪烁。
@export_range(-2.0, 2.0, 0.1) var mipmap_bias: float = 0.0
## 网格 LOD 像素阈值；0 禁用。基础几何本身没有导入 LOD。
@export_range(0.0, 10.0, 0.1) var lod_threshold: float = 1.0
## 视口调试视图，默认正常渲染。
@export var debug_draw: Viewport.DebugDraw = Viewport.DEBUG_DRAW_DISABLED
@export_enum("512:512", "1024:1024", "2048:2048", "4096:4096", "8192:8192") var positional_shadow_size: int = 4096
@export var positional_shadow_16_bits: bool = true
@export_group("Sample Motion / 样品运动")
@export var animate_sample: bool = false
@export_range(0.0, 180.0, 1.0) var rotation_speed: float = 35.0

func graphics_targets() -> Dictionary:
	return {"world": %World, "sun": %Sun}

func _ready() -> void:
	_viewport = get_viewport()
	if not protocol_managed:
		_apply_preview_quality()
	set_process(animate_sample)

func _apply_preview_quality() -> void:
	var quality: Dictionary[StringName, Variant] = {
		&"msaa_3d": msaa, &"use_taa": taa, &"screen_space_aa": screen_space_aa,
		&"scaling_3d_mode": scaling_mode, &"scaling_3d_scale": render_scale,
		&"fsr_sharpness": fsr_sharpness, &"use_debanding": debanding,
		&"anisotropic_filtering_level": anisotropic_filtering, &"texture_mipmap_bias": mipmap_bias,
		&"mesh_lod_threshold": lod_threshold, &"debug_draw": debug_draw,
		&"positional_shadow_atlas_size": positional_shadow_size,
		&"positional_shadow_atlas_16_bits": positional_shadow_16_bits,
	}
	for property: StringName in quality:
		if not _saved_viewport.has(property):
			_saved_viewport[property] = _viewport.get(property)
		_viewport.set(property, quality[property])

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and orbit_camera.handle_input(event):
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	%MaterialSample.rotate_y(deg_to_rad(rotation_speed) * delta)

func _exit_tree() -> void:
	for property: StringName in _saved_viewport:
		_viewport.set(property, _saved_viewport[property])
