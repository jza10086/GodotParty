## Full-canvas 1920x1080 authoring showcase comparing 4 spacious Standard Briefing Page
## layouts with zero top toolbar, enlarged Rules & Controls regions, and locked-in components:
## - Scheme A frosted glass (8px radius, 2px borders)
## - Enlarged 16:9 preview with top-left title overlay
## - Lobby-style 2px player-color cards + tinted player names + Roster B flat difficulty/ready tags
## - Input Prompt Style 2 vertical-fill Kenney keycaps + PartyCTAButton
## Interactive hotkeys when running in editor: 1-4 switch layout, 8 toggle 4/8 players, C toggle choice.
extends Control

const AMBIENT_THEME: Theme = preload("res://core/ui/ambient_reveal/ambient_theme.tres")
const FALLBACK_COVER: Texture2D = preload("res://core/ui/components/assets/game_preview.svg")
const CTAButtonScript: Script = preload("res://core/ui/ambient_reveal/components/cta_button.gd")
const PromptIconsScript: Script = preload("res://core/ui/ambient_reveal/components/navigation/prompt_icons.gd")

const ICON_A: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_a.svg")
const ICON_D: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_d.svg")
const ICON_W: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_w.svg")
const ICON_S: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_s.svg")
const ICON_Q: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_q.svg")
const ICON_E: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_e.svg")
const ICON_SPACE: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_space.svg")
const ICON_SHIFT: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_shift.svg")
const ICON_MOUSE_SCROLL: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/mouse_scroll.svg")
const ICON_ENTER: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_enter.svg")
const ICON_ESC: Texture2D = preload("res://core/ui/ambient_reveal/icons/kenney_input/keyboard_mouse/keyboard_escape.svg")

const RADIUS: int = 8
const ACCENT_TEXT: Color = Color(0.5843, 0.7804, 0.9255, 1.0)
const MUTED_TEXT: Color = Color(0.66, 0.74, 0.83, 1.0)
const BRIGHT_TEXT: Color = Color(0.96, 0.97, 0.99, 1.0)
const READY_BG: Color = Color(0.14, 0.58, 0.35, 0.94)
const GLASS_BG: Color = Color(0.055, 0.09, 0.14, 0.84)
const GLASS_BORDER: Color = Color(0.58, 0.78, 0.94, 0.24)
const PROMPT_BAR_BG: Color = Color(0.095, 0.14, 0.195, 0.95)

const SAMPLE_RULES: String = "轮流操控坦克调整仰角与蓄力力度，结合风向与可破坏地形摧毁对手或将其击落深渊。\n\n每回合移动会消耗燃油，合理切换穿甲弹、散射弹与EMP等特殊弹药压制敌人。最后存活或总伤害最高者获胜。"

var _active_layout: String = "layout_1"
var _player_count: int = 4
var _show_choice: bool = true
var _local_ready: bool = false
var _local_choice: String = "普通"
var _cover_tex: Texture2D = null
var _stage: Control


func _ready() -> void:
	theme = AMBIENT_THEME
	if ResourceLoader.exists("res://games/minigame/GP_artillery/cover.png"):
		_cover_tex = load("res://games/minigame/GP_artillery/cover.png") as Texture2D
	if _cover_tex == null:
		_cover_tex = FALLBACK_COVER

	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	show_layout("layout_1")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var ke: InputEventKey = event as InputEventKey
	match ke.keycode:
		KEY_1:
			show_layout("layout_1")
		KEY_2:
			show_layout("layout_2")
		KEY_3:
			show_layout("layout_3")
		KEY_4:
			show_layout("layout_4")
		KEY_8:
			_player_count = 8 if _player_count == 4 else 4
			_rebuild_stage()
		KEY_C:
			_show_choice = not _show_choice
			_rebuild_stage()


func show_layout(layout_id: String) -> void:
	_active_layout = layout_id
	_rebuild_stage()


func set_preview_options(player_count: int, show_choice: bool, local_ready: bool) -> void:
	_player_count = clampi(player_count, 4, 8)
	_show_choice = show_choice
	_local_ready = local_ready
	_rebuild_stage()


func _rebuild_stage() -> void:
	for child: Node in _stage.get_children():
		_stage.remove_child(child)
		child.queue_free()

	var view: Control = null
	match _active_layout:
		"layout_1":
			view = _build_layout_1_tall_split()
		"layout_2":
			view = _build_layout_2_right_editorial()
		"layout_3":
			view = _build_layout_3_quadrant()
		_:
			view = _build_layout_4_three_cards_bottom()
	if view != null:
		view.set_anchors_preset(Control.PRESET_FULL_RECT)
		_stage.add_child(view)


func _mock_players() -> Array[Dictionary]:
	var all_players: Array[Dictionary] = [
		{"name": "星野凌（你）", "color": Color(0.32, 0.74, 0.98, 1.0), "choice": _local_choice, "ready": _local_ready, "loaded": true},
		{"name": "小林", "color": Color(0.32, 0.86, 0.54, 1.0), "choice": "困难", "ready": true, "loaded": true},
		{"name": "阿白", "color": Color(0.98, 0.65, 0.25, 1.0), "choice": "普通", "ready": true, "loaded": true},
		{"name": "柚子", "color": Color(0.96, 0.44, 0.56, 1.0), "choice": "简单", "ready": false, "loaded": true},
		{"name": "夜岚", "color": Color(0.72, 0.54, 0.98, 1.0), "choice": "专家", "ready": true, "loaded": true},
		{"name": "橙子汽水", "color": Color(0.98, 0.82, 0.30, 1.0), "choice": "普通", "ready": false, "loaded": true},
		{"name": "冰川猫", "color": Color(0.28, 0.86, 0.82, 1.0), "choice": "困难", "ready": true, "loaded": true},
		{"name": "火柴人", "color": Color(0.96, 0.52, 0.36, 1.0), "choice": "普通", "ready": false, "loaded": false},
	]
	var out: Array[Dictionary] = []
	for i: int in range(mini(_player_count, all_players.size())):
		out.append(all_players[i])
	return out


func _mock_controls() -> Array[Dictionary]:
	return [
		{"icons": [ICON_A, ICON_D], "label": "左右移动坦克"},
		{"icons": [ICON_W, ICON_S], "label": "调整炮管仰角"},
		{"icons": [ICON_SPACE], "label": "长按蓄力开火"},
		{"icons": [ICON_Q, ICON_E], "label": "切换特殊弹药"},
		{"icons": [ICON_SHIFT], "label": "微调瞄准精度"},
		{"icons": [ICON_MOUSE_SCROLL], "label": "缩放战场视野"},
	]


func _ready_count(players: Array[Dictionary]) -> int:
	var c: int = 0
	for p: Dictionary in players:
		if bool(p["ready"]):
			c += 1
	return c


func _box(bg: Color, border: Color, bw: int, radius: int, pad_x: int = 18, pad_y: int = 14, shadow: int = 0) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.corner_detail = 16
	s.anti_aliasing = true
	s.anti_aliasing_size = 1.25
	s.content_margin_left = float(pad_x)
	s.content_margin_right = float(pad_x)
	s.content_margin_top = float(pad_y)
	s.content_margin_bottom = float(pad_y)
	if shadow > 0:
		s.shadow_size = shadow
		s.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
		s.shadow_offset = Vector2(0, 8)
	return s


func _lbl(text: String, size: int = 20, col: Color = BRIGHT_TEXT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _make_cropped_icon(tex: Texture2D, target_h: int = 28) -> TextureRect:
	var info: Dictionary = PromptIconsScript.cropped(tex)
	var cropped: Texture2D = info["texture"] as Texture2D
	var aspect: float = float(info["aspect"])
	var tr: TextureRect = TextureRect.new()
	tr.texture = cropped
	tr.custom_minimum_size = Vector2(roundf(float(target_h) * aspect), float(target_h))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _make_key_row(icons: Array, caption: String, icon_h: int = 28, font_sz: int = 19) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var icon_box: HBoxContainer = HBoxContainer.new()
	icon_box.add_theme_constant_override("separation", 5)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for tex_v: Variant in icons:
		icon_box.add_child(_make_cropped_icon(tex_v as Texture2D, icon_h))
	row.add_child(icon_box)
	var l: Label = _lbl(caption, font_sz, BRIGHT_TEXT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(l)
	return row


func _make_prompt_bar(items: Array, pad_x: int = 16, pad_y: int = 7) -> PanelContainer:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box(PROMPT_BAR_BG, Color(0, 0, 0, 0), 0, RADIUS, pad_x, pad_y))
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	bar.add_child(row)
	for it: Variant in items:
		var d: Dictionary = it as Dictionary
		var pair: HBoxContainer = HBoxContainer.new()
		pair.add_theme_constant_override("separation", 8)
		for tex_v: Variant in (d["icons"] as Array):
			pair.add_child(_make_cropped_icon(tex_v as Texture2D, 25))
		var lbl: Label = _lbl(String(d["label"]), 16, BRIGHT_TEXT)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pair.add_child(lbl)
		row.add_child(pair)
	return bar


func _make_choice_chip(text: String, font_sz: int = 15) -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _box(Color(0.14, 0.22, 0.32, 0.90), Color(0, 0, 0, 0), 0, 6, 9, 3))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.add_child(_lbl(text, font_sz, ACCENT_TEXT))
	return pill


func _make_lobby_player_row(p: Dictionary, compact: bool = false) -> PanelContainer:
	var is_ready: bool = bool(p["ready"])
	var is_loaded: bool = bool(p["loaded"])
	var pcol: Color = p["color"] as Color

	var row_bg: Color = Color(0.08, 0.125, 0.185, 0.84)
	var border_col: Color = Color(pcol.r, pcol.g, pcol.b, 0.92 if is_loaded else 0.42)
	var row_card: PanelContainer = PanelContainer.new()
	row_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_card.custom_minimum_size = Vector2(0, 48 if compact else 56)
	row_card.add_theme_stylebox_override("panel", _box(row_bg, border_col, 2, RADIUS, 16, 8))

	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row_card.add_child(h)

	var name_col: Color = pcol if is_loaded else Color(pcol.r, pcol.g, pcol.b, 0.58)
	var nl: Label = _lbl(String(p["name"]), 19 if compact else 21, name_col)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(nl)

	if _show_choice:
		h.add_child(_make_choice_chip(String(p["choice"]), 14 if compact else 15))

	var pill: PanelContainer = PanelContainer.new()
	var p_bg: Color = READY_BG if is_ready else Color(0.14, 0.20, 0.28, 0.78)
	pill.add_theme_stylebox_override("panel", _box(p_bg, Color(0, 0, 0, 0), 0, 6, 11, 4))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st_txt: String = "加载中" if not is_loaded else ("已准备" if is_ready else "未准备")
	pill.add_child(_lbl(st_txt, 14 if compact else 15, BRIGHT_TEXT if is_ready else MUTED_TEXT))
	h.add_child(pill)
	return row_card


func _make_preview_card(title_text: String = "炮火对决") -> Panel:
	var preview_frame: Panel = Panel.new()
	preview_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	preview_frame.add_theme_stylebox_override("panel", _box(Color(0.05, 0.08, 0.13, 1.0), GLASS_BORDER, 2, RADIUS, 0, 0, 22))

	var cover_rect: TextureRect = TextureRect.new()
	cover_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover_rect.texture = _cover_tex
	cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview_frame.add_child(cover_rect)

	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(0.02, 0.038, 0.068, 0.84),
		Color(0.02, 0.038, 0.068, 0.30),
		Color(0.02, 0.038, 0.068, 0.0),
	])
	var grad_tex: GradientTexture2D = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.0, 0.0)
	grad_tex.fill_to = Vector2(0.55, 0.44)
	var scrim: TextureRect = TextureRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.texture = grad_tex
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.add_child(scrim)

	var title_inset: MarginContainer = MarginContainer.new()
	title_inset.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title_inset.add_theme_constant_override("margin_left", 30)
	title_inset.add_theme_constant_override("margin_top", 22)
	title_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.add_child(title_inset)

	var title_lbl: Label = _lbl(title_text, 50, Color(0.96, 0.98, 1.0, 1.0))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	title_lbl.add_theme_constant_override("shadow_offset_x", 0)
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	title_inset.add_child(title_lbl)

	return preview_frame


func _make_rules_block(font_sz: int = 21) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_child(_lbl("规则", 24, ACCENT_TEXT))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var intro: Label = _lbl(SAMPLE_RULES, font_sz, BRIGHT_TEXT)
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(intro)
	return box


func _make_controls_block(cols: int = 2, icon_h: int = 28, font_sz: int = 19) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.add_child(_lbl("按键", 24, ACCENT_TEXT))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = cols
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 16)
	for c_item: Dictionary in _mock_controls():
		var r: HBoxContainer = _make_key_row(c_item["icons"] as Array, String(c_item["label"]), icon_h, font_sz)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(r)
	scroll.add_child(grid)
	return box


func _make_roster_block(players: Array[Dictionary], cols: int = 1) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)

	var head: HBoxContainer = HBoxContainer.new()
	var t: Label = _lbl("玩家列表", 24, ACCENT_TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_lbl("%d / %d 就绪" % [_ready_count(players), players.size()], 18, MUTED_TEXT))
	box.add_child(head)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	var compact: bool = players.size() > 5
	if cols > 1:
		var grid: GridContainer = GridContainer.new()
		grid.columns = cols
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 10)
		for p: Dictionary in players:
			grid.add_child(_make_lobby_player_row(p, compact))
		scroll.add_child(grid)
	else:
		var list: VBoxContainer = VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 8)
		for p2: Dictionary in players:
			list.add_child(_make_lobby_player_row(p2, compact))
		scroll.add_child(list)
	return box


func _make_choice_picker() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var title: Label = _lbl("难度", 19, ACCENT_TEXT)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	var opt: OptionButton = OptionButton.new()
	opt.custom_minimum_size = Vector2(0, 48)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_theme_font_size_override("font_size", 19)
	var options: Array[String] = ["简单", "普通", "困难", "专家"]
	for i: int in range(options.size()):
		opt.add_item(options[i], i)
		if options[i] == _local_choice:
			opt.select(i)
	opt.disabled = _local_ready
	opt.item_selected.connect(func(idx: int) -> void:
		_local_choice = opt.get_item_text(idx)
		_rebuild_stage()
	)
	row.add_child(opt)
	return row


func _make_ready_cta(min_h: int = 66) -> Button:
	var cta: Button = CTAButtonScript.new() as Button
	cta.custom_minimum_size = Vector2(0, float(min_h))
	cta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cta.add_theme_font_size_override("font_size", 26)
	cta.text = "取消准备" if _local_ready else "准备"
	cta.set("semantic_color", "red" if _local_ready else "green")
	cta.set("enabled_state", _local_ready)
	cta.set("corner_radius", RADIUS)
	cta.pressed.connect(func() -> void:
		_local_ready = not _local_ready
		_rebuild_stage()
	)
	return cta


func _make_action_footer() -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	if _show_choice:
		v.add_child(_make_choice_picker())
	v.add_child(_make_ready_cta(66))
	var hint_center: CenterContainer = CenterContainer.new()
	hint_center.add_child(_make_prompt_bar([
		{"icons": [ICON_ENTER, ICON_SPACE], "label": "准备 / 取消"},
		{"icons": [ICON_ESC], "label": "菜单"},
	], 14, 6))
	v.add_child(hint_center)
	return v


func _wrap_margin() -> MarginContainer:
	var m: MarginContainer = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 48)
	m.add_theme_constant_override("margin_right", 48)
	m.add_theme_constant_override("margin_top", 40)
	m.add_theme_constant_override("margin_bottom", 40)
	return m


# ==============================================================================
# LAYOUT 1: 经典双栏加高信息区（左：16:9 大预览 + 340px 宽舒规则/按键 · 右：整高玩家列表 + 准备台）
# ==============================================================================
func _build_layout_1_tall_split() -> Control:
	var players: Array[Dictionary] = _mock_players()
	var margin: MarginContainer = _wrap_margin()
	var cols: HBoxContainer = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	margin.add_child(cols)

	# Left (~64%): Large Preview (~630px tall) + Spacious Info Card (~340px tall)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.85
	left.add_theme_constant_override("separation", 22)
	cols.add_child(left)

	var preview: Panel = _make_preview_card()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.size_flags_stretch_ratio = 1.82
	left.add_child(preview)

	var info_card: PanelContainer = PanelContainer.new()
	info_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_card.size_flags_stretch_ratio = 1.0
	info_card.add_theme_stylebox_override("panel", _box(GLASS_BG, GLASS_BORDER, 2, RADIUS, 28, 24, 20))
	left.add_child(info_card)

	var info_cols: HBoxContainer = HBoxContainer.new()
	info_cols.add_theme_constant_override("separation", 30)
	info_card.add_child(info_cols)

	var rules_b: VBoxContainer = _make_rules_block(21)
	rules_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules_b.size_flags_stretch_ratio = 1.05
	info_cols.add_child(rules_b)

	info_cols.add_child(VSeparator.new())

	var ctrl_b: VBoxContainer = _make_controls_block(2, 28, 19)
	ctrl_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctrl_b.size_flags_stretch_ratio = 1.15
	info_cols.add_child(ctrl_b)

	# Right (~36%): Full-height Ready Station (Roster + Action Footer)
	var right_card: PanelContainer = PanelContainer.new()
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_card.size_flags_stretch_ratio = 1.0
	right_card.add_theme_stylebox_override("panel", _box(GLASS_BG, GLASS_BORDER, 2, RADIUS, 24, 24, 22))
	cols.add_child(right_card)

	var rv: VBoxContainer = VBoxContainer.new()
	rv.add_theme_constant_override("separation", 16)
	right_card.add_child(rv)

	var roster: VBoxContainer = _make_roster_block(players, 1)
	roster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(roster)

	rv.add_child(HSeparator.new())
	rv.add_child(_make_action_footer())
	return margin


# ==============================================================================
# LAYOUT 2: 右栏纵置说明版（左：16:9 大预览 + 下 2 列玩家卡 · 右：超大纵置规则/按键卡 + 底部准备台）
# ==============================================================================
func _build_layout_2_right_editorial() -> Control:
	var players: Array[Dictionary] = _mock_players()
	var margin: MarginContainer = _wrap_margin()
	var cols: HBoxContainer = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	margin.add_child(cols)

	# Left (~58%): Huge 16:9 Preview + 2-column Lobby Player Roster Card below
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.42
	left.add_theme_constant_override("separation", 22)
	cols.add_child(left)

	var preview: Panel = _make_preview_card()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.size_flags_stretch_ratio = 1.65
	left.add_child(preview)

	var roster_card: PanelContainer = PanelContainer.new()
	roster_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_card.size_flags_stretch_ratio = 1.0
	roster_card.add_theme_stylebox_override("panel", _box(GLASS_BG, GLASS_BORDER, 2, RADIUS, 24, 20, 20))
	left.add_child(roster_card)
	roster_card.add_child(_make_roster_block(players, 2))

	# Right (~42%): Huge vertical Rules + Controls card (top) + Ready Station (bottom)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	right.add_theme_constant_override("separation", 22)
	cols.add_child(right)

	var brief_card: PanelContainer = PanelContainer.new()
	brief_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	brief_card.add_theme_stylebox_override("panel", _box(GLASS_BG, GLASS_BORDER, 2, RADIUS, 28, 24, 20))
	right.add_child(brief_card)

	var bv: VBoxContainer = VBoxContainer.new()
	bv.add_theme_constant_override("separation", 20)
	brief_card.add_child(bv)

	var rules_b: VBoxContainer = _make_rules_block(22)
	rules_b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules_b.size_flags_stretch_ratio = 1.05
	bv.add_child(rules_b)

	bv.add_child(HSeparator.new())

	var ctrl_b: VBoxContainer = _make_controls_block(2, 28, 19)
	ctrl_b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ctrl_b.size_flags_stretch_ratio = 1.0
	bv.add_child(ctrl_b)

	var act_card: PanelContainer = PanelContainer.new()
	act_card.add_theme_stylebox_override("panel", _box(GLASS_BG, GLASS_BORDER, 2, RADIUS, 24, 20, 20))
	right.add_child(act_card)
	act_card.add_child(_make_action_footer())

	return margin


# ==============================================================================
# LAYOUT 3: 四宫格均衡版（上：exact 16:9 大预览 + 超大规则按键卡 · 下：2 列宽玩家卡 + 右下准备台）
# ==============================================================================
func _build_layout_3_quadrant() -> Control:
	var players: Array[Dictionary] = _mock_players()
	var margin: MarginContainer = _wrap_margin()
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 24)
	margin.add_child(rows)

	# Top Row (~61% height): 16:9 Preview (59%) + Huge Rules/Controls Card (41%)
	var top: HBoxContainer = HBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.size_flags_stretch_ratio = 1.62
	top.add_theme_constant_override("separation", 24)
	rows.add_child(top)

	var preview: Panel = _make_preview_card()
	preview.size_flags_stretch_ratio = 1.42
	top.add_child(preview)

	var brief_card: PanelContainer = PanelContainer.new()
	brief_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brief_card.size_flags_stretch_ratio = 1.0
	brief_card.add_theme_stylebox_override("panel", _box(GLASS_BG, GLASS_BORDER, 2, RADIUS, 28, 24, 20))
	top.add_child(brief_card)

	var bv: VBoxContainer = VBoxContainer.new()
	bv.add_theme_constant_override("separation", 18)
	brief_card.add_child(bv)

	var rules_b: VBoxContainer = _make_rules_block(21)
	rules_b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules_b.size_flags_stretch_ratio = 1.05
	bv.add_child(rules_b)

	bv.add_child(HSeparator.new())

	var ctrl_b: VBoxContainer = _make_controls_block(2, 28, 19)
	ctrl_b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ctrl_b.size_flags_stretch_ratio = 1.0
	bv.add_child(ctrl_b)

	# Bottom Row (~39% height): Wide 2-col Roster Card (68%) + Dedicated Ready Station Card (32%)
	var bot: HBoxContainer = HBoxContainer.new()
	bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bot.size_flags_stretch_ratio = 1.0
	bot.add_theme_constant_override("separation", 24)
	rows.add_child(bot)

	var roster_card: PanelContainer = PanelContainer.new()
	roster_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_card.size_flags_stretch_ratio = 2.15
	roster_card.add_theme_stylebox_override("panel", _box(GLASS_BG, GLASS_BORDER, 2, RADIUS, 24, 20, 20))
	bot.add_child(roster_card)
	roster_card.add_child(_make_roster_block(players, 2))

	var act_card: PanelContainer = PanelContainer.new()
	act_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_card.size_flags_stretch_ratio = 1.0
	act_card.add_theme_stylebox_override("panel", _box(GLASS_BG, GLASS_BORDER, 2, RADIUS, 24, 22, 20))
	bot.add_child(act_card)

	var act_center: VBoxContainer = VBoxContainer.new()
	act_center.alignment = BoxContainer.ALIGNMENT_CENTER
	act_center.add_child(_make_action_footer())
	act_card.add_child(act_center)

	return margin


# ==============================================================================
# LAYOUT 4: 独立三卡底栏版（上：16:9 大预览 + 玩家列表卡 · 下：独立大规则卡 + 独立大按键卡 + 右下准备台）
# ==============================================================================
func _build_layout_4_three_cards_bottom() -> Control:
	var players: Array[Dictionary] = _mock_players()
	var margin: MarginContainer = _wrap_margin()
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 24)
	margin.add_child(rows)

	# Top Row (~61% height): 16:9 Large Preview (62%) + Player Roster Card (38%)
	var top: HBoxContainer = HBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.size_flags_stretch_ratio = 1.62
	top.add_theme_constant_override("separation", 24)
	rows.add_child(top)

	var preview: Panel = _make_preview_card()
	preview.size_flags_stretch_ratio = 1.60
	top.add_child(preview)

	var roster_card: PanelContainer = PanelContainer.new()
	roster_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_card.size_flags_stretch_ratio = 1.0
	roster_card.add_theme_stylebox_override("panel", _box(GLASS_BG, GLASS_BORDER, 2, RADIUS, 24, 20, 20))
	top.add_child(roster_card)
	roster_card.add_child(_make_roster_block(players, 1))

	# Bottom Row (~39% height): Standalone Rules Card + Standalone Controls Card + Ready Station Card
	var bot: HBoxContainer = HBoxContainer.new()
	bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bot.size_flags_stretch_ratio = 1.0
	bot.add_theme_constant_override("separation", 24)
	rows.add_child(bot)

	var rules_card: PanelContainer = PanelContainer.new()
	rules_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules_card.size_flags_stretch_ratio = 1.35
	rules_card.add_theme_stylebox_override("panel", _box(GLASS_BG, GLASS_BORDER, 2, RADIUS, 26, 22, 20))
	bot.add_child(rules_card)
	rules_card.add_child(_make_rules_block(21))

	var ctrl_card: PanelContainer = PanelContainer.new()
	ctrl_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctrl_card.size_flags_stretch_ratio = 1.28
	ctrl_card.add_theme_stylebox_override("panel", _box(GLASS_BG, GLASS_BORDER, 2, RADIUS, 26, 22, 20))
	bot.add_child(ctrl_card)
	ctrl_card.add_child(_make_controls_block(2, 28, 19))

	var act_card: PanelContainer = PanelContainer.new()
	act_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_card.size_flags_stretch_ratio = 1.0
	act_card.add_theme_stylebox_override("panel", _box(GLASS_BG, GLASS_BORDER, 2, RADIUS, 24, 22, 20))
	bot.add_child(act_card)

	var act_center: VBoxContainer = VBoxContainer.new()
	act_center.alignment = BoxContainer.ALIGNMENT_CENTER
	act_center.add_child(_make_action_footer())
	act_card.add_child(act_center)

	return margin
