## 原版协议的唯一画质实现；只接管显式登记的三维视图，不修改大厅或二维场景。
## 灯光方向、亮度、AO 半径、曝光和相机视角属于游戏美术；这里只控制性能与效果开关。
extends RefCounted

const PRESETS: Dictionary = {
	"低": {"shadow": 2048, "filter": 1, "msaa": 0, "ao": 1, "half": true, "samples": 0.5, "blur": 2},
	"中": {"shadow": 4096, "filter": 2, "msaa": 1, "ao": 2, "half": true, "samples": 0.5, "blur": 3},
	"高": {"shadow": 4096, "filter": 4, "msaa": 2, "ao": 3, "half": false, "samples": 0.75, "blur": 4},
	"极高": {"shadow": 8192, "filter": 5, "msaa": 3, "ao": 4, "half": false, "samples": 1.0, "blur": 4}
}
const KEYS: PackedStringArray = ["graphics.quality", "graphics.shadows", "graphics.pcss", "graphics.ao", "graphics.taa", "graphics.bloom", "graphics.render_scale"]
var _config: RefCounted
var _active: bool = false
var _viewport: Viewport
var _world: WorldEnvironment
var _sun: DirectionalLight3D
var _environment: Environment
var _old_viewport: Dictionary = {}
var _old_sun: Dictionary = {}
var _materials: Array[Dictionary] = []
var _globals_changed: bool = false

func configure(api: PartyAPI) -> void:
	configure_preferences(api.config)

## 仅供当前独立地图预览复用；传入正式 PartyConfig，不伪造 API 或另存一套偏好。
func configure_preferences(preferences: RefCounted) -> void:
	_config = preferences

func enter() -> Dictionary:
	_active = true
	return {"ok": true}

## 视图根可实现 godot_party_graphics_targets()，返回 world、sun 和可选 materials_root。
## 未登记的视图不受影响；每次重建视图先释放旧引用，保持共享材质不被污染。
func attach_view(view_root: Node) -> Dictionary:
	_release_view()
	if not _active or not view_root.has_method("godot_party_graphics_targets"):
		return {"ok": true, "unsupported": KEYS}
	var targets: Dictionary = view_root.godot_party_graphics_targets()
	if targets.is_empty():
		return {"ok": true, "unsupported": KEYS}
	if not targets.get("world") is WorldEnvironment or not targets.get("sun") is DirectionalLight3D:
		return {"ok": false, "message": "原版画质需要 WorldEnvironment 和 DirectionalLight3D"}
	_world = targets.world
	_sun = targets.sun
	if _world.environment == null:
		return {"ok": false, "message": "原版画质缺少 Environment 资源"}
	_viewport = view_root.get_viewport()
	for key: String in ["msaa_3d", "use_taa", "mesh_lod_threshold", "scaling_3d_scale", "scaling_3d_mode"]:
		_old_viewport[key] = _viewport.get(key)
	for key: String in ["shadow_enabled", "light_angular_distance"]:
		_old_sun[key] = _sun.get(key)
	_environment = _world.environment
	_world.environment = _environment.duplicate() as Environment
	var material_root: Node = targets.get("materials_root")
	if material_root != null:
		_prepare_materials(material_root)
	return apply(KEYS, PackedStringArray())

func apply(_common_keys: PackedStringArray, _own_keys: PackedStringArray) -> Dictionary:
	if not _active or not is_instance_valid(_viewport) or _old_viewport.is_empty():
		return {"ok": true, "unsupported": KEYS}
	var preset: Dictionary = PRESETS[_config.get_common("graphics.quality", "极高")]
	var forward_plus: bool = RenderingServer.get_current_rendering_method() == "forward_plus"
	_viewport.msaa_3d = int(preset.msaa) as Viewport.MSAA
	_viewport.use_taa = bool(_config.get_common("graphics.taa", true)) and forward_plus
	_viewport.mesh_lod_threshold = 0.0
	_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	_viewport.scaling_3d_scale = float(_config.get_common("graphics.render_scale", 1.0))
	RenderingServer.directional_shadow_atlas_set_size(int(preset.shadow), false)
	RenderingServer.directional_soft_shadow_filter_set_quality(int(preset.filter) as RenderingServer.ShadowQuality)
	RenderingServer.environment_set_ssao_quality(int(preset.ao) as RenderingServer.EnvironmentSSAOQuality, bool(preset.half), float(preset.samples), int(preset.blur), 50.0, 300.0)
	_globals_changed = true
	_sun.shadow_enabled = bool(_config.get_common("graphics.shadows", true))
	_sun.light_angular_distance = float(_old_sun.light_angular_distance) if bool(_config.get_common("graphics.pcss", false)) else 0.0
	_world.environment.ssao_enabled = bool(_config.get_common("graphics.ao", false)) and forward_plus
	_world.environment.glow_enabled = bool(_config.get_common("graphics.bloom", false))
	var applied: PackedStringArray = KEYS.duplicate()
	var unsupported: PackedStringArray = []
	if not forward_plus:
		for key: String in ["graphics.ao", "graphics.taa"]:
			applied.erase(key)
			unsupported.append(key)
	return {"ok": true, "applied": applied, "unsupported": unsupported}

## 明确登记的模型使用线性各向异性采样，避免色板最近邻条带；退出恢复原覆盖。
func _prepare_materials(root: Node) -> void:
	var copies: Dictionary[Material, Material] = {}
	var nodes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		nodes.append(root)
	for node: Node in nodes:
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.mesh == null or mesh.material_override != null:
			continue
		for index: int in range(mesh.mesh.get_surface_count()):
			var original: Material = mesh.get_active_material(index)
			if not original is BaseMaterial3D:
				continue
			if not copies.has(original):
				var copy: BaseMaterial3D = original.duplicate() as BaseMaterial3D
				copy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				copies[original] = copy
			_materials.append({"mesh": mesh, "surface": index, "previous": mesh.get_surface_override_material(index)})
			mesh.set_surface_override_material(index, copies[original])

func _release_view() -> void:
	if is_instance_valid(_viewport):
		for key: String in _old_viewport:
			_viewport.set(key, _old_viewport[key])
	if is_instance_valid(_sun):
		for key: String in _old_sun:
			_sun.set(key, _old_sun[key])
	if is_instance_valid(_world) and _environment != null:
		_world.environment = _environment
	for item: Dictionary in _materials:
		if is_instance_valid(item.mesh):
			item.mesh.set_surface_override_material(item.surface, item.previous)
	_materials.clear()
	_old_viewport.clear()
	_old_sun.clear()
	_viewport = null
	_world = null
	_sun = null
	_environment = null

	_restore_globals()

## 可重复调用；RenderingServer 全局质量恢复项目基准，作用域协调器保证唯一所有者。
func leave() -> void:
	_active = false
	_release_view()

func _restore_globals() -> void:
	if not _globals_changed:
		return
	_globals_changed = false
	RenderingServer.directional_shadow_atlas_set_size(int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size")), bool(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits")))
	RenderingServer.directional_soft_shadow_filter_set_quality(int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality")) as RenderingServer.ShadowQuality)
	RenderingServer.environment_set_ssao_quality(int(ProjectSettings.get_setting("rendering/environment/ssao/quality")) as RenderingServer.EnvironmentSSAOQuality, bool(ProjectSettings.get_setting("rendering/environment/ssao/half_size")), float(ProjectSettings.get_setting("rendering/environment/ssao/adaptive_target")), int(ProjectSettings.get_setting("rendering/environment/ssao/blur_passes")), float(ProjectSettings.get_setting("rendering/environment/ssao/fadeout_from")), float(ProjectSettings.get_setting("rendering/environment/ssao/fadeout_to")))
