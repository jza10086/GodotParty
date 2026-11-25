## Real-time single-pass analytical SDF opening animation (V2 Tactical Wireframe, 8-bit dithered).
extends ColorRect

signal finished()

const LENGTH: float = 7.51
const LOGO: float = 660.0
const LOGO_SMALL: float = 264.0
const STROKE_W: float = 14.5
const LOCKUP_GAP: float = 68.0
const TITLE_FONT_SIZE: int = 128
const TITLE_TRACKING: float = 4.5
const SUB_FONT_SIZE: int = 26
const SUB_TRACKING: int = 17

const FLOW_START: float = 0.27
const FLOW_END: float = 2.555473
const FLOW_DUR: float = FLOW_END - FLOW_START
const FLASH_START: float = 2.61
const FLASH_END: float = 3.01
const FLASH_PEAK: float = 2.83
const MOVE_START: float = 3.73
const MOVE_END: float = 4.70
const TITLE_START: float = 4.35
const TITLE_END: float = 5.20
const SUB_START: float = 4.58
const SUB_END: float = 5.38
const FADE_START: float = 6.73
const FADE_END: float = 7.30
const MAX_DIST: float = 338.25000372559646

# V2 Tactical Wireframe style constants
const TIP_STRENGTH: float = 0.52
const TIP_LEN: float = 18.0
const TIP_GLOW: float = 0.22
const JUNC_STRENGTH: float = 0.22
const JUNC_DUR: float = 0.20
const WIRE_LEAD: float = 0.24
const WIRE_WIDTH: float = 2.5
const WIRE_OPACITY: float = 0.52

const LOGO_CX_512: float = 255.81182
const LOGO_CY_512: float = 259.2625
const LOGO_W_512: float = 468.69294

# Exact 42 shared-edge segments from geometry.py: [ax, ay, bx, by, da, db]
const EDGES: Array = [
	[21.46535, 276.175, 21.46535, 343.825, 270.6, 338.25], [21.46535, 276.175, 80.05196, 242.35, 270.6, 202.95],
	[21.46535, 343.825, 80.05196, 377.65, 338.25, 270.6], [80.05196, 242.35, 138.63858, 276.175, 202.95, 135.3],
	[80.05196, 377.65, 80.05196, 445.3, 270.6, 338.25], [80.05196, 377.65, 138.63858, 343.825, 270.6, 202.95],
	[80.05196, 445.3, 138.63858, 479.125, 338.25, 270.6], [138.63858, 73.225, 138.63858, 140.875, 270.6, 202.95],
	[138.63858, 73.225, 197.2252, 39.4, 270.6, 338.25], [138.63858, 140.875, 197.2252, 174.7, 202.95, 135.3],
	[138.63858, 276.175, 138.63858, 343.825, 135.3, 202.95], [138.63858, 276.175, 197.2252, 242.35, 135.3, 67.65],
	[138.63858, 343.825, 197.2252, 377.65, 202.95, 135.3], [138.63858, 479.125, 197.2252, 445.3, 270.6, 202.95],
	[197.2252, 39.4, 255.81182, 73.225, 338.25, 270.6], [197.2252, 174.7, 197.2252, 242.35, 135.3, 67.65],
	[197.2252, 174.7, 255.81182, 140.875, 135.3, 202.95], [197.2252, 242.35, 255.81182, 276.175, 67.65, 0.0],
	[197.2252, 377.65, 197.2252, 445.3, 135.3, 202.95], [197.2252, 377.65, 255.81182, 343.825, 135.3, 67.65],
	[255.81182, 73.225, 255.81182, 140.875, 270.6, 202.95], [255.81182, 73.225, 314.39844, 39.4, 270.6, 338.25],
	[255.81182, 140.875, 314.39844, 174.7, 202.95, 135.3], [255.81182, 276.175, 255.81182, 343.825, 0.0, 67.65],
	[255.81182, 276.175, 314.39844, 242.35, 0.0, 67.65], [255.81182, 343.825, 314.39844, 377.65, 67.65, 135.3],
	[314.39844, 39.4, 372.98506, 73.225, 338.25, 270.6], [314.39844, 174.7, 314.39844, 242.35, 135.3, 67.65],
	[314.39844, 174.7, 372.98506, 140.875, 135.3, 202.95], [314.39844, 242.35, 372.98506, 276.175, 67.65, 135.3],
	[314.39844, 377.65, 314.39844, 445.3, 135.3, 202.95], [314.39844, 377.65, 372.98506, 343.825, 135.3, 202.95],
	[314.39844, 445.3, 372.98506, 479.125, 202.95, 270.6], [372.98506, 73.225, 372.98506, 140.875, 270.6, 202.95],
	[372.98506, 276.175, 372.98506, 343.825, 135.3, 202.95], [372.98506, 276.175, 431.57168, 242.35, 135.3, 202.95],
	[372.98506, 343.825, 431.57168, 377.65, 202.95, 270.6], [372.98506, 479.125, 431.57168, 445.3, 270.6, 338.25],
	[431.57168, 242.35, 490.15829, 276.175, 202.95, 270.6], [431.57168, 377.65, 431.57168, 445.3, 270.6, 338.25],
	[431.57168, 377.65, 490.15829, 343.825, 270.6, 338.25], [490.15829, 276.175, 490.15829, 343.825, 270.6, 338.25]
]

# Exact 34 unique vertices: [vx, vy, dist]
const VERTS: Array = [
	[21.46535, 276.175, 270.6], [21.46535, 343.825, 338.25], [80.05196, 242.35, 202.95], [80.05196, 377.65, 270.6],
	[80.05196, 445.3, 338.25], [138.63858, 73.225, 270.6], [138.63858, 140.875, 202.95], [138.63858, 276.175, 135.3],
	[138.63858, 343.825, 202.95], [138.63858, 479.125, 270.6], [197.2252, 39.4, 338.25], [197.2252, 174.7, 135.3],
	[197.2252, 242.35, 67.65], [197.2252, 377.65, 135.3], [197.2252, 445.3, 202.95], [255.81182, 73.225, 270.6],
	[255.81182, 140.875, 202.95], [255.81182, 276.175, 0.0], [255.81182, 343.825, 67.65], [314.39844, 39.4, 338.25],
	[314.39844, 174.7, 135.3], [314.39844, 242.35, 67.65], [314.39844, 377.65, 135.3], [314.39844, 445.3, 202.95],
	[372.98506, 73.225, 270.6], [372.98506, 140.875, 202.95], [372.98506, 276.175, 135.3], [372.98506, 343.825, 202.95],
	[372.98506, 479.125, 270.6], [431.57168, 242.35, 202.95], [431.57168, 377.65, 270.6], [431.57168, 445.3, 338.25],
	[490.15829, 276.175, 270.6], [490.15829, 343.825, 338.25]
]

@onready var _canvas: ColorRect = %Canvas
@onready var _lockup: Control = %Lockup
@onready var _title: Label = %Title
@onready var _studio: Label = %Studio
@onready var _audio: AudioStreamPlayer = %Audio

var _shader_mat: ShaderMaterial
var _title_mat: ShaderMaterial
var _studio_mat: ShaderMaterial
var _title_font_var: FontVariation
var _studio_font_var: FontVariation

var _seg_pos_buf: Array = []
var _seg_geo_buf: Array = []
var _wire_pos_buf: Array = []
var _junc_buf: Array = []
var _vert_times: PackedFloat32Array = PackedFloat32Array()

var _large_cx_ref: float = 960.0
var _large_cy_ref: float = 540.0
var _small_cx_ref: float = 569.0
var _small_cy_ref: float = 538.0
var _title_left_ref: float = 752.0
var _title_top_ref: float = 456.0
var _title_w_ref: float = 714.0
var _sub_top_ref: float = 594.0

var _playing: bool = false
var _done: bool = false
var _elapsed: float = 0.0
var _saved_max_fps: int = 0
var _fps_overridden: bool = false
var _last_layout_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_process(false)
	_shader_mat = _canvas.material as ShaderMaterial
	_title_mat = _title.material as ShaderMaterial
	_studio_mat = _studio.material as ShaderMaterial
	_seg_pos_buf.resize(64)
	_seg_geo_buf.resize(64)
	_wire_pos_buf.resize(64)
	_junc_buf.resize(34)
	for i: int in 64:
		_seg_pos_buf[i] = Vector4.ZERO
		_seg_geo_buf[i] = Vector2.ZERO
		_wire_pos_buf[i] = Vector4.ZERO
	for i: int in 34:
		_junc_buf[i] = Vector4.ZERO

	_vert_times.resize(VERTS.size())
	for i: int in VERTS.size():
		var d: float = float(VERTS[i][2])
		_vert_times[i] = FLOW_START + FLOW_DUR * _invert_scurve(d / MAX_DIST)

	_setup_typography()
	_update_layout_metrics()
	_render_at(0.0)

func _setup_typography() -> void:
	var base_bold: SystemFont = SystemFont.new()
	base_bold.font_names = PackedStringArray(["Century Gothic", "URW Gothic", "Avant Garde", "Futura", "Noto Sans", "Arial"])
	base_bold.font_weight = 700
	base_bold.multichannel_signed_distance_field = true
	base_bold.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO

	var base_reg: SystemFont = SystemFont.new()
	base_reg.font_names = PackedStringArray(["Century Gothic", "URW Gothic", "Avant Garde", "Futura", "Noto Sans", "Arial"])
	base_reg.font_weight = 400
	base_reg.multichannel_signed_distance_field = true
	base_reg.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO

	_title_font_var = FontVariation.new()
	_title_font_var.base_font = base_bold
	_title_font_var.spacing_glyph = int(round(TITLE_TRACKING))

	_studio_font_var = FontVariation.new()
	_studio_font_var.base_font = base_reg
	_studio_font_var.spacing_glyph = SUB_TRACKING

	var title_settings: LabelSettings = LabelSettings.new()
	title_settings.font = _title_font_var
	title_settings.font_size = TITLE_FONT_SIZE
	title_settings.font_color = Color(1.0, 1.0, 1.0, 1.0)
	title_settings.shadow_size = 0
	_title.label_settings = title_settings
	_title.text = "Hextrategy"

	var studio_settings: LabelSettings = LabelSettings.new()
	studio_settings.font = _studio_font_var
	studio_settings.font_size = SUB_FONT_SIZE
	studio_settings.font_color = Color(180.0 / 255.0, 200.0 / 255.0, 222.0 / 255.0, 1.0)
	studio_settings.shadow_size = 0
	_studio.label_settings = studio_settings
	_studio.text = "STUDIO"

	_title.visible = false
	_studio.visible = false

func _update_layout_metrics() -> void:
	var measured_w: float = _title_font_var.get_string_size("Hextrategy", HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FONT_SIZE).x
	_title_w_ref = maxf(measured_w, 560.0)
	var logo_w_small: float = LOGO_W_512 * (LOGO_SMALL / 512.0)
	var total_w: float = logo_w_small + LOCKUP_GAP + _title_w_ref
	var left_edge: float = 0.5 * (1920.0 - total_w)

	_large_cx_ref = 960.0 - (LOGO_CX_512 - 256.0) * (LOGO / 512.0)
	_large_cy_ref = 540.0 - (LOGO_CY_512 - 256.0) * (LOGO / 512.0)
	_small_cx_ref = (left_edge + 0.5 * logo_w_small) - (LOGO_CX_512 - 256.0) * (LOGO_SMALL / 512.0)
	_small_cy_ref = 540.0 - (LOGO_CY_512 - 256.0) * (LOGO_SMALL / 512.0)

	_title_left_ref = left_edge + logo_w_small + LOCKUP_GAP
	var title_h: float = _title_font_var.get_height(TITLE_FONT_SIZE)
	var ascent: float = _title_font_var.get_ascent(TITLE_FONT_SIZE)
	# Optical vertical center of the combined Hextrategy + STUDIO stack aligned to y = 540
	var baseline_y: float = 540.0 + ascent * 0.30
	_title_top_ref = baseline_y - ascent
	_sub_top_ref = baseline_y + maxf(28.0, (title_h - ascent) * 0.78)

	# Fix Label positions once; all motion/zoom happens in GPU floating-point vertex shader (zero jitter!)
	_title.position = Vector2(_title_left_ref, _title_top_ref)
	_studio.position = Vector2(_title_left_ref + 3.0, _sub_top_ref)
	_title_mat.set_shader_parameter("u_pivot_local", Vector2(960.0, 540.0) - _title.position)
	_studio_mat.set_shader_parameter("u_pivot_local", Vector2(960.0, 540.0) - _studio.position)
	_studio_mat.set_shader_parameter("u_wipe_edge", 10000.0)
	_studio_mat.set_shader_parameter("u_stretch_x", 1.0)

## Starts real-time playback with linear volume [0.0..1.0] and optional FPS limit (0 = unlimited).
func play(volume_linear: float = 0.3, target_fps: int = 60) -> Error:
	if _audio.stream == null:
		return ERR_CANT_OPEN
	_done = false
	_elapsed = 0.0
	_playing = true

	_saved_max_fps = Engine.max_fps
	_fps_overridden = true
	Engine.max_fps = maxi(target_fps, 0)

	var clamped: float = clampf(volume_linear, 0.0, 1.0)
	_audio.volume_db = linear_to_db(clamped) if clamped > 0.0001 else -80.0
	_audio.play()
	_render_at(0.0)
	set_process(true)
	return OK

func _process(delta: float) -> void:
	if not _playing or _done:
		return
	var next_t: float = _elapsed + delta
	if _audio.playing:
		var audio_t: float = _audio.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		# Keep timeline tightly locked to the hardware audio clock without backward jitter
		if audio_t > 0.02 and audio_t < LENGTH - 0.05:
			next_t = maxf(_elapsed, audio_t)
	_elapsed = next_t
	_render_at(_elapsed)
	if _elapsed >= LENGTH:
		_finish()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	_playing = false
	set_process(false)
	if is_instance_valid(_audio):
		_audio.stop()
	_restore_fps()
	finished.emit()

func _restore_fps() -> void:
	if _fps_overridden:
		Engine.max_fps = _saved_max_fps
		_fps_overridden = false

func _exit_tree() -> void:
	_restore_fps()

# ---------------------------------------------------------------------------
# Animation Math & Uniform Upload
# ---------------------------------------------------------------------------

static func _ease(a: float, b: float, x: float) -> float:
	var p: float = clampf((x - a) / (b - a), 0.0, 1.0)
	return p * p * (3.0 - 2.0 * p)

static func _ease_out_cubic(a: float, b: float, x: float) -> float:
	var p: float = clampf((x - a) / (b - a), 0.0, 1.0)
	return 1.0 - pow(1.0 - p, 3.0)

static func _eval_scurve(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 0.30 * u + 0.70 * (u * u * (3.0 - 2.0 * u))

static func _invert_scurve(target_y: float) -> float:
	var lo: float = 0.0
	var hi: float = 1.0
	for _i: int in 32:
		var mid: float = 0.5 * (lo + hi)
		if _eval_scurve(mid) < target_y:
			lo = mid
		else:
			hi = mid
	return 0.5 * (lo + hi)

static func _front_at(t: float) -> float:
	if t <= FLOW_START:
		return 0.0
	if t >= FLOW_END:
		return MAX_DIST + 0.01
	return _eval_scurve((t - FLOW_START) / FLOW_DUR) * MAX_DIST

func _compute_drift(t: float) -> Vector4:
	# Returns (cx_ref, cy_ref, logo_size_ref, lockup_zoom)
	var hold1: float = 1.0 + 0.022 * _ease(FLASH_PEAK, MOVE_START, t)
	var logo_at_move: float = LOGO * 1.022
	if t <= MOVE_START:
		var sz: float = LOGO * hold1
		return Vector4(
			960.0 + (_large_cx_ref - 960.0) * (sz / LOGO),
			540.0 + (_large_cy_ref - 540.0) * (sz / LOGO),
			sz,
			1.0
		)
	var lz: float = 1.0 + 0.020 * _ease(MOVE_END - 0.10, FADE_END + 0.15, t)
	if t < MOVE_END:
		var p: float = _ease(MOVE_START, MOVE_END, t)
		var b_sz: float = lerpf(logo_at_move, LOGO_SMALL, p)
		var b_cx: float = lerpf(_large_cx_ref, _small_cx_ref, p)
		var b_cy: float = lerpf(_large_cy_ref, _small_cy_ref, p)
		return Vector4(
			960.0 + (b_cx - 960.0) * lz,
			540.0 + (b_cy - 540.0) * lz,
			b_sz * lz,
			lz
		)
	return Vector4(
		960.0 + (_small_cx_ref - 960.0) * lz,
		540.0 + (_small_cy_ref - 540.0) * lz,
		LOGO_SMALL * lz,
		lz
	)

func _fill_segments(front: float, cx: float, cy: float, scale: float, out_pos: Array, out_geo: Array) -> int:
	if front <= 0.0:
		return 0
	var count: int = 0
	for i: int in EDGES.size():
		var e: Array = EDGES[i]
		var ax: float = float(e[0])
		var ay: float = float(e[1])
		var bx: float = float(e[2])
		var by: float = float(e[3])
		var da: float = float(e[4])
		var db: float = float(e[5])
		var seg_len: float = Vector2(bx - ax, by - ay).length()
		var pa: float = clampf((front - da) / seg_len, 0.0, 1.0)
		var pb: float = clampf((front - db) / seg_len, 0.0, 1.0)
		if pa >= 1.0 or pb >= 1.0 or (pa + pb) >= 1.0:
			out_pos[count] = Vector4(
				cx + (ax - 256.0) * scale, cy + (ay - 256.0) * scale,
				cx + (bx - 256.0) * scale, cy + (by - 256.0) * scale
			)
			if not out_geo.is_empty():
				out_geo[count] = Vector2(da, db)
			count += 1
		else:
			if pa > 0.0:
				out_pos[count] = Vector4(
					cx + (ax - 256.0) * scale, cy + (ay - 256.0) * scale,
					cx + (ax + (bx - ax) * pa - 256.0) * scale, cy + (ay + (by - ay) * pa - 256.0) * scale
				)
				if not out_geo.is_empty():
					out_geo[count] = Vector2(da, da + pa * seg_len)
				count += 1
			if pb > 0.0:
				out_pos[count] = Vector4(
					cx + (bx - 256.0) * scale, cy + (by - 256.0) * scale,
					cx + (bx + (ax - bx) * pb - 256.0) * scale, cy + (by + (ay - by) * pb - 256.0) * scale
				)
				if not out_geo.is_empty():
					out_geo[count] = Vector2(db, db + pb * seg_len)
				count += 1
	return count

func _render_at(t: float) -> void:
	var canvas_size: Vector2 = size if size.x > 1.0 and size.y > 1.0 else Vector2(1920.0, 1080.0)
	var unit_scale: float = minf(canvas_size.x / 1920.0, canvas_size.y / 1080.0)
	var screen_center: Vector2 = canvas_size * 0.5
	var origin: Vector2 = screen_center - Vector2(960.0, 540.0) * unit_scale

	if canvas_size != _last_layout_size:
		_last_layout_size = canvas_size
		_lockup.size = Vector2(1920.0, 1080.0)
		_lockup.pivot_offset = Vector2(960.0, 540.0)
		_lockup.position = screen_center - Vector2(960.0, 540.0)
		_lockup.scale = Vector2(unit_scale, unit_scale)

	var drift: Vector4 = _compute_drift(t)
	var cx: float = origin.x + drift.x * unit_scale
	var cy: float = origin.y + drift.y * unit_scale
	var logo_size: float = drift.z * unit_scale
	var lockup_zoom: float = drift.w
	var scale: float = logo_size / 512.0
	var radius: float = STROKE_W * scale * 0.5

	var full_static: bool = t >= 3.20
	var in_flow: bool = (not full_static) and (t < FLASH_START + 0.16)
	var front: float = (MAX_DIST + 1.0) if full_static else _front_at(t)

	var seg_count: int = _fill_segments(front, cx, cy, scale, _seg_pos_buf, _seg_geo_buf)
	var wire_count: int = 0
	var wire_opacity: float = 0.0
	if not full_static and t < FLOW_END + 0.05:
		var wf: float = _front_at(t + WIRE_LEAD)
		wire_count = _fill_segments(wf, cx, cy, scale, _wire_pos_buf, [])
		wire_opacity = WIRE_OPACITY * (1.0 - _ease(FLOW_END - 0.05, FLOW_END + 0.04, t))

	var junc_count: int = 0
	if in_flow:
		var j_rad: float = radius * 1.45
		for i: int in VERTS.size():
			var dt_j: float = t - _vert_times[i]
			if dt_j >= 0.0 and dt_j <= JUNC_DUR:
				var amp: float = (1.0 - exp(-dt_j / 0.020)) * exp(-dt_j / (JUNC_DUR * 0.34))
				amp *= (1.0 - _ease(JUNC_DUR * 0.72, JUNC_DUR, dt_j)) * JUNC_STRENGTH
				if amp > 0.006:
					var v: Array = VERTS[i]
					_junc_buf[junc_count] = Vector4(
						cx + (float(v[0]) - 256.0) * scale,
						cy + (float(v[1]) - 256.0) * scale,
						amp,
						j_rad
					)
					junc_count += 1

	var lit: float = 1.0 if full_static else _ease(FLASH_START, FLASH_END, t)
	var flash: float = 0.0 if full_static else exp(-pow((t - FLASH_PEAK) / 0.160, 2.0)) * _ease(2.61, 2.68, t)
	var amb_int: float = 0.0
	if t > FLOW_START:
		var fa: float = 0.38 * _ease(FLOW_START, FLOW_END, t)
		var la: float = 0.28 * _ease(FLASH_START, FLASH_END, t)
		var fla: float = 1.15 * exp(-pow((t - FLASH_PEAK) / 0.18, 2.0)) * _ease(2.61, 2.70, t)
		amb_int = (fa + la + fla) * (0.55 + 0.45 * (drift.z / LOGO))
	var fade: float = _ease(FADE_START, FADE_END, t) if t > FADE_START else 0.0
	var flow_fade: float = (1.0 - _ease(FLOW_END - 0.04, FLOW_END + 0.12, t)) if in_flow else 0.0

	_shader_mat.set_shader_parameter("u_canvas_size", canvas_size)
	_shader_mat.set_shader_parameter("u_logo_center", Vector2(cx, cy))
	_shader_mat.set_shader_parameter("u_logo_scale", scale)
	_shader_mat.set_shader_parameter("u_unit_scale", unit_scale)
	_shader_mat.set_shader_parameter("u_seg_count", seg_count)
	_shader_mat.set_shader_parameter("u_seg_pos", _seg_pos_buf)
	_shader_mat.set_shader_parameter("u_seg_geo", _seg_geo_buf)
	_shader_mat.set_shader_parameter("u_wire_count", wire_count)
	_shader_mat.set_shader_parameter("u_wire_pos", _wire_pos_buf)
	_shader_mat.set_shader_parameter("u_wire_radius", WIRE_WIDTH * scale * 0.5)
	_shader_mat.set_shader_parameter("u_wire_opacity", wire_opacity)
	_shader_mat.set_shader_parameter("u_junc_count", junc_count)
	_shader_mat.set_shader_parameter("u_junc", _junc_buf)
	_shader_mat.set_shader_parameter("u_radius", radius)
	_shader_mat.set_shader_parameter("u_front", front)
	_shader_mat.set_shader_parameter("u_tip_strength", TIP_STRENGTH * flow_fade)
	_shader_mat.set_shader_parameter("u_tip_len", TIP_LEN)
	_shader_mat.set_shader_parameter("u_tip_glow", TIP_GLOW)
	_shader_mat.set_shader_parameter("u_time", t)
	_shader_mat.set_shader_parameter("u_lit", lit)
	_shader_mat.set_shader_parameter("u_flash", flash)
	_shader_mat.set_shader_parameter("u_ambient_int", amb_int)
	_shader_mat.set_shader_parameter("u_fade", fade)

	# Pure GPU floating-point typography animation (never mutates GUI position/scale/spacing_glyph per frame!)
	if t >= TITLE_START:
		_title.visible = true
		var p: float = _ease_out_cubic(TITLE_START, TITLE_END, t)
		var alpha: float = _ease(TITLE_START, TITLE_START + 0.55, t) * (1.0 - fade)
		var glide_x: float = -20.0 * (1.0 - p)
		var stretch_x: float = 1.0 + 0.026 * (1.0 - p)
		var wipe_edge: float = (-140.0 + (_title_w_ref + 420.0) * p) if t < TITLE_END else 4000.0
		_title_mat.set_shader_parameter("u_glide_x", glide_x)
		_title_mat.set_shader_parameter("u_stretch_x", stretch_x)
		_title_mat.set_shader_parameter("u_zoom", lockup_zoom)
		_title_mat.set_shader_parameter("u_wipe_edge", wipe_edge)
		_title_mat.set_shader_parameter("u_wipe_width", 250.0)
		_title_mat.set_shader_parameter("u_alpha", alpha)
	else:
		_title.visible = false

	if t >= SUB_START:
		_studio.visible = true
		var ps: float = _ease_out_cubic(SUB_START, SUB_END, t)
		var sa: float = _ease(SUB_START, SUB_END, t) * (1.0 - fade)
		var s_glide: float = -12.0 * (1.0 - ps)
		_studio_mat.set_shader_parameter("u_glide_x", s_glide)
		_studio_mat.set_shader_parameter("u_zoom", lockup_zoom)
		_studio_mat.set_shader_parameter("u_alpha", sa)
	else:
		_studio.visible = false
