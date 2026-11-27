## Strong-semantic CTA button with hollow semantic rest, diagonal high-saturation fill wipe
## (leaving a hollow bottom-right triangle on un-enabled hover), real-time diagonal caption
## inversion, and a 100%-filled enabled state with zero outer glow.
class_name PartyCTAButton
extends Button

const WIPE_SHADER: Shader = preload("res://core/ui/ambient_reveal/theme/materials/cta_diagonal_wipe.gdshader")
const EDGE_SOFTNESS: float = 1.5
const HOVER_TOP_OVERHANG_PX: float = 4.0
const HOLLOW_BG: Color = Color(0.03, 0.055, 0.09, 0.42)
const DISABLED_BG: Color = Color(0.04, 0.06, 0.10, 0.35)
const DISABLED_INK: Color = Color(0.70, 0.75, 0.82, 0.58)

@export_enum("green", "orange", "blue", "red") var semantic_color: String = "green":
	set(value):
		semantic_color = value
		if is_node_ready():
			_apply_visuals()

@export var enabled_state: bool = false:
	set(value):
		enabled_state = value
		if is_node_ready():
			_sync_fill(true)

@export_range(0, 24, 1) var corner_radius: int = 8:
	set(value):
		corner_radius = value
		if is_node_ready():
			_apply_visuals()

@export_range(2, 6, 1) var border_width: int = 2:
	set(value):
		border_width = maxi(value, 2)
		if is_node_ready():
			_apply_visuals()

@export_range(12.0, 64.0, 1.0) var slant_px: float = 36.0:
	set(value):
		slant_px = value
		if _wipe_mat != null:
			_wipe_mat.set_shader_parameter("slant_px", slant_px)
			_sync_fill(false)

var _base_label: Label
var _upper_mask: Panel
var _fill_bg: ColorRect
var _inv_label: Label
var _wipe_mat: ShaderMaterial
var _fill_tween: Tween
var _scale_tween: Tween
var _last_disabled: bool = false
var _last_caption: String = ""
var _last_font_size: int = -1
var _pressing: bool = false


## Returns the finalized high-saturation glow-free CTA palette for a semantic color key.
static func get_palette(color_key: String) -> Dictionary:
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
		_:
			return {
				"bright": Color(0.90, 0.29, 0.34, 1.0),
				"pressed": Color(0.68, 0.19, 0.23, 1.0),
				"outline": Color(0.98, 0.42, 0.46, 1.0),
				"ink": Color(1.0, 1.0, 1.0, 1.0),
			}


func _ready() -> void:
	_base_label = Label.new()
	_base_label.name = "BaseCaption"
	_base_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_base_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_base_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_base_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_base_label)

	_upper_mask = Panel.new()
	_upper_mask.name = "WipeMask"
	_upper_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	_upper_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upper_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(_upper_mask)

	_wipe_mat = ShaderMaterial.new()
	_wipe_mat.shader = WIPE_SHADER
	_wipe_mat.set_shader_parameter("fill_progress", 0.0)
	_wipe_mat.set_shader_parameter("rect_size", Vector2(maxf(size.x, 200.0), maxf(size.y, 48.0)))
	_wipe_mat.set_shader_parameter("slant_px", slant_px)
	_wipe_mat.set_shader_parameter("edge_softness", EDGE_SOFTNESS)

	_fill_bg = ColorRect.new()
	_fill_bg.name = "FillRect"
	_fill_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fill_bg.material = _wipe_mat
	_fill_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upper_mask.add_child(_fill_bg)

	_inv_label = Label.new()
	_inv_label.name = "InvertedCaption"
	_inv_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inv_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_inv_label.material = _wipe_mat
	_inv_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upper_mask.add_child(_inv_label)

	# Hide native Button text so the base & diagonal-inverted labels render cleanly without double-draw.
	for color_slot: StringName in [
		&"font_color",
		&"font_hover_color",
		&"font_focus_color",
		&"font_pressed_color",
		&"font_hover_pressed_color",
		&"font_disabled_color",
	]:
		add_theme_color_override(color_slot, Color(0.0, 0.0, 0.0, 0.0))

	mouse_entered.connect(_on_highlight_changed)
	mouse_exited.connect(_on_highlight_changed)
	focus_entered.connect(_on_highlight_changed)
	focus_exited.connect(_on_highlight_changed)
	toggled.connect(_on_toggled)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	resized.connect(_on_resized)

	var audio: Node = get_tree().get_first_node_in_group(&"ambient_menu_audio")
	if audio != null:
		pressed.connect(audio.click)

	_last_disabled = disabled
	_apply_visuals()
	_sync_caption()
	_sync_fill(false)
	call_deferred("_on_resized")


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_DRAW:
		if text != _last_caption or get_theme_font_size(&"font_size") != _last_font_size:
			_sync_caption()
		if disabled != _last_disabled:
			_last_disabled = disabled
			_apply_visuals()
			_sync_fill(false)
	elif what == NOTIFICATION_THEME_CHANGED:
		_sync_caption()


func _apply_visuals() -> void:
	var pal: Dictionary = get_palette(semantic_color)
	var bright_col: Color = pal["bright"] as Color
	var pressed_col: Color = pal["pressed"] as Color
	var outline_col: Color = pal["outline"] as Color
	var ink_col: Color = pal["ink"] as Color
	var bw: int = maxi(border_width, 2)

	var rest_box: StyleBoxFlat = _make_box(HOLLOW_BG, outline_col, bw, corner_radius)
	var dis_box: StyleBoxFlat = _make_box(
		DISABLED_BG,
		Color(outline_col.r, outline_col.g, outline_col.b, 0.28),
		bw,
		corner_radius
	)
	add_theme_stylebox_override(&"normal", rest_box)
	add_theme_stylebox_override(&"hover", rest_box)
	add_theme_stylebox_override(&"hover_pressed", rest_box)
	add_theme_stylebox_override(&"focus", rest_box)
	add_theme_stylebox_override(&"pressed", rest_box)
	add_theme_stylebox_override(&"disabled", dis_box)

	var mask_box: StyleBoxFlat = _make_box(Color(1.0, 1.0, 1.0, 1.0), Color(0.0, 0.0, 0.0, 0.0), 0, corner_radius)
	_upper_mask.add_theme_stylebox_override(&"panel", mask_box)
	_upper_mask.visible = not disabled

	_fill_bg.color = pressed_col if _pressing else bright_col
	_base_label.add_theme_color_override(&"font_color", DISABLED_INK if disabled else outline_col)
	_inv_label.add_theme_color_override(&"font_color", ink_col)


func _sync_caption() -> void:
	if _base_label == null or _inv_label == null:
		return
	_last_caption = text
	_last_font_size = get_theme_font_size(&"font_size")
	_base_label.text = text
	_inv_label.text = text
	_base_label.add_theme_font_size_override(&"font_size", _last_font_size)
	_inv_label.add_theme_font_size_override(&"font_size", _last_font_size)


func _is_enabled_active() -> bool:
	return enabled_state or (toggle_mode and button_pressed)


func _is_highlighted() -> bool:
	return not disabled and (is_hovered() or has_focus())


func _unenabled_hover_progress(btn_width: float) -> float:
	var w: float = maxf(btn_width, 96.0)
	var span: float = w + slant_px + EDGE_SOFTNESS * 2.0
	var target_cutoff: float = w + HOVER_TOP_OVERHANG_PX
	return clampf((target_cutoff + EDGE_SOFTNESS) / maxf(span, 1.0), 0.72, 0.96)


func _target_progress() -> float:
	if disabled:
		return 0.0
	if _is_enabled_active():
		return 1.0
	if _is_highlighted():
		return _unenabled_hover_progress(size.x)
	return 0.0


func _sync_fill(animate: bool) -> void:
	if _wipe_mat == null:
		return
	_wipe_mat.set_shader_parameter("rect_size", Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0)))
	var target: float = _target_progress()
	if _fill_tween != null and _fill_tween.is_valid():
		_fill_tween.kill()
	if not animate or not is_visible_in_tree():
		_wipe_mat.set_shader_parameter("fill_progress", target)
		return
	var cur_p: float = float(_wipe_mat.get_shader_parameter("fill_progress"))
	if is_equal_approx(cur_p, target):
		return
	var duration: float = 0.20 if target > cur_p else 0.18
	if _is_enabled_active() and _is_highlighted():
		duration = 0.14
	var trans: Tween.TransitionType = Tween.TRANS_CUBIC if target > cur_p else Tween.TRANS_QUAD
	_fill_tween = create_tween().set_trans(trans).set_ease(Tween.EASE_OUT)
	_fill_tween.tween_method(_set_fill_progress, cur_p, target, duration)


func _set_fill_progress(value: float) -> void:
	if _wipe_mat != null:
		_wipe_mat.set_shader_parameter("fill_progress", value)


func _on_highlight_changed() -> void:
	_sync_fill(true)


func _on_toggled(_on: bool) -> void:
	_sync_fill(true)


func _on_button_down() -> void:
	if disabled:
		return
	_pressing = true
	var pal: Dictionary = get_palette(semantic_color)
	_fill_bg.color = pal["pressed"] as Color
	pivot_offset = size * 0.5
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2(0.97, 0.97), 0.07)


func _on_button_up() -> void:
	_pressing = false
	var pal: Dictionary = get_palette(semantic_color)
	_fill_bg.color = pal["bright"] as Color
	pivot_offset = size * 0.5
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.12)


func _on_resized() -> void:
	pivot_offset = size * 0.5
	if _wipe_mat != null:
		_wipe_mat.set_shader_parameter("rect_size", Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0)))
		if not _is_enabled_active() and _is_highlighted():
			_wipe_mat.set_shader_parameter("fill_progress", _unenabled_hover_progress(size.x))


func _make_box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(bw)
	box.set_corner_radius_all(radius)
	box.corner_detail = 16
	box.anti_aliasing = true
	box.anti_aliasing_size = 1.25
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box
