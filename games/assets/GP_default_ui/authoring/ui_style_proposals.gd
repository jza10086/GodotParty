## Interactive authoring showcase for unified GodotParty UI proposals:
## - Strict border rule: all borders are 0px or >= 2px (no 1px hairlines)
## - Live Corner Radius (0-24px), Rest Border (Default / 0 / 2 / 3 / 4px), Hover Border (Default / 0 / 2 / 3 / 4px)
## - Unified Hover / Gamepad-Selection state (4 states: Rest / Hover / Pressed / Disabled)
## - Standardized Open-Background vs. Card/Dialog buttons
## - 4 Input Prompt / Key Hint styles with vertical-fill wide keycap adaptation (Space / Shift / Tab / LB / RB)
## - Finalized Strong-Semantic CTA (Hollow Outlined -> Diagonal High-Saturation Fill + Enabled/Toggled State)
## Run this scene (F6) at 1920x1080; press 1-8 or click top tabs to switch views.
extends Control

const CTA_DIAG_WIPE_SHADER: Shader = preload("res://games/assets/GP_default_ui/authoring/cta_diagonal_wipe.gdshader")
const DEFAULT_AVATAR: Texture2D = preload("res://core/ui/icons/player_avatar.svg")

const ICON_KB_ARROWS: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_arrows.svg")
const ICON_KB_ENTER: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_enter.svg")
const ICON_KB_ENTER_OUT: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_enter_outline.svg")
const ICON_KB_ESC: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_escape.svg")
const ICON_KB_ESC_OUT: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_escape_outline.svg")
const ICON_KB_TAB: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_tab.svg")
const ICON_KB_TAB_OUT: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_tab_outline.svg")
const ICON_KB_SPACE: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_space.svg")
const ICON_KB_SPACE_OUT: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_space_outline.svg")
const ICON_KB_SHIFT: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_shift.svg")
const ICON_KB_SHIFT_OUT: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_shift_outline.svg")
const ICON_KB_W: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_w.svg")
const ICON_KB_W_OUT: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_w_outline.svg")
const ICON_MOUSE_L: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/mouse_left.svg")
const ICON_MOUSE_L_OUT: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/mouse_left_outline.svg")
const ICON_XB_A_COL: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/xbox/xbox_button_color_a.svg")
const ICON_XB_A_COL_OUT: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/xbox/xbox_button_color_a_outline.svg")
const ICON_XB_B_COL: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/xbox/xbox_button_color_b.svg")
const ICON_XB_B_COL_OUT: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/xbox/xbox_button_color_b_outline.svg")
const ICON_XB_X_COL: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/xbox/xbox_button_color_x.svg")
const ICON_XB_X_COL_OUT: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/xbox/xbox_button_color_x_outline.svg")
const ICON_XB_LB: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/xbox/xbox_lb.svg")
const ICON_XB_LB_OUT: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/xbox/xbox_lb_outline.svg")
const ICON_XB_RB: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/xbox/xbox_rb.svg")
const ICON_XB_RB_OUT: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/xbox/xbox_rb_outline.svg")

const BORDER_STEPS: Array[int] = [-1, 0, 2, 3, 4]

const VIEW_KEYS: Array[String] = [
	"scheme_a",
	"scheme_b",
	"scheme_c",
	"scheme_d",
	"button_matrix",
	"surface_matrix",
	"prompt_matrix",
	"cta_matrix",
]
const VIEW_LABELS: Dictionary = {
	"scheme_a": "A · 磨砂玻璃",
	"scheme_b": "B · 分层实色",
	"scheme_c": "C · 外环主机",
	"scheme_d": "D · 柔光微边",
	"button_matrix": "按钮 4 方案",
	"surface_matrix": "面板 & 悬停",
	"prompt_matrix": "按键提示",
	"cta_matrix": "强语义 CTA",
}

var _current_view: String = "scheme_a"
var _tab_buttons: Dictionary = {}
var _schemes: Dictionary = {}
var _cropped_icon_cache: Dictionary = {}

# Live tweak parameters (-1 means "use each scheme's own default"; allowed widths: 0, 2, 3, 4)
var _corner_radius: int = 8
var _rest_border_override: int = -1
var _hover_border_override: int = -1

var _radius_slider: HSlider
var _radius_value: Label
var _rest_border_slider: HSlider
var _rest_border_value: Label
var _hover_border_slider: HSlider
var _hover_border_value: Label
var _syncing_controls: bool = false


func _ready() -> void:
	_build_schemes()
	_build_top_bar()
	_build_tweak_bar()
	show_view("scheme_a")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1:
			show_view("scheme_a")
		KEY_2:
			show_view("scheme_b")
		KEY_3:
			show_view("scheme_c")
		KEY_4:
			show_view("scheme_d")
		KEY_5:
			show_view("button_matrix")
		KEY_6:
			show_view("surface_matrix")
		KEY_7:
			show_view("prompt_matrix")
		KEY_8:
			show_view("cta_matrix")


## Programmatically adjust live preview parameters (snapping any 1px to 2px per rule).
func set_live_params(radius: int, rest_border: int = -1, hover_border: int = -1) -> void:
	_corner_radius = clampi(radius, 0, 24)
	_rest_border_override = _sanitize_border(rest_border)
	_hover_border_override = _sanitize_border(hover_border)
	_sync_tweak_ui()
	_build_schemes()
	_refresh_top_tabs()
	show_view(_current_view)


func _sanitize_border(val: int) -> int:
	if val < 0:
		return -1
	if val == 0:
		return 0
	return clampi(maxi(val, 2), 2, 4)


func show_view(view_key: String) -> void:
	if not VIEW_LABELS.has(view_key):
		return
	_current_view = view_key
	_refresh_top_tabs()

	var stage: Control = %Stage as Control
	for child: Node in stage.get_children():
		child.queue_free()

	if view_key == "button_matrix":
		stage.add_child(_build_button_matrix())
	elif view_key == "surface_matrix":
		stage.add_child(_build_surface_matrix())
	elif view_key == "prompt_matrix":
		stage.add_child(_build_prompt_matrix())
	elif view_key == "cta_matrix":
		stage.add_child(_build_cta_matrix())
	else:
		stage.add_child(_build_full_scheme_preview(_schemes[view_key] as Dictionary))


func _build_top_bar() -> void:
	var bar: HBoxContainer = %TopBar as HBoxContainer
	for key: String in VIEW_KEYS:
		var btn: Button = Button.new()
		btn.text = String(VIEW_LABELS[key])
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(func() -> void: show_view(key))
		bar.add_child(btn)
		_tab_buttons[key] = btn


func _refresh_top_tabs() -> void:
	for key: String in _tab_buttons.keys():
		var btn: Button = _tab_buttons[key] as Button
		btn.button_pressed = (key == _current_view)
		_style_top_tab(btn, key == _current_view)


func _style_top_tab(btn: Button, active: bool) -> void:
	var r: int = _corner_radius
	var rb: int = _resolve_rest_border(2)
	var hb: int = _resolve_hover_border(2)
	var normal: StyleBoxFlat = _box(
		Color(0.18, 0.34, 0.48, 0.92) if active else Color(0.08, 0.12, 0.17, 0.80),
		Color(0.55, 0.80, 0.98, 0.85) if active else Color(0.55, 0.70, 0.84, 0.22),
		rb, r, 10, 6
	)
	var hover: StyleBoxFlat = _box(
		Color(0.20, 0.36, 0.50, 0.96) if active else Color(0.13, 0.19, 0.26, 0.90),
		Color(0.65, 0.86, 1.0, 0.95),
		hb, r, 10, 6
	)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("pressed", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("hover_pressed", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1) if active else Color(0.84, 0.90, 0.96, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_pressed_color", Color(1, 1, 1, 1))


func _build_tweak_bar() -> void:
	var panel: PanelContainer = %TweakBar as PanelContainer
	panel.add_theme_stylebox_override(
		"panel",
		_box(Color(0.055, 0.085, 0.13, 0.86), Color(0.55, 0.72, 0.88, 0.22), 2, 16, 20, 8)
	)
	var row: HBoxContainer = %TweakRow as HBoxContainer

	var title: Label = _make_label("实时参数（边框 0 或 ≥2px）", 16, Color(0.5843, 0.7804, 0.9255, 1.0))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)

	# 1. Corner Radius (0-24px)
	var g1: HBoxContainer = HBoxContainer.new()
	g1.add_theme_constant_override("separation", 10)
	g1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l1: Label = _make_label("圆角", 17)
	l1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_radius_slider = HSlider.new()
	_radius_slider.min_value = 0.0
	_radius_slider.max_value = 24.0
	_radius_slider.step = 1.0
	_radius_slider.value = float(_corner_radius)
	_radius_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_radius_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_radius_slider.value_changed.connect(_on_tweak_changed)
	_radius_value = _make_label("16 px", 17, Color(0.76, 0.90, 1.0, 1.0))
	_radius_value.custom_minimum_size = Vector2(58, 0)
	_radius_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g1.add_child(l1)
	g1.add_child(_radius_slider)
	g1.add_child(_radius_value)
	row.add_child(g1)

	# 2. Rest Border Width (discrete steps: Default / 0 / 2 / 3 / 4px)
	var g2: HBoxContainer = HBoxContainer.new()
	g2.add_theme_constant_override("separation", 10)
	g2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l2: Label = _make_label("常态边框", 17)
	l2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rest_border_slider = HSlider.new()
	_rest_border_slider.min_value = 0.0
	_rest_border_slider.max_value = float(BORDER_STEPS.size() - 1)
	_rest_border_slider.step = 1.0
	_rest_border_slider.value = 0.0
	_rest_border_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rest_border_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rest_border_slider.value_changed.connect(_on_tweak_changed)
	_rest_border_value = _make_label("默认", 17, Color(0.76, 0.90, 1.0, 1.0))
	_rest_border_value.custom_minimum_size = Vector2(58, 0)
	_rest_border_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g2.add_child(l2)
	g2.add_child(_rest_border_slider)
	g2.add_child(_rest_border_value)
	row.add_child(g2)

	# 3. Hover Border Width (discrete steps: Default / 0 / 2 / 3 / 4px)
	var g3: HBoxContainer = HBoxContainer.new()
	g3.add_theme_constant_override("separation", 10)
	g3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l3: Label = _make_label("悬停边框", 17)
	l3.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hover_border_slider = HSlider.new()
	_hover_border_slider.min_value = 0.0
	_hover_border_slider.max_value = float(BORDER_STEPS.size() - 1)
	_hover_border_slider.step = 1.0
	_hover_border_slider.value = 0.0
	_hover_border_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hover_border_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hover_border_slider.value_changed.connect(_on_tweak_changed)
	_hover_border_value = _make_label("默认", 17, Color(0.76, 0.90, 1.0, 1.0))
	_hover_border_value.custom_minimum_size = Vector2(58, 0)
	_hover_border_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g3.add_child(l3)
	g3.add_child(_hover_border_slider)
	g3.add_child(_hover_border_value)
	row.add_child(g3)

	# Quick presets (all 0px or >=2px)
	for preset: Array in [["8px/2px", 8, 2, 2], ["16px/0+2", 16, 0, 2], ["16px/默认", 16, -1, -1], ["20px/3px", 20, 2, 3]]:
		var pbtn: Button = Button.new()
		pbtn.text = String(preset[0])
		pbtn.custom_minimum_size = Vector2(96, 34)
		pbtn.add_theme_font_size_override("font_size", 15)
		var pn: StyleBoxFlat = _box(Color(0.12, 0.18, 0.25, 0.85), Color(0.55, 0.72, 0.88, 0.28), 2, 10, 10, 4)
		var ph: StyleBoxFlat = _box(Color(0.18, 0.28, 0.39, 0.95), Color(0.58, 0.82, 1.0, 0.85), 2, 10, 10, 4)
		pbtn.add_theme_stylebox_override("normal", pn)
		pbtn.add_theme_stylebox_override("hover", ph)
		pbtn.add_theme_stylebox_override("focus", ph)
		pbtn.add_theme_stylebox_override("pressed", pn)
		var r_val: int = int(preset[1])
		var rb_val: int = int(preset[2])
		var hb_val: int = int(preset[3])
		pbtn.pressed.connect(func() -> void: set_live_params(r_val, rb_val, hb_val))
		row.add_child(pbtn)

	_sync_tweak_ui()


func _border_step_index(border_val: int) -> int:
	var idx: int = BORDER_STEPS.find(border_val)
	return idx if idx >= 0 else 0


func _sync_tweak_ui() -> void:
	_syncing_controls = true
	if _radius_slider != null:
		_radius_slider.value = float(_corner_radius)
		_radius_value.text = str(_corner_radius) + " px"
	if _rest_border_slider != null:
		_rest_border_slider.value = float(_border_step_index(_rest_border_override))
		_rest_border_value.text = "默认" if _rest_border_override < 0 else (str(_rest_border_override) + " px")
	if _hover_border_slider != null:
		_hover_border_slider.value = float(_border_step_index(_hover_border_override))
		_hover_border_value.text = "默认" if _hover_border_override < 0 else (str(_hover_border_override) + " px")
	_syncing_controls = false


func _on_tweak_changed(_value: float) -> void:
	if _syncing_controls:
		return
	_corner_radius = int(_radius_slider.value)
	_rest_border_override = BORDER_STEPS[int(_rest_border_slider.value)]
	_hover_border_override = BORDER_STEPS[int(_hover_border_slider.value)]
	_sync_tweak_ui()
	_build_schemes()
	_refresh_top_tabs()
	show_view(_current_view)


func _resolve_rest_border(default_w: int) -> int:
	return default_w if _rest_border_override < 0 else _rest_border_override


func _resolve_hover_border(default_w: int) -> int:
	return default_w if _hover_border_override < 0 else _hover_border_override


func _box(
	bg: Color,
	border: Color,
	border_w: int,
	radius: int,
	pad_x: float = 16.0,
	pad_y: float = 10.0,
	shadow_size: int = 0,
	shadow_alpha: float = 0.0,
	expand: float = 0.0,
	shadow_color_override: Color = Color(0, 0, 0, -1.0),
	shadow_offset: Vector2 = Vector2.ZERO
) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.corner_detail = 16
	s.anti_aliasing = true
	s.anti_aliasing_size = 1.25
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	if shadow_size > 0:
		s.shadow_size = shadow_size
		if shadow_color_override.a >= 0.0:
			s.shadow_color = shadow_color_override
		else:
			s.shadow_color = Color(0.0, 0.0, 0.0, shadow_alpha)
		s.shadow_offset = shadow_offset
	if expand != 0.0:
		s.expand_margin_left = expand
		s.expand_margin_right = expand
		s.expand_margin_top = expand
		s.expand_margin_bottom = expand
	return s


func _build_schemes() -> void:
	var r: int = _corner_radius

	# Scheme A: Cosmic Frost Glass (strictly 2px soft borders, zero 1px!)
	var a_rb: int = _resolve_rest_border(2)
	var a_hb: int = _resolve_hover_border(2)
	_schemes["scheme_a"] = {
		"id": "scheme_a",
		"name": "方案 A · 星际磨砂玻璃",
		"tag": "84% 磨砂透底 + 2px 冰蓝柔光边 | 悬停统一：2px 亮冰蓝边 + 轻提亮",
		"prompt_style": "glass_outline",
		"prompt_desc": "风格 1 · 悬浮磨砂胶囊条 + 线性描边图标",
		"panel": _box(Color(0.055, 0.095, 0.145, 0.84), Color(0.62, 0.80, 0.96, 0.24), a_rb, r, 24, 18, 20, 0.28),
		"subpanel": _box(Color(0.035, 0.065, 0.105, 0.65), Color(0.58, 0.78, 0.94, 0.16), a_rb, r, 16, 12),
		"overlay": _box(Color(0.045, 0.085, 0.135, 0.76), Color(0.65, 0.82, 0.96, 0.22), a_rb, r, 16, 12),
		"input_normal": _box(Color(0.035, 0.062, 0.100, 0.72), Color(0.58, 0.78, 0.94, 0.22), a_rb, r, 16, 8),
		"input_hover": _box(Color(0.055, 0.105, 0.165, 0.88), Color(0.48, 0.78, 1.0, 0.92), a_hb, r, 16, 8),
		"open_normal": _box(Color(1, 1, 1, 0), Color(1, 1, 1, 0), 0, r, 16, 10),
		"open_hover": _box(Color(0.11, 0.20, 0.30, 0.80), Color(0.52, 0.82, 1.0, 0.92), a_hb, r, 16, 10),
		"open_pressed": _box(Color(0.08, 0.15, 0.23, 0.88), Color(0.52, 0.82, 1.0, 0.80), a_hb, r, 16, 10),
		"open_disabled": _box(Color(1, 1, 1, 0), Color(1, 1, 1, 0), 0, r, 16, 10),
		"card_normal": _box(Color(0.13, 0.20, 0.29, 0.64), Color(0.62, 0.80, 0.96, 0.28), a_rb, r, 16, 10),
		"card_hover": _box(Color(0.18, 0.29, 0.41, 0.86), Color(0.48, 0.80, 1.0, 0.95), a_hb, r, 16, 10),
		"card_pressed": _box(Color(0.10, 0.17, 0.25, 0.88), Color(0.52, 0.80, 1.0, 0.80), a_hb, r, 16, 10),
		"card_disabled": _box(Color(0.09, 0.13, 0.19, 0.42), Color(0.55, 0.70, 0.84, 0.14), a_rb, r, 16, 10),
		"primary_normal": _box(Color(0.16, 0.36, 0.54, 0.88), Color(0.54, 0.82, 1.0, 0.65), a_rb, r, 16, 10),
		"primary_hover": _box(Color(0.21, 0.45, 0.67, 0.98), Color(0.76, 0.93, 1.0, 1.0), a_hb, r, 16, 10),
		"primary_pressed": _box(Color(0.13, 0.30, 0.46, 0.95), Color(0.58, 0.84, 1.0, 0.85), a_hb, r, 16, 10),
		"primary_disabled": _box(Color(0.13, 0.21, 0.30, 0.45), Color(0.48, 0.65, 0.80, 0.18), a_rb, r, 16, 10),
		"primary_font": Color(1, 1, 1, 1),
		"use_outset_hover": false,
	}

	# Scheme B: Elevated Slate (0px borderless at rest, 2px crisp cold blue on hover)
	var b_rb: int = _resolve_rest_border(0)
	var b_hb: int = _resolve_hover_border(2)
	_schemes["scheme_b"] = {
		"id": "scheme_b",
		"name": "方案 B · 深空分层实色",
		"tag": "96% 实色明度阶梯 + 常态 0px 全无框 | 悬停统一：明度跃升 + 2px 冷蓝框",
		"prompt_style": "solid_filled",
		"prompt_desc": "风格 2 · 宽幅实色底条 + 高对比实心键帽图标",
		"panel": _box(Color(0.085, 0.125, 0.175, 0.96), Color(0.28, 0.39, 0.50, 0.45), b_rb, r, 24, 18, 24, 0.35),
		"subpanel": _box(Color(0.12, 0.17, 0.23, 1.0), Color(0.32, 0.42, 0.54, 0.35), b_rb, r, 16, 12),
		"overlay": _box(Color(0.075, 0.11, 0.155, 0.92), Color(0.28, 0.39, 0.50, 0.45), b_rb, r, 16, 12),
		"input_normal": _box(Color(0.165, 0.225, 0.295, 1.0), Color(0.34, 0.44, 0.55, 0.45), b_rb, r, 16, 8),
		"input_hover": _box(Color(0.21, 0.285, 0.37, 1.0), Color(0.48, 0.68, 0.86, 1.0), b_hb, r, 16, 8),
		"open_normal": _box(Color(1, 1, 1, 0), Color(1, 1, 1, 0), 0, r, 16, 10),
		"open_hover": _box(Color(0.18, 0.25, 0.33, 0.98), Color(0.48, 0.68, 0.86, 1.0), b_hb, r, 16, 10),
		"open_pressed": _box(Color(0.12, 0.175, 0.235, 1.0), Color(0.42, 0.60, 0.76, 1.0), b_hb, r, 16, 10),
		"open_disabled": _box(Color(1, 1, 1, 0), Color(1, 1, 1, 0), 0, r, 16, 10),
		"card_normal": _box(Color(0.195, 0.26, 0.335, 1.0), Color(0.36, 0.46, 0.58, 0.45), b_rb, r, 16, 10),
		"card_hover": _box(Color(0.255, 0.34, 0.43, 1.0), Color(0.50, 0.70, 0.88, 1.0), b_hb, r, 16, 10),
		"card_pressed": _box(Color(0.155, 0.215, 0.285, 1.0), Color(0.45, 0.64, 0.80, 1.0), b_hb, r, 16, 10),
		"card_disabled": _box(Color(0.14, 0.19, 0.25, 0.75), Color(0.26, 0.34, 0.44, 0.25), b_rb, r, 16, 10),
		"primary_normal": _box(Color(0.21, 0.44, 0.63, 1.0), Color(0.48, 0.72, 0.92, 0.55), b_rb, r, 16, 10),
		"primary_hover": _box(Color(0.27, 0.53, 0.75, 1.0), Color(0.72, 0.89, 1.0, 1.0), b_hb, r, 16, 10),
		"primary_pressed": _box(Color(0.17, 0.37, 0.54, 1.0), Color(0.56, 0.78, 0.95, 1.0), b_hb, r, 16, 10),
		"primary_disabled": _box(Color(0.16, 0.24, 0.32, 0.70), Color(0.30, 0.40, 0.50, 0.25), b_rb, r, 16, 10),
		"primary_font": Color(1, 1, 1, 1),
		"use_outset_hover": false,
	}

	# Scheme C: Console Ring (2px rest, 2px bright white outset hover)
	var c_rb: int = _resolve_rest_border(2)
	var c_hb: int = _resolve_hover_border(2)
	_schemes["scheme_c"] = {
		"id": "scheme_c",
		"name": "方案 C · 锐利外环主机风",
		"tag": "94% 深午夜蓝板 + 2px 沉稳边 | 悬停统一：2px 高对比亮白外环",
		"prompt_style": "bare_keycaps",
		"prompt_desc": "风格 3 · 无底条裸浮 + 立体深色键帽徽章",
		"panel": _box(Color(0.07, 0.095, 0.135, 0.94), Color(0.30, 0.40, 0.52, 0.46), c_rb, r, 24, 18, 26, 0.38),
		"subpanel": _box(Color(0.045, 0.068, 0.10, 0.92), Color(0.26, 0.36, 0.48, 0.36), c_rb, r, 16, 12),
		"overlay": _box(Color(0.05, 0.075, 0.11, 0.90), Color(0.32, 0.46, 0.60, 0.48), c_rb, r, 16, 12),
		"input_normal": _box(Color(0.045, 0.068, 0.10, 0.96), Color(0.28, 0.38, 0.50, 0.55), c_rb, r, 16, 8),
		"input_hover": _box(Color(0.07, 0.11, 0.16, 1.0), Color(0.90, 0.96, 1.0, 0.94), c_hb, r, 16, 8),
		"open_normal": _box(Color(1, 1, 1, 0), Color(1, 1, 1, 0), 0, r, 16, 10),
		"open_hover": _box(Color(0.15, 0.22, 0.31, 0.90), Color(0.92, 0.97, 1.0, 0.96), c_hb, r, 16, 10),
		"open_pressed": _box(Color(0.10, 0.16, 0.23, 0.92), Color(0.75, 0.88, 1.0, 0.80), c_hb, r, 16, 10),
		"open_disabled": _box(Color(1, 1, 1, 0), Color(1, 1, 1, 0), 0, r, 16, 10),
		"card_normal": _box(Color(0.145, 0.20, 0.27, 1.0), Color(0.30, 0.40, 0.52, 0.52), c_rb, r, 16, 10),
		"card_hover": _box(Color(0.19, 0.26, 0.35, 1.0), Color(0.92, 0.97, 1.0, 0.96), c_hb, r, 16, 10),
		"card_pressed": _box(Color(0.11, 0.16, 0.22, 1.0), Color(0.75, 0.88, 1.0, 0.85), c_hb, r, 16, 10),
		"card_disabled": _box(Color(0.10, 0.14, 0.19, 0.60), Color(0.24, 0.30, 0.38, 0.28), c_rb, r, 16, 10),
		"primary_normal": _box(Color(0.24, 0.56, 0.80, 1.0), Color(0.45, 0.76, 0.98, 0.55), c_rb, r, 16, 10),
		"primary_hover": _box(Color(0.30, 0.63, 0.88, 1.0), Color(1.0, 1.0, 1.0, 0.96), c_hb, r, 16, 10),
		"primary_pressed": _box(Color(0.19, 0.47, 0.69, 1.0), Color(0.85, 0.94, 1.0, 0.85), c_hb, r, 16, 10),
		"primary_disabled": _box(Color(0.15, 0.25, 0.34, 0.55), Color(0.28, 0.40, 0.52, 0.22), c_rb, r, 16, 10),
		"primary_font": Color(0.04, 0.08, 0.14, 1.0),
		"use_outset_hover": true,
	}

	# Scheme D: Soft Ambient (2px ultra-soft white rest, 2px soft ice-blue hover)
	var d_rb: int = _resolve_rest_border(2)
	var d_hb: int = _resolve_hover_border(2)
	_schemes["scheme_d"] = {
		"id": "scheme_d",
		"name": "方案 D · 柔光微边平衡风",
		"tag": "92% 深蓝炭板 + 2px 轻白柔边 | 悬停统一：2px 柔和冰蓝内框 + 轻提亮",
		"prompt_style": "pill_chips",
		"prompt_desc": "风格 4 · 轻白光分组独立胶囊 + 柔色描边图标",
		"panel": _box(Color(0.08, 0.115, 0.16, 0.92), Color(0.85, 0.92, 1.0, 0.14), d_rb, r, 24, 18, 30, 0.32),
		"subpanel": _box(Color(0.03, 0.05, 0.08, 0.55), Color(0.85, 0.92, 1.0, 0.10), d_rb, r, 16, 12),
		"overlay": _box(Color(0.06, 0.09, 0.13, 0.84), Color(0.85, 0.92, 1.0, 0.15), d_rb, r, 16, 12),
		"input_normal": _box(Color(0.035, 0.055, 0.088, 0.68), Color(0.85, 0.92, 1.0, 0.14), d_rb, r, 16, 8),
		"input_hover": _box(Color(0.06, 0.095, 0.145, 0.86), Color(0.54, 0.80, 0.98, 0.88), d_hb, r, 16, 8),
		"open_normal": _box(Color(1, 1, 1, 0), Color(1, 1, 1, 0), 0, r, 16, 10),
		"open_hover": _box(Color(0.85, 0.93, 1.0, 0.13), Color(0.54, 0.80, 0.98, 0.88), d_hb, r, 16, 10),
		"open_pressed": _box(Color(0.85, 0.93, 1.0, 0.07), Color(0.54, 0.80, 0.98, 0.72), d_hb, r, 16, 10),
		"open_disabled": _box(Color(1, 1, 1, 0), Color(1, 1, 1, 0), 0, r, 16, 10),
		"card_normal": _box(Color(0.85, 0.93, 1.0, 0.08), Color(0.85, 0.93, 1.0, 0.15), d_rb, r, 16, 10),
		"card_hover": _box(Color(0.85, 0.93, 1.0, 0.16), Color(0.54, 0.80, 0.98, 0.88), d_hb, r, 16, 10),
		"card_pressed": _box(Color(0.85, 0.93, 1.0, 0.06), Color(0.54, 0.80, 0.98, 0.75), d_hb, r, 16, 10),
		"card_disabled": _box(Color(0.85, 0.93, 1.0, 0.04), Color(0.85, 0.93, 1.0, 0.08), d_rb, r, 16, 10),
		"primary_normal": _box(Color(0.23, 0.50, 0.72, 0.96), Color(0.72, 0.89, 1.0, 0.40), d_rb, r, 16, 10),
		"primary_hover": _box(Color(0.29, 0.58, 0.82, 1.0), Color(0.78, 0.93, 1.0, 0.96), d_hb, r, 16, 10),
		"primary_pressed": _box(Color(0.18, 0.42, 0.62, 1.0), Color(0.68, 0.86, 1.0, 0.75), d_hb, r, 16, 10),
		"primary_disabled": _box(Color(0.20, 0.33, 0.45, 0.45), Color(0.60, 0.76, 0.90, 0.14), d_rb, r, 16, 10),
		"primary_font": Color(1, 1, 1, 1),
		"use_outset_hover": false,
	}


func _apply_btn(btn: Button, scheme: Dictionary, kind: String, force_state: String = "") -> void:
	var normal_s: StyleBox = scheme[kind + "_normal"] as StyleBox
	var hover_s: StyleBox = scheme[kind + "_hover"] as StyleBox
	var pressed_s: StyleBox = scheme[kind + "_pressed"] as StyleBox
	var disabled_s: StyleBox = scheme[kind + "_disabled"] as StyleBox

	var live_hover: StyleBox = hover_s
	if bool(scheme.get("use_outset_hover", false)):
		var out_s: StyleBoxFlat = (hover_s as StyleBoxFlat).duplicate() as StyleBoxFlat
		out_s.expand_margin_left = 2.0
		out_s.expand_margin_right = 2.0
		out_s.expand_margin_top = 2.0
		out_s.expand_margin_bottom = 2.0
		live_hover = out_s

	if force_state == "hover":
		btn.add_theme_stylebox_override("normal", live_hover)
	elif force_state == "pressed":
		btn.add_theme_stylebox_override("normal", pressed_s)
	elif force_state == "disabled":
		btn.disabled = true
		btn.add_theme_stylebox_override("disabled", disabled_s)
		btn.add_theme_stylebox_override("normal", disabled_s)
	else:
		btn.add_theme_stylebox_override("normal", normal_s)

	btn.add_theme_stylebox_override("hover", live_hover)
	btn.add_theme_stylebox_override("focus", live_hover)
	btn.add_theme_stylebox_override("pressed", pressed_s)
	btn.add_theme_stylebox_override("disabled", disabled_s)

	var text_col: Color = Color(0.96, 0.97, 0.99, 1.0)
	if kind == "primary":
		text_col = scheme["primary_font"] as Color
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_focus_color", text_col)
	btn.add_theme_color_override("font_pressed_color", Color(0.5843, 0.7804, 0.9255, 1.0) if kind != "primary" else text_col)
	btn.add_theme_color_override("font_disabled_color", Color(0.60, 0.64, 0.70, 0.65))


func _cta_palette(color_key: String) -> Dictionary:
	# High-saturation glow-free CTA palettes matching finalized Motion 5
	match color_key:
		"green":
			return {
				"bright": Color(0.24, 0.77, 0.47, 1.0),
				"pressed": Color(0.16, 0.56, 0.34, 1.0),
				"outline": Color(0.32, 0.86, 0.54, 1.0),
				"ink": Color(1.0, 1.0, 1.0, 1.0),
			}
		"orange":
			return {
				"bright": Color(0.96, 0.61, 0.18, 1.0),
				"pressed": Color(0.74, 0.44, 0.11, 1.0),
				"outline": Color(1.0, 0.72, 0.28, 1.0),
				"ink": Color(1.0, 1.0, 1.0, 1.0),
			}
		"blue":
			return {
				"bright": Color(0.24, 0.59, 0.95, 1.0),
				"pressed": Color(0.15, 0.43, 0.74, 1.0),
				"outline": Color(0.38, 0.74, 1.0, 1.0),
				"ink": Color(1.0, 1.0, 1.0, 1.0),
			}
		_: # red
			return {
				"bright": Color(0.90, 0.29, 0.34, 1.0),
				"pressed": Color(0.68, 0.19, 0.23, 1.0),
				"outline": Color(0.98, 0.42, 0.46, 1.0),
				"ink": Color(1.0, 1.0, 1.0, 1.0),
			}


const CTA_SLANT_PX: float = 36.0
const CTA_EDGE_SOFTNESS: float = 1.5
const CTA_HOVER_TOP_OVERHANG_PX: float = 4.0


func _cta_unenabled_hover_progress(btn_width: float) -> float:
	# Stops the diagonal cutoff at (W + overhang), so the top-right corner stays filled
	# while leaving a crisp ~32px hollow diagonal triangle in the bottom-right corner.
	var w: float = maxf(btn_width, 96.0)
	var span: float = w + CTA_SLANT_PX + CTA_EDGE_SOFTNESS * 2.0
	var target_cutoff: float = w + CTA_HOVER_TOP_OVERHANG_PX
	return clampf((target_cutoff + CTA_EDGE_SOFTNESS) / maxf(span, 1.0), 0.72, 0.96)


## Finalized Strong-Semantic CTA (Motion 5):
## - Rest (un-enabled): transparent dark interior + >=2px semantic outline + semantic-colored caption
## - Hover (un-enabled): diagonal high-saturation fill stops short, leaving a hollow bottom-right triangle
## - Enabled (and Enabled Hover): 100% completely filled (bottom-right corner snaps shut); click again to toggle off
## - Disabled: low-opacity outline + muted gray text
func _make_cta_button(
	color_key: String,
	label_text: String,
	force_state: String = "",
	font_size: int = 19,
	min_h: int = 48,
	interactive_toggle: bool = true
) -> Control:
	var slot: Control = Control.new()
	slot.custom_minimum_size = Vector2(0, min_h)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var pal: Dictionary = _cta_palette(color_key)
	var r: int = _corner_radius
	var bright_col: Color = pal["bright"] as Color
	var pressed_col: Color = pal["pressed"] as Color
	var outline_col: Color = pal["outline"] as Color
	var ink_col: Color = pal["ink"] as Color
	var dis_ink: Color = Color(0.70, 0.75, 0.82, 0.58)
	var hollow_bw: int = maxi(_resolve_rest_border(2), 2)

	var btn: Button = Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.text = ""
	btn.focus_mode = Control.FOCUS_ALL
	btn.toggle_mode = interactive_toggle and force_state in ["", "enabled"]
	btn.button_pressed = (force_state == "enabled")
	slot.add_child(btn)

	var hollow_bg: Color = Color(0.03, 0.055, 0.09, 0.42)
	var sn: StyleBoxFlat = _box(hollow_bg, outline_col, hollow_bw, r, 12, 6)
	var sp: StyleBoxFlat = _box(pressed_col, pressed_col, hollow_bw, r, 12, 6)
	var sd: StyleBoxFlat = _box(
		Color(0.04, 0.06, 0.10, 0.35),
		Color(outline_col.r, outline_col.g, outline_col.b, 0.25),
		hollow_bw, r, 12, 6
	)

	if force_state == "disabled":
		btn.disabled = true
		btn.add_theme_stylebox_override("normal", sd)
		btn.add_theme_stylebox_override("disabled", sd)
	else:
		btn.add_theme_stylebox_override("normal", sn)
		btn.add_theme_stylebox_override("hover", sn)
		btn.add_theme_stylebox_override("hover_pressed", sn)
		btn.add_theme_stylebox_override("focus", sn)
		btn.add_theme_stylebox_override("pressed", sp if not btn.toggle_mode else sn)
		btn.add_theme_stylebox_override("disabled", sd)

	# Base caption (semantic bright ink on hollow rest)
	var base_lbl_col: Color = dis_ink if force_state == "disabled" else outline_col
	var lbl: Label = _make_label(label_text, font_size, base_lbl_col)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)

	# Diagonal-wiped high-saturation layer + inverted white caption
	var wipe_mat: ShaderMaterial = null
	var fill_bg: ColorRect = null
	var state_box: Dictionary = {"hovered": false, "tween": null}
	if force_state != "disabled":
		var upper_mask: Panel = Panel.new()
		upper_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
		upper_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		upper_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		upper_mask.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 1), Color(0, 0, 0, 0), 0, r, 0, 0))
		btn.add_child(upper_mask)

		wipe_mat = ShaderMaterial.new()
		wipe_mat.shader = CTA_DIAG_WIPE_SHADER
		var init_prog: float = 0.0
		if force_state == "enabled":
			init_prog = 1.0
		elif force_state == "hover":
			init_prog = _cta_unenabled_hover_progress(200.0)
		elif force_state == "mid":
			init_prog = 0.55
		wipe_mat.set_shader_parameter("fill_progress", init_prog)
		wipe_mat.set_shader_parameter("rect_size", Vector2(200.0, float(min_h)))
		wipe_mat.set_shader_parameter("slant_px", CTA_SLANT_PX)
		wipe_mat.set_shader_parameter("edge_softness", CTA_EDGE_SOFTNESS)

		fill_bg = ColorRect.new()
		fill_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		fill_bg.color = bright_col
		fill_bg.material = wipe_mat
		fill_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		upper_mask.add_child(fill_bg)

		var inv_lbl: Label = _make_label(label_text, font_size, ink_col)
		inv_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		inv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inv_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		inv_lbl.material = wipe_mat
		inv_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		upper_mask.add_child(inv_lbl)

	btn.resized.connect(func() -> void:
		btn.pivot_offset = btn.size * 0.5
		if wipe_mat != null:
			wipe_mat.set_shader_parameter("rect_size", btn.size)
			if force_state == "hover":
				wipe_mat.set_shader_parameter("fill_progress", _cta_unenabled_hover_progress(btn.size.x))
			elif bool(state_box["hovered"]) and not btn.button_pressed and force_state in ["", "enabled"]:
				wipe_mat.set_shader_parameter("fill_progress", _cta_unenabled_hover_progress(btn.size.x))
	)
	if wipe_mat != null:
		btn.call_deferred("emit_signal", "resized")

	# Interactive Hover (partial bottom-right corner left open) + Click-to-Toggle Enabled (100% full)
	if force_state != "disabled" and force_state not in ["hover", "mid"]:
		var animate_fill: Callable = func(target: float, duration: float) -> void:
			if wipe_mat == null:
				return
			wipe_mat.set_shader_parameter("rect_size", btn.size)
			var prev: Variant = state_box.get("tween")
			if prev is Tween and (prev as Tween).is_valid():
				(prev as Tween).kill()
			var cur_p: float = float(wipe_mat.get_shader_parameter("fill_progress"))
			var tw: Tween = btn.create_tween().set_trans(Tween.TRANS_CUBIC if target > cur_p else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_method(func(v: float) -> void: wipe_mat.set_shader_parameter("fill_progress", v), cur_p, target, duration)
			state_box["tween"] = tw

		var sync_fill: Callable = func() -> void:
			var target_p: float = 0.0
			var dur: float = 0.18
			if btn.button_pressed:
				target_p = 1.0
				dur = 0.14 if bool(state_box["hovered"]) else 0.20
			elif bool(state_box["hovered"]):
				target_p = _cta_unenabled_hover_progress(btn.size.x)
				dur = 0.20
			animate_fill.call(target_p, dur)

		btn.mouse_entered.connect(func() -> void:
			state_box["hovered"] = true
			sync_fill.call()
		)
		btn.focus_entered.connect(func() -> void:
			state_box["hovered"] = true
			sync_fill.call()
		)
		btn.mouse_exited.connect(func() -> void:
			state_box["hovered"] = false
			sync_fill.call()
		)
		btn.focus_exited.connect(func() -> void:
			state_box["hovered"] = false
			sync_fill.call()
		)
		btn.toggled.connect(func(_on: bool) -> void:
			sync_fill.call()
		)
		btn.button_down.connect(func() -> void:
			btn.pivot_offset = btn.size * 0.5
			var tw_d: Tween = btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_d.tween_property(btn, "scale", Vector2(0.97, 0.97), 0.07)
			if fill_bg != null:
				fill_bg.color = pressed_col
		)
		btn.button_up.connect(func() -> void:
			btn.pivot_offset = btn.size * 0.5
			var tw_u: Tween = btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_u.tween_property(btn, "scale", Vector2.ONE, 0.12)
			if fill_bg != null:
				fill_bg.color = bright_col
		)

	return slot


func _make_label(text: String, size: int = 20, col: Color = Color(0.96, 0.97, 0.99, 1.0)) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	return lbl


## Crops away unused transparent margins in Kenney 64x64 SVGs so wide keys
## (Space, Shift, Tab, LB, RB) vertically fill the exact same cap height as single keys (W, Esc, A).
func _get_cropped_icon(tex: Texture2D) -> Dictionary:
	if _cropped_icon_cache.has(tex):
		return _cropped_icon_cache[tex] as Dictionary

	var result: Dictionary = {"texture": tex, "aspect": 1.0}
	var img: Image = tex.get_image()
	if img != null:
		var used: Rect2i = img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			var pad: int = 1
			var x0: int = maxi(used.position.x - pad, 0)
			var y0: int = maxi(used.position.y - pad, 0)
			var x1: int = mini(used.end.x + pad, img.get_width())
			var y1: int = mini(used.end.y + pad, img.get_height())
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(float(x0), float(y0), float(x1 - x0), float(y1 - y0))
			atlas.filter_clip = true
			result["texture"] = atlas
			result["aspect"] = float(x1 - x0) / maxf(float(y1 - y0), 1.0)

	_cropped_icon_cache[tex] = result
	return result


func _make_prompt_icon(tex: Texture2D, tint: Color = Color(1, 1, 1, 1), target_height: int = 28) -> TextureRect:
	var info: Dictionary = _get_cropped_icon(tex)
	var cropped: Texture2D = info["texture"] as Texture2D
	var aspect: float = float(info["aspect"])
	var w: float = roundf(float(target_height) * aspect)

	var tr: TextureRect = TextureRect.new()
	tr.texture = cropped
	tr.modulate = tint
	tr.custom_minimum_size = Vector2(w, float(target_height))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return tr


func _make_keycap_badge(text: String, target_height: int = 28, accent_col: Color = Color(0.86, 0.93, 1.0, 1.0)) -> PanelContainer:
	var cap: PanelContainer = PanelContainer.new()
	cap.custom_minimum_size = Vector2(float(target_height), float(target_height))
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.11, 0.15, 0.21, 0.96)
	s.border_color = Color(0.68, 0.78, 0.90, 0.65)
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 4
	s.set_corner_radius_all(8)
	s.content_margin_left = 9.0
	s.content_margin_right = 9.0
	s.content_margin_top = 2.0
	s.content_margin_bottom = 3.0
	s.shadow_size = 6
	s.shadow_color = Color(0, 0, 0, 0.35)
	cap.add_theme_stylebox_override("panel", s)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lbl: Label = _make_label(text, 15, accent_col)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_child(lbl)
	return cap


func _build_prompt_strip(style_id: String, mode: String = "kb") -> Control:
	var r: int = _corner_radius
	var rb: int = _resolve_rest_border(2)
	var items_kb: Array = [
		{"tex_fill": ICON_KB_ARROWS, "tex_out": ICON_KB_ARROWS, "cap": "↑↓←→", "label": "移动"},
		{"tex_fill": ICON_KB_ENTER, "tex_out": ICON_KB_ENTER_OUT, "cap": "Enter", "label": "确认"},
		{"tex_fill": ICON_KB_TAB, "tex_out": ICON_KB_TAB_OUT, "cap": "Tab", "label": "战绩"},
		{"tex_fill": ICON_KB_ESC, "tex_out": ICON_KB_ESC_OUT, "cap": "Esc", "label": "返回"},
	]
	var items_xbox: Array = [
		{"tex_fill": ICON_XB_A_COL, "tex_out": ICON_XB_A_COL_OUT, "cap": "A", "label": "确认"},
		{"tex_fill": ICON_XB_B_COL, "tex_out": ICON_XB_B_COL_OUT, "cap": "B", "label": "返回"},
		{"tex_fill": ICON_XB_X_COL, "tex_out": ICON_XB_X_COL_OUT, "cap": "X", "label": "更多"},
		{"tex_fill": ICON_XB_LB, "tex_out": ICON_XB_LB_OUT, "cap": "LB", "label": "上页"},
		{"tex_fill": ICON_XB_RB, "tex_out": ICON_XB_RB_OUT, "cap": "RB", "label": "下页"},
	]
	var items_hud: Array = [
		{"tex_fill": ICON_KB_W, "tex_out": ICON_KB_W_OUT, "cap": "W", "label": "前进"},
		{"tex_fill": ICON_KB_SHIFT, "tex_out": ICON_KB_SHIFT_OUT, "cap": "Shift", "label": "冲刺"},
		{"tex_fill": ICON_KB_SPACE, "tex_out": ICON_KB_SPACE_OUT, "cap": "Space", "label": "跳跃"},
		{"tex_fill": ICON_MOUSE_L, "tex_out": ICON_MOUSE_L_OUT, "cap": "左键", "label": "交互"},
	]
	var items: Array = items_kb if mode == "kb" else (items_xbox if mode == "xbox" else items_hud)

	if style_id == "glass_outline":
		var bar: PanelContainer = PanelContainer.new()
		bar.add_theme_stylebox_override(
			"panel",
			_box(Color(0.05, 0.09, 0.14, 0.78), Color(0.62, 0.80, 0.96, 0.24), rb, r, 18, 7, 12, 0.22)
		)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		bar.add_child(row)
		for it: Variant in items:
			var d: Dictionary = it as Dictionary
			var pair: HBoxContainer = HBoxContainer.new()
			pair.add_theme_constant_override("separation", 8)
			var is_color_xb: bool = (mode == "xbox" and String(d["cap"]) in ["A", "B", "X"])
			var tint: Color = Color(1, 1, 1, 1) if is_color_xb else Color(0.84, 0.93, 1.0, 0.95)
			pair.add_child(_make_prompt_icon(d["tex_out"] as Texture2D, tint, 28))
			var lbl: Label = _make_label(String(d["label"]), 17, Color(0.86, 0.92, 0.97, 1.0))
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			pair.add_child(lbl)
			row.add_child(pair)
		return bar

	if style_id == "solid_filled":
		var bar2: PanelContainer = PanelContainer.new()
		bar2.add_theme_stylebox_override(
			"panel",
			_box(Color(0.095, 0.14, 0.195, 0.95), Color(0.30, 0.40, 0.50, 0.40), _resolve_rest_border(0), r, 18, 7)
		)
		var row2: HBoxContainer = HBoxContainer.new()
		row2.add_theme_constant_override("separation", 20)
		bar2.add_child(row2)
		for it2: Variant in items:
			var d2: Dictionary = it2 as Dictionary
			var pair2: HBoxContainer = HBoxContainer.new()
			pair2.add_theme_constant_override("separation", 8)
			pair2.add_child(_make_prompt_icon(d2["tex_fill"] as Texture2D, Color(1, 1, 1, 1), 28))
			var lbl2: Label = _make_label(String(d2["label"]), 17, Color(0.95, 0.97, 0.99, 1.0))
			lbl2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			pair2.add_child(lbl2)
			row2.add_child(pair2)
		return bar2

	if style_id == "bare_keycaps":
		var row3: HBoxContainer = HBoxContainer.new()
		row3.add_theme_constant_override("separation", 20)
		for it3: Variant in items:
			var d3: Dictionary = it3 as Dictionary
			var pair3: HBoxContainer = HBoxContainer.new()
			pair3.add_theme_constant_override("separation", 8)
			if mode == "xbox":
				pair3.add_child(_make_prompt_icon(d3["tex_fill"] as Texture2D, Color(1, 1, 1, 1), 28))
			else:
				pair3.add_child(_make_keycap_badge(String(d3["cap"]), 28))
			var lbl3: Label = _make_label(String(d3["label"]), 17, Color(0.94, 0.96, 0.99, 1.0))
			lbl3.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl3.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
			lbl3.add_theme_constant_override("shadow_offset_x", 0)
			lbl3.add_theme_constant_override("shadow_offset_y", 2)
			pair3.add_child(lbl3)
			row3.add_child(pair3)
		return row3

	# Style 4 ("pill_chips")
	var row4: HBoxContainer = HBoxContainer.new()
	row4.add_theme_constant_override("separation", 10)
	for it4: Variant in items:
		var d4: Dictionary = it4 as Dictionary
		var chip: PanelContainer = PanelContainer.new()
		chip.add_theme_stylebox_override(
			"panel",
			_box(Color(0.85, 0.93, 1.0, 0.08), Color(0.85, 0.93, 1.0, 0.14), rb, r, 12, 5)
		)
		var pair4: HBoxContainer = HBoxContainer.new()
		pair4.add_theme_constant_override("separation", 8)
		var is_col4: bool = (mode == "xbox" and String(d4["cap"]) in ["A", "B", "X"])
		var tint4: Color = Color(1, 1, 1, 1) if is_col4 else Color(0.80, 0.91, 1.0, 0.92)
		pair4.add_child(_make_prompt_icon(d4["tex_out"] as Texture2D, tint4, 26))
		var lbl4: Label = _make_label(String(d4["label"]), 16, Color(0.91, 0.95, 0.99, 1.0))
		lbl4.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pair4.add_child(lbl4)
		chip.add_child(pair4)
		row4.add_child(chip)
	return row4


func _build_full_scheme_preview(scheme: Dictionary) -> Control:
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	var title: Label = _make_label(String(scheme["name"]), 26, Color(0.80, 0.90, 0.98, 1.0))
	var tag: Label = _make_label(String(scheme["tag"]), 17, Color(0.68, 0.76, 0.85, 1.0))
	tag.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	head.add_child(title)
	head.add_child(tag)
	root.add_child(head)

	var cols: HBoxContainer = HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 28)
	root.add_child(cols)

	# Column 1: Open Background Menu + Steam Avatar + Finalized 4-Color CTA Grid
	var col1: VBoxContainer = VBoxContainer.new()
	col1.custom_minimum_size = Vector2(360, 0)
	col1.add_theme_constant_override("separation", 10)
	col1.add_child(_make_label("1. 开放背景区域（星空底）", 17, Color(0.5843, 0.7804, 0.9255, 1.0)))

	var badge: PanelContainer = PanelContainer.new()
	badge.add_theme_stylebox_override("panel", scheme["open_hover"] as StyleBox)
	var badge_row: HBoxContainer = HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 12)
	var av_frame: PanelContainer = PanelContainer.new()
	av_frame.custom_minimum_size = Vector2(56, 56)
	av_frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	av_frame.add_theme_stylebox_override(
		"panel",
		_box(Color(0.08, 0.13, 0.2, 0.78), Color(0.75, 0.84, 0.92, 0.24), 2, 0, 0, 0)
	)
	var av_tex: TextureRect = TextureRect.new()
	av_tex.texture = DEFAULT_AVATAR
	av_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	av_frame.add_child(av_tex)
	badge_row.add_child(av_frame)
	var av_info: VBoxContainer = VBoxContainer.new()
	av_info.alignment = BoxContainer.ALIGNMENT_CENTER
	av_info.add_child(_make_label("星野凌", 22))
	av_info.add_child(_make_label("直角 0px 头像框保留", 14, Color(0.68, 0.76, 0.84, 1.0)))
	badge_row.add_child(av_info)
	badge.add_child(badge_row)
	col1.add_child(badge)

	var menu_list: VBoxContainer = VBoxContainer.new()
	menu_list.add_theme_constant_override("separation", 8)
	var open_items: Array = [
		["创建房间（悬停 / 手柄选中）", "hover"],
		["加入房间（常态透明）", ""],
		["设置（按下态）", "pressed"],
		["网络实验（禁用态）", "disabled"],
	]
	for item: Variant in open_items:
		var arr: Array = item as Array
		var b: Button = Button.new()
		b.text = String(arr[0])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(340, 48)
		b.add_theme_font_size_override("font_size", 20)
		_apply_btn(b, scheme, "open", String(arr[1]))
		menu_list.add_child(b)
	col1.add_child(menu_list)

	var cta_spacer: Control = Control.new()
	cta_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col1.add_child(cta_spacer)
	col1.add_child(_make_label("定稿 CTA（悬停斜切 / 点击切换已启用）", 15, Color(0.65, 0.74, 0.83, 1.0)))
	var cta_grid: GridContainer = GridContainer.new()
	cta_grid.columns = 2
	cta_grid.add_theme_constant_override("h_separation", 12)
	cta_grid.add_theme_constant_override("v_separation", 12)
	cta_grid.add_child(_make_cta_button("green", "准备", "", 19, 48))
	cta_grid.add_child(_make_cta_button("orange", "开始游戏", "enabled", 19, 48))
	cta_grid.add_child(_make_cta_button("blue", "复制地址", "", 19, 48))
	cta_grid.add_child(_make_cta_button("red", "取消准备", "", 19, 48))
	col1.add_child(cta_grid)
	cols.add_child(col1)

	# Column 2: Dialog / Form Card
	var col2: VBoxContainer = VBoxContainer.new()
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2.size_flags_stretch_ratio = 1.45
	col2.add_theme_constant_override("separation", 10)
	col2.add_child(_make_label("2. 弹窗 / 卡片与内部控件（边框 0 或 ≥2px）", 17, Color(0.5843, 0.7804, 0.9255, 1.0)))

	var dialog: PanelContainer = PanelContainer.new()
	dialog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_theme_stylebox_override("panel", scheme["panel"] as StyleBox)
	var dv: VBoxContainer = VBoxContainer.new()
	dv.add_theme_constant_override("separation", 14)
	dialog.add_child(dv)

	dv.add_child(_make_label("创建房间 · 选择大游戏", 25))

	var sub: PanelContainer = PanelContainer.new()
	sub.add_theme_stylebox_override("panel", scheme["subpanel"] as StyleBox)
	var sv: VBoxContainer = VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	sub.add_child(sv)

	var r1: HBoxContainer = HBoxContainer.new()
	r1.add_theme_constant_override("separation", 14)
	var r1_l: Label = _make_label("房间名称", 19)
	r1_l.custom_minimum_size = Vector2(124, 0)
	r1_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var r1_e: LineEdit = LineEdit.new()
	r1_e.text = "星际派对（输入框常态）"
	r1_e.custom_minimum_size = Vector2(0, 46)
	r1_e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1_e.add_theme_stylebox_override("normal", scheme["input_normal"] as StyleBox)
	r1_e.add_theme_stylebox_override("focus", scheme["input_hover"] as StyleBox)
	r1.add_child(r1_l)
	r1.add_child(r1_e)
	sv.add_child(r1)

	var r2: HBoxContainer = HBoxContainer.new()
	r2.add_theme_constant_override("separation", 14)
	var r2_l: Label = _make_label("监听端口", 19)
	r2_l.custom_minimum_size = Vector2(124, 0)
	r2_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var r2_e: LineEdit = LineEdit.new()
	r2_e.text = "7777（输入框悬停 / 输入态）"
	r2_e.custom_minimum_size = Vector2(0, 46)
	r2_e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2_e.add_theme_stylebox_override("normal", scheme["input_hover"] as StyleBox)
	r2_e.add_theme_stylebox_override("focus", scheme["input_hover"] as StyleBox)
	r2.add_child(r2_l)
	r2.add_child(r2_e)
	sv.add_child(r2)

	var r3: HBoxContainer = HBoxContainer.new()
	r3.add_theme_constant_override("separation", 12)
	var r3_l: Label = _make_label("监听网卡", 19)
	r3_l.custom_minimum_size = Vector2(124, 0)
	r3_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var r3_pick: Button = Button.new()
	r3_pick.text = "IPv4 · 以太网 1 · 192.168.5.8"
	r3_pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	r3_pick.custom_minimum_size = Vector2(0, 46)
	r3_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_btn(r3_pick, scheme, "card")
	var r3_ref: Button = Button.new()
	r3_ref.text = "刷新"
	r3_ref.custom_minimum_size = Vector2(98, 46)
	_apply_btn(r3_ref, scheme, "card", "hover")
	r3.add_child(r3_l)
	r3.add_child(r3_pick)
	r3.add_child(r3_ref)
	sv.add_child(r3)
	dv.add_child(sub)

	dv.add_child(_make_label("卡片按钮 4 态（常态 / 悬停 / 按下 / 禁用）", 15, Color(0.65, 0.74, 0.83, 1.0)))
	var state_row: HBoxContainer = HBoxContainer.new()
	state_row.add_theme_constant_override("separation", 12)
	for st: Array in [["常态", ""], ["悬停态", "hover"], ["按下态", "pressed"], ["禁用态", "disabled"]]:
		var sb: Button = Button.new()
		sb.text = String(st[0])
		sb.custom_minimum_size = Vector2(0, 48)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_btn(sb, scheme, "card", String(st[1]))
		state_row.add_child(sb)
	dv.add_child(state_row)

	var d_spacer: Control = Control.new()
	d_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(d_spacer)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	var cancel_b: Button = Button.new()
	cancel_b.text = "上一步"
	cancel_b.custom_minimum_size = Vector2(190, 54)
	cancel_b.add_theme_font_size_override("font_size", 21)
	_apply_btn(cancel_b, scheme, "card")
	var confirm_b: Button = Button.new()
	confirm_b.text = "创建房间（主操作悬停态）"
	confirm_b.custom_minimum_size = Vector2(0, 54)
	confirm_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_b.add_theme_font_size_override("font_size", 21)
	_apply_btn(confirm_b, scheme, "primary", "hover")
	actions.add_child(cancel_b)
	actions.add_child(confirm_b)
	dv.add_child(actions)

	col2.add_child(dialog)
	cols.add_child(col2)

	# Column 3: In-game Overlay HUD + Pause Menu Card
	var col3: VBoxContainer = VBoxContainer.new()
	col3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col3.size_flags_stretch_ratio = 0.95
	col3.add_theme_constant_override("separation", 12)
	col3.add_child(_make_label("3. 局内浮层与暂停卡片", 17, Color(0.5843, 0.7804, 0.9255, 1.0)))

	var hud: PanelContainer = PanelContainer.new()
	hud.add_theme_stylebox_override("panel", scheme["overlay"] as StyleBox)
	var hv: VBoxContainer = VBoxContainer.new()
	hv.add_theme_constant_override("separation", 6)
	hud.add_child(hv)
	hv.add_child(_make_label("局内小榜（极矮行条保留 6px）", 15, Color(0.68, 0.78, 0.88, 1.0)))
	var rows_data: Array = [
		["#1  星野凌", "1240", Color("#ff6673"), true],
		["#2  小林", "1080", Color("#4cd97b"), false],
		["#3  阿白", "920", Color("#4da6ff"), false],
		["#4  暮雪", "760", Color("#ffe047"), false],
	]
	for rd: Variant in rows_data:
		var rarr: Array = rd as Array
		var rp: PanelContainer = PanelContainer.new()
		var is_me: bool = bool(rarr[3])
		rp.add_theme_stylebox_override(
			"panel",
			_box(
				Color(0.14, 0.28, 0.42, 0.55) if is_me else Color(0.08, 0.13, 0.20, 0.42),
				Color(0.45, 0.78, 1.0, 0.65) if is_me else Color(0, 0, 0, 0),
				2 if is_me else 0,
				6, 10, 4
			)
		)
		var rh: HBoxContainer = HBoxContainer.new()
		var rn: Label = _make_label(String(rarr[0]), 16, rarr[2] as Color)
		rn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rs: Label = _make_label(String(rarr[1]), 16)
		rh.add_child(rn)
		rh.add_child(rs)
		rp.add_child(rh)
		hv.add_child(rp)
	col3.add_child(hud)

	var pause: PanelContainer = PanelContainer.new()
	pause.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pause.add_theme_stylebox_override("panel", scheme["panel"] as StyleBox)
	var pv: VBoxContainer = VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	pause.add_child(pv)
	var pt: Label = _make_label("游戏菜单", 23)
	pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(pt)
	var pause_btns: Array = [
		["返回游戏", "primary", ""],
		["框架设置（悬停态）", "card", "hover"],
		["协议设置", "card", ""],
		["返回大厅", "card", ""],
	]
	for pb_item: Variant in pause_btns:
		var pa: Array = pb_item as Array
		var pb: Button = Button.new()
		pb.text = String(pa[0])
		pb.custom_minimum_size = Vector2(0, 46)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.add_theme_font_size_override("font_size", 19)
		_apply_btn(pb, scheme, String(pa[1]), String(pa[2]))
		pv.add_child(pb)
	col3.add_child(pause)
	cols.add_child(col3)

	var prompt_footer: HBoxContainer = HBoxContainer.new()
	prompt_footer.add_theme_constant_override("separation", 16)
	prompt_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	var p_tag: Label = _make_label("配套按键提示：" + String(scheme["prompt_desc"]), 15, Color(0.5843, 0.7804, 0.9255, 1.0))
	p_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_footer.add_child(p_tag)
	prompt_footer.add_child(_build_prompt_strip(String(scheme["prompt_style"]), "kb"))
	prompt_footer.add_child(_build_prompt_strip(String(scheme["prompt_style"]), "hud"))
	root.add_child(prompt_footer)

	return root


func _build_button_matrix() -> Control:
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)

	root.add_child(_make_label("按钮标准化 4 方案对比（悬停 = 手柄选中，边框 0 或 ≥2px，4 态：常态 / 悬停 / 按下 / 禁用）", 22, Color(0.80, 0.90, 0.98, 1.0)))

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 18)
	root.add_child(grid)

	for key: String in ["scheme_a", "scheme_b", "scheme_c", "scheme_d"]:
		var scheme: Dictionary = _schemes[key] as Dictionary
		var block: VBoxContainer = VBoxContainer.new()
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.size_flags_vertical = Control.SIZE_EXPAND_FILL
		block.add_theme_constant_override("separation", 10)
		block.add_child(_make_label(String(scheme["name"]) + "  —  " + String(scheme["tag"]), 16, Color(0.5843, 0.7804, 0.9255, 1.0)))

		var open_row: HBoxContainer = HBoxContainer.new()
		open_row.add_theme_constant_override("separation", 14)
		var open_tag: Label = _make_label("开放背景", 16, Color(0.68, 0.76, 0.85, 1.0))
		open_tag.custom_minimum_size = Vector2(80, 0)
		open_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		open_row.add_child(open_tag)
		for st: Array in [["常态", ""], ["悬停 / 选中", "hover"], ["按下", "pressed"], ["禁用", "disabled"]]:
			var ob: Button = Button.new()
			ob.text = String(st[0])
			ob.custom_minimum_size = Vector2(0, 46)
			ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ob.add_theme_font_size_override("font_size", 18)
			_apply_btn(ob, scheme, "open", String(st[1]))
			open_row.add_child(ob)
		block.add_child(open_row)

		var card_bg: PanelContainer = PanelContainer.new()
		card_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var compact_panel: StyleBoxFlat = (scheme["panel"] as StyleBoxFlat).duplicate() as StyleBoxFlat
		compact_panel.content_margin_left = 16
		compact_panel.content_margin_right = 16
		compact_panel.content_margin_top = 12
		compact_panel.content_margin_bottom = 12
		card_bg.add_theme_stylebox_override("panel", compact_panel)
		var cv: VBoxContainer = VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 14)
		card_bg.add_child(cv)

		for row_def: Array in [["卡片次要", "card"], ["卡片主钮", "primary"]]:
			var brow: HBoxContainer = HBoxContainer.new()
			brow.add_theme_constant_override("separation", 14)
			var rtag: Label = _make_label(String(row_def[0]), 16, Color(0.68, 0.76, 0.85, 1.0))
			rtag.custom_minimum_size = Vector2(80, 0)
			rtag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			brow.add_child(rtag)
			for st2: Array in [["常态", ""], ["悬停 / 选中", "hover"], ["按下", "pressed"], ["禁用", "disabled"]]:
				var cb: Button = Button.new()
				cb.text = String(st2[0])
				cb.custom_minimum_size = Vector2(0, 46)
				cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cb.add_theme_font_size_override("font_size", 18)
				_apply_btn(cb, scheme, String(row_def[1]), String(st2[1]))
				brow.add_child(cb)
			cv.add_child(brow)

		block.add_child(card_bg)
		grid.add_child(block)

	return root


func _build_surface_matrix() -> Control:
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)

	root.add_child(_make_label("面板表面、嵌套层级与统一悬停态 4 方案总览（边框均 0px 或 ≥2px）", 24, Color(0.80, 0.90, 0.98, 1.0)))

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 20)
	root.add_child(grid)

	for key: String in ["scheme_a", "scheme_b", "scheme_c", "scheme_d"]:
		var scheme: Dictionary = _schemes[key] as Dictionary
		var panel: PanelContainer = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", scheme["panel"] as StyleBox)

		var pv: VBoxContainer = VBoxContainer.new()
		pv.add_theme_constant_override("separation", 14)
		panel.add_child(pv)

		var header: VBoxContainer = VBoxContainer.new()
		header.add_theme_constant_override("separation", 4)
		header.add_child(_make_label(String(scheme["name"]), 23, Color(0.84, 0.92, 0.99, 1.0)))
		header.add_child(_make_label(String(scheme["tag"]), 15, Color(0.66, 0.75, 0.84, 1.0)))
		pv.add_child(header)

		var sub: PanelContainer = PanelContainer.new()
		sub.add_theme_stylebox_override("panel", scheme["subpanel"] as StyleBox)
		var sh: HBoxContainer = HBoxContainer.new()
		sh.add_theme_constant_override("separation", 14)
		var le1: LineEdit = LineEdit.new()
		le1.text = "输入框 · 常态"
		le1.custom_minimum_size = Vector2(0, 46)
		le1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le1.add_theme_stylebox_override("normal", scheme["input_normal"] as StyleBox)
		le1.add_theme_stylebox_override("focus", scheme["input_hover"] as StyleBox)
		var le2: LineEdit = LineEdit.new()
		le2.text = "输入框 · 悬停 / 输入态"
		le2.custom_minimum_size = Vector2(0, 46)
		le2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le2.add_theme_stylebox_override("normal", scheme["input_hover"] as StyleBox)
		le2.add_theme_stylebox_override("focus", scheme["input_hover"] as StyleBox)
		sh.add_child(le1)
		sh.add_child(le2)
		sub.add_child(sh)
		pv.add_child(sub)

		var brow: HBoxContainer = HBoxContainer.new()
		brow.add_theme_constant_override("separation", 14)
		var b_sec: Button = Button.new()
		b_sec.text = "取消（常态）"
		b_sec.custom_minimum_size = Vector2(0, 50)
		b_sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_btn(b_sec, scheme, "card")
		var b_sec_h: Button = Button.new()
		b_sec_h.text = "设置（悬停）"
		b_sec_h.custom_minimum_size = Vector2(0, 50)
		b_sec_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_btn(b_sec_h, scheme, "card", "hover")
		var b_pri: Button = Button.new()
		b_pri.text = "确认（主操作）"
		b_pri.custom_minimum_size = Vector2(0, 50)
		b_pri.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_btn(b_pri, scheme, "primary")
		var b_pri_h: Button = Button.new()
		b_pri_h.text = "确认（悬停）"
		b_pri_h.custom_minimum_size = Vector2(0, 50)
		b_pri_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_btn(b_pri_h, scheme, "primary", "hover")
		brow.add_child(b_sec)
		brow.add_child(b_sec_h)
		brow.add_child(b_pri)
		brow.add_child(b_pri_h)
		pv.add_child(brow)

		grid.add_child(panel)

	return root


func _build_prompt_matrix() -> Control:
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)

	root.add_child(_make_label("按键提示 4 种风格对比（已对 Space / Shift / Tab / LB / RB 垂直填充适配，与单键等高清晰）", 22, Color(0.80, 0.90, 0.98, 1.0)))

	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	root.add_child(list)

	var styles: Array = [
		{"id": "glass_outline", "title": "风格 1 · 悬浮磨砂胶囊条 + 线性描边图标（配方案 A）", "note": "自动裁切透明边并垂直填满 28px，Space/Shift/Tab 与 W/Esc 完全等高"},
		{"id": "solid_filled", "title": "风格 2 · 实色扁平底条 + 实心高对比键帽（配方案 B）", "note": "高不透明无边框底条 + 垂直满高实体白底键帽，扫读最快"},
		{"id": "bare_keycaps", "title": "风格 3 · 无底条裸浮 + 立体深色键帽徽章（配方案 C）", "note": "去掉整条底板不遮挡画面，宽键帽与单键统一 28px 高度"},
		{"id": "pill_chips", "title": "风格 4 · 轻白光分组独立胶囊 + 柔色描边图标（配方案 D）", "note": "每条操作独立成轻柔胶囊，无整根长条压迫感"},
	]

	for item: Variant in styles:
		var st: Dictionary = item as Dictionary
		var row_card: PanelContainer = PanelContainer.new()
		row_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row_card.add_theme_stylebox_override(
			"panel",
			_box(Color(0.05, 0.08, 0.125, 0.52), Color(0.55, 0.72, 0.88, 0.16), _resolve_rest_border(2), _corner_radius, 22, 12)
		)
		var rv: VBoxContainer = VBoxContainer.new()
		rv.alignment = BoxContainer.ALIGNMENT_CENTER
		rv.add_theme_constant_override("separation", 10)
		row_card.add_child(rv)

		var head_row: HBoxContainer = HBoxContainer.new()
		head_row.add_theme_constant_override("separation", 16)
		head_row.add_child(_make_label(String(st["title"]), 20, Color(0.84, 0.92, 0.99, 1.0)))
		var note_lbl: Label = _make_label(String(st["note"]), 15, Color(0.66, 0.75, 0.84, 1.0))
		note_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		head_row.add_child(note_lbl)
		rv.add_child(head_row)

		var samples: HBoxContainer = HBoxContainer.new()
		samples.add_theme_constant_override("separation", 22)
		var sid: String = String(st["id"])

		var g1: VBoxContainer = VBoxContainer.new()
		g1.add_theme_constant_override("separation", 4)
		g1.add_child(_make_label("键鼠导航栏", 14, Color(0.5843, 0.7804, 0.9255, 1.0)))
		g1.add_child(_build_prompt_strip(sid, "kb"))
		samples.add_child(g1)

		var g2: VBoxContainer = VBoxContainer.new()
		g2.add_theme_constant_override("separation", 4)
		g2.add_child(_make_label("Xbox 手柄栏", 14, Color(0.5843, 0.7804, 0.9255, 1.0)))
		g2.add_child(_build_prompt_strip(sid, "xbox"))
		samples.add_child(g2)

		var g3: VBoxContainer = VBoxContainer.new()
		g3.add_theme_constant_override("separation", 4)
		g3.add_child(_make_label("宽键实测（W / Shift / Space / 左键）", 14, Color(0.5843, 0.7804, 0.9255, 1.0)))
		g3.add_child(_build_prompt_strip(sid, "hud"))
		samples.add_child(g3)

		rv.add_child(samples)
		list.add_child(row_card)

	return root


func _build_cta_matrix() -> Control:
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 18)

	root.add_child(_make_label("强语义 CTA 定稿（反向镂空描边 → 斜向高饱和填充 + 已启用态，无辉光）", 25, Color(0.80, 0.90, 0.98, 1.0)))

	var card: PanelContainer = PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel",
		_box(Color(0.055, 0.088, 0.135, 0.78), Color(0.55, 0.72, 0.88, 0.22), _resolve_rest_border(2), _corner_radius, 34, 28)
	)
	var cv: VBoxContainer = VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 24)
	card.add_child(cv)

	cv.add_child(_make_label("交互说明：未启用悬停会在右下角保留一小块镂空角；点击后右下角闭合进入「已启用（全满）」态，悬停仍保持全满以作区分。", 17, Color(0.68, 0.78, 0.88, 1.0)))

	var cols_def: Array = [
		["未启用 · 常态（可交互）", ""],
		["斜向滑入过程（55%）", "mid"],
		["未启用 · 悬停（留右下角）", "hover"],
		["已启用 / 启用悬停（全满）", "enabled"],
		["禁用态", "disabled"],
	]

	var ch: HBoxContainer = HBoxContainer.new()
	ch.add_theme_constant_override("separation", 24)
	var tag_h: Label = _make_label("语义色", 16, Color(0.5843, 0.7804, 0.9255, 1.0))
	tag_h.custom_minimum_size = Vector2(110, 0)
	ch.add_child(tag_h)
	for col_item: Variant in cols_def:
		var cd: Array = col_item as Array
		var cl: Label = _make_label(String(cd[0]), 16, Color(0.5843, 0.7804, 0.9255, 1.0))
		cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ch.add_child(cl)
	cv.add_child(ch)

	var colors: Array = [
		["green", "绿色 · 准备", "准备"],
		["orange", "橙色 · 开始", "开始游戏"],
		["blue", "蓝色 · 复制", "复制房间地址"],
		["red", "红色 · 取消", "取消准备"],
	]
	for c_item: Variant in colors:
		var ca: Array = c_item as Array
		var c_row: HBoxContainer = HBoxContainer.new()
		c_row.add_theme_constant_override("separation", 24)
		var row_lbl: Label = _make_label(String(ca[1]), 18, (_cta_palette(String(ca[0]))["outline"] as Color))
		row_lbl.custom_minimum_size = Vector2(110, 0)
		row_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c_row.add_child(row_lbl)
		for col_item2: Variant in cols_def:
			var cd2: Array = col_item2 as Array
			c_row.add_child(_make_cta_button(String(ca[0]), String(ca[2]), String(cd2[1]), 21, 64))
		cv.add_child(c_row)

	root.add_child(card)
	return root
