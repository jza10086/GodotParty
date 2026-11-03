@tool
extends SubViewportContainer
## 空白小游戏的常驻画面调校展台。编辑器与实机使用同一独立视口、相机和资源。
## 只修改自己的视口与场景；不写项目设置、RenderingServer 全局质量或用户偏好。
## 环境与材质使用原生 Resource Inspector，保留完整参数而不重复一套字段。

@export_group("Rendering / 清晰度")
## MSAA 几何边缘抗锯齿；与 TAA 可叠加。
@export_enum("关闭:0", "2×:1", "4×:2", "8×:3") var msaa: int = Viewport.MSAA_4X:
	set(value):
		msaa = value
		_queue_apply()
## 时间抗锯齿；Forward+ 有效，FSR2 自带时间抗锯齿。
@export var taa: bool = false:
	set(value):
		taa = value
		_queue_apply()
## 屏幕空间抗锯齿。
@export_enum("关闭:0", "FXAA:1", "SMAA:2") var screen_space_aa: int = Viewport.SCREEN_SPACE_AA_DISABLED:
	set(value):
		screen_space_aa = value
		_queue_apply()
## 三维升频算法；不会缩放上层 UI。
@export_enum("Bilinear:0", "FSR 1:1", "FSR 2:2", "Nearest:5") var scaling_mode: int = Viewport.SCALING_3D_MODE_BILINEAR:
	set(value):
		scaling_mode = value
		_queue_apply()
## 三维内部渲染比例；1 为原生，超过 1 为超采样。
@export_range(0.5, 2.0, 0.05) var render_scale: float = 1.0:
	set(value):
		render_scale = value
		_queue_apply()
## FSR 锐化参数。
@export_range(0.0, 2.0, 0.05) var fsr_sharpness: float = 0.2:
	set(value):
		fsr_sharpness = value
		_queue_apply()
## 减少颜色渐变条带。
@export var debanding: bool = true:
	set(value):
		debanding = value
		_queue_apply()
## 各向异性过滤等级；用于支持此过滤方式的材质。
@export_enum("关闭:0", "2×:1", "4×:2", "8×:3", "16×:4") var anisotropic_filtering: int = Viewport.ANISOTROPY_8X:
	set(value):
		anisotropic_filtering = value
		_queue_apply()
## 纹理 mipmap 偏移；负数更锐利，也可能增加闪烁。
@export_range(-2.0, 2.0, 0.1) var mipmap_bias: float = 0.0:
	set(value):
		mipmap_bias = value
		_queue_apply()
## 网格 LOD 像素阈值；0 禁用。基础几何本身没有导入 LOD。
@export_range(0.0, 10.0, 0.1) var lod_threshold: float = 1.0:
	set(value):
		lod_threshold = value
		_queue_apply()
## 视口调试视图，默认正常渲染。
@export var debug_draw: Viewport.DebugDraw = Viewport.DEBUG_DRAW_DISABLED:
	set(value):
		debug_draw = value
		_queue_apply()
@export_group("Environment / 环境与后处理")
## 展开此资源可调天空、背景、环境光、色调映射、AO、SSIL、SSR、辉光、雾、体积雾、GI 与色彩调整。
@export var environment: Environment:
	set(value):
		environment = value
		_queue_apply()
## 展开此资源可调曝光、自动曝光、近景与远景景深。
@export var camera_attributes: CameraAttributesPractical:
	set(value):
		camera_attributes = value
		_queue_apply()
@export_group("Camera / 相机构图")
## 透视或正交投影。
@export_enum("透视:0", "正交:1") var projection: int = Camera3D.PROJECTION_PERSPECTIVE:
	set(value):
		projection = value
		_queue_apply()
## 透视垂直视角。
@export_range(20.0, 100.0, 1.0) var fov: float = 48.0:
	set(value):
		fov = value
		_queue_apply()
## 正交投影尺寸。
@export_range(2.0, 40.0, 0.1) var orthographic_size: float = 18.0:
	set(value):
		orthographic_size = value
		_queue_apply()
## 相机围绕此点观察。
@export var camera_target: Vector3 = Vector3(0.0, 1.0, 0.0):
	set(value):
		camera_target = value
		_queue_apply()
## 相机到观察点的距离。
@export_range(3.0, 50.0, 0.1) var camera_distance: float = 22.0:
	set(value):
		camera_distance = value
		_queue_apply()
## 相机水平方位角。
@export_range(-180.0, 180.0, 1.0) var camera_yaw: float = 24.0:
	set(value):
		camera_yaw = value
		_queue_apply()
## 相机俯角。
@export_range(5.0, 85.0, 1.0) var camera_pitch: float = 28.0:
	set(value):
		camera_pitch = value
		_queue_apply()
## 近裁剪距离。
@export_range(0.01, 2.0, 0.01) var camera_near: float = 0.1:
	set(value):
		camera_near = value
		_queue_apply()
## 远裁剪距离。
@export_range(30.0, 1000.0, 1.0) var camera_far: float = 200.0:
	set(value):
		camera_far = value
		_queue_apply()
@export_group("Sun / 主光与方向阴影")
## 主光颜色。
@export_color_no_alpha var sun_color: Color = Color(1.0, 0.92, 0.8):
	set(value):
		sun_color = value
		_queue_apply()
## 主光能量。
@export_range(0.0, 8.0, 0.05) var sun_energy: float = 1.2:
	set(value):
		sun_energy = value
		_queue_apply()
## 主光欧拉角，单位度。
@export var sun_rotation: Vector3 = Vector3(-48.0, -28.0, 0.0):
	set(value):
		sun_rotation = value
		_queue_apply()
## 主光真实投影。
@export var sun_shadows: bool = true:
	set(value):
		sun_shadows = value
		_queue_apply()
## 太阳角直径；0 使用 PCF，大于 0 可观察 PCSS。
@export_range(0.0, 10.0, 0.05) var sun_angular_distance: float = 0.5:
	set(value):
		sun_angular_distance = value
		_queue_apply()
## 方向阴影分割方式。
@export var sun_shadow_mode: DirectionalLight3D.ShadowMode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS:
	set(value):
		sun_shadow_mode = value
		_queue_apply()
## 阴影最大距离。
@export_range(5.0, 200.0, 1.0) var sun_shadow_distance: float = 60.0:
	set(value):
		sun_shadow_distance = value
		_queue_apply()
## 阴影深度偏移。
@export_range(0.0, 2.0, 0.01) var sun_shadow_bias: float = 0.05:
	set(value):
		sun_shadow_bias = value
		_queue_apply()
## 阴影法线偏移。
@export_range(0.0, 4.0, 0.05) var sun_normal_bias: float = 1.0:
	set(value):
		sun_normal_bias = value
		_queue_apply()
## 混合方向阴影级联边界。
@export var sun_blend_splits: bool = true:
	set(value):
		sun_blend_splits = value
		_queue_apply()
@export_group("Local Lights / 点光与聚光")
## 开启左侧蓝色点光。
@export var omni_enabled: bool = true:
	set(value):
		omni_enabled = value
		_queue_apply()
## 点光颜色。
@export_color_no_alpha var omni_color: Color = Color(0.25, 0.55, 1.0):
	set(value):
		omni_color = value
		_queue_apply()
## 点光能量。
@export_range(0.0, 16.0, 0.1) var omni_energy: float = 3.0:
	set(value):
		omni_energy = value
		_queue_apply()
## 点光影响范围。
@export_range(0.1, 30.0, 0.1) var omni_range: float = 8.0:
	set(value):
		omni_range = value
		_queue_apply()
## 点光投影。
@export var omni_shadows: bool = true:
	set(value):
		omni_shadows = value
		_queue_apply()
## 开启右侧暖色聚光。
@export var spot_enabled: bool = true:
	set(value):
		spot_enabled = value
		_queue_apply()
## 聚光颜色。
@export_color_no_alpha var spot_color: Color = Color(1.0, 0.35, 0.12):
	set(value):
		spot_color = value
		_queue_apply()
## 聚光能量。
@export_range(0.0, 16.0, 0.1) var spot_energy: float = 5.0:
	set(value):
		spot_energy = value
		_queue_apply()
## 聚光影响范围。
@export_range(0.1, 30.0, 0.1) var spot_range: float = 12.0:
	set(value):
		spot_range = value
		_queue_apply()
## 聚光锥半角。
@export_range(5.0, 85.0, 1.0) var spot_angle: float = 38.0:
	set(value):
		spot_angle = value
		_queue_apply()
## 聚光投影。
@export var spot_shadows: bool = true:
	set(value):
		spot_shadows = value
		_queue_apply()
## 点光与聚光的视口阴影图尺寸。
@export_enum("512:512", "1024:1024", "2048:2048", "4096:4096", "8192:8192") var positional_shadow_size: int = 4096:
	set(value):
		positional_shadow_size = value
		_queue_apply()
## 局部阴影图使用 16 位深度。
@export var positional_shadow_16_bits: bool = true:
	set(value):
		positional_shadow_16_bits = value
		_queue_apply()
@export_group("Samples / 材质与运动")
## 中心样品的完整材质：颜色、金属、粗糙、透明、发光、法线、采样等。
@export var sample_material: StandardMaterial3D:
	set(value):
		sample_material = value
		_queue_apply()
## 地面完整材质，可替换纹理与采样。
@export var floor_material: StandardMaterial3D:
	set(value):
		floor_material = value
		_queue_apply()
## 转动物体用于观察 TAA 拖影和高光闪烁；默认静止以便对照。
@export var animate_sample: bool = false:
	set(value):
		animate_sample = value
		_queue_apply()
## 运动样品旋转速度，度/秒。
@export_range(0.0, 180.0, 1.0) var rotation_speed: float = 35.0:
	set(value):
		rotation_speed = value
		_queue_apply()
## 运动样品固定起始角度。
@export_range(-180.0, 180.0, 1.0) var sample_angle: float = 0.0:
	set(value):
		sample_angle = value
		_queue_apply()

var _apply_queued: bool = false
var _render: SubViewport:
	get:
		return %Render
var _world: WorldEnvironment:
	get:
		return %World
var _camera: Camera3D:
	get:
		return %Camera
var _sun: DirectionalLight3D:
	get:
		return %Sun
var _omni: OmniLight3D:
	get:
		return %Omni
var _spot: SpotLight3D:
	get:
		return %Spot
var _sample: MeshInstance3D:
	get:
		return %MaterialSample
var _floor: MeshInstance3D:
	get:
		return %Floor

func _ready() -> void:
	if environment == null or camera_attributes == null or sample_material == null or floor_material == null:
		if not Engine.is_editor_hint():
			push_error("GraphicsLab requires environment, camera attributes, sample and floor materials.")
		set_process(false)
		return
	_apply_settings()

## 多个 Inspector setter 合并为一次应用；入树前的序列化由 _ready 统一应用。
func _queue_apply() -> void:
	if not is_node_ready() or _apply_queued:
		return
	_apply_queued = true
	_apply_settings.call_deferred()

func _apply_settings() -> void:
	_apply_queued = false
	if not is_inside_tree():
		return
	_render.msaa_3d = msaa as Viewport.MSAA
	_render.use_taa = taa
	_render.screen_space_aa = screen_space_aa as Viewport.ScreenSpaceAA
	_render.scaling_3d_mode = scaling_mode as Viewport.Scaling3DMode
	_render.scaling_3d_scale = render_scale
	_render.fsr_sharpness = fsr_sharpness
	_render.use_debanding = debanding
	_render.anisotropic_filtering_level = anisotropic_filtering as Viewport.AnisotropicFiltering
	_render.texture_mipmap_bias = mipmap_bias
	_render.mesh_lod_threshold = lod_threshold
	_render.debug_draw = debug_draw
	_render.positional_shadow_atlas_size = positional_shadow_size
	_render.positional_shadow_atlas_16_bits = positional_shadow_16_bits
	_world.environment = environment
	_camera.attributes = camera_attributes
	_camera.projection = projection as Camera3D.ProjectionType
	_camera.fov = fov
	_camera.size = orthographic_size
	_camera.near = camera_near
	_camera.far = camera_far
	var yaw: float = deg_to_rad(camera_yaw)
	var pitch: float = deg_to_rad(camera_pitch)
	_camera.position = camera_target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * camera_distance
	_camera.look_at(camera_target)
	_sun.light_color = sun_color
	_sun.light_energy = sun_energy
	_sun.rotation_degrees = sun_rotation
	_sun.shadow_enabled = sun_shadows
	_sun.light_angular_distance = sun_angular_distance
	_sun.directional_shadow_mode = sun_shadow_mode
	_sun.directional_shadow_max_distance = sun_shadow_distance
	_sun.shadow_bias = sun_shadow_bias
	_sun.shadow_normal_bias = sun_normal_bias
	_sun.directional_shadow_blend_splits = sun_blend_splits
	_omni.visible = omni_enabled
	_omni.light_color = omni_color
	_omni.light_energy = omni_energy
	_omni.omni_range = omni_range
	_omni.shadow_enabled = omni_shadows
	_spot.visible = spot_enabled
	_spot.light_color = spot_color
	_spot.light_energy = spot_energy
	_spot.spot_range = spot_range
	_spot.spot_angle = spot_angle
	_spot.shadow_enabled = spot_shadows
	_sample.material_override = sample_material
	_sample.rotation_degrees.y = sample_angle
	_floor.material_override = floor_material
	set_process(animate_sample)

func _process(delta: float) -> void:
	_sample.rotate_y(deg_to_rad(rotation_speed) * delta)
