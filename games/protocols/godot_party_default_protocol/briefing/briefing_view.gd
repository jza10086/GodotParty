## Optional presentation only. Games supply content and authoritative readiness snapshots.
## This view does not start gameplay or interpret transport messages.
extends Control

signal ready_requested()
signal choice_selected(value: String)

const PANEL_SCENE: PackedScene = preload("res://core/ui/ambient_reveal/components/panel.tscn")
const LABEL: PackedScene = preload("res://core/ui/ambient_reveal/components/display/label.tscn")
const INK: Color = Color(0.96, 0.97, 0.99)
const MUTED: Color = Color(0.6, 0.64, 0.7)
const ACCENT: Color = Color(0.5843, 0.7804, 0.9255)
const GREEN: Color = Color("a6c8a7")
const ACTION_THEME: Theme = preload("res://core/ui/source/ui/lobby_action_theme.tres")

@export var top_inset: int = 64
var _content: Dictionary = {}
var _rows: Array[Dictionary] = []
var _local_can_ready: bool = false
var _local_ready: bool = false
var _countdown: int = -1
var _status: String = ""
var _rows_hash: int = -1
var _initialized: bool = false
var _compact: bool = false
var _hint_hovered: bool = false
var _hint_pressed: bool = false
var _hint_enabled: bool = false
var _hint_ready: bool = false
var _hint_tween: Tween

@onready var _layout: MarginContainer = %Layout
@onready var _title: Label = %Title
@onready var _cover: TextureRect = %Cover
@onready var _video: VideoStreamPlayer = %Video
@onready var _fallback: Control = %Fallback
@onready var _introduction: Label = %Introduction
@onready var _controls: VBoxContainer = %Controls
@onready var _roster: VBoxContainer = %Roster
@onready var _choice: OptionButton = %PlayerChoice
@onready var _input_hint: HBoxContainer = %ReadyHints.get_node("KeyboardHints/Accept")

class PreviewArt extends Control:
	func _draw() -> void:
		var middle: Vector2 = size * Vector2(0.5, 0.48)
		var radius: float = minf(size.x * 0.21, size.y * 0.34)
		draw_arc(middle, radius * 1.75, 0.0, TAU, 80, Color(0.6, 0.65, 0.8, 0.1), 2.0, true)
		draw_arc(middle, radius * 1.24, 0.0, TAU, 60, Color(0.6, 0.65, 0.8, 0.13), 2.0, true)
		var colors: Array[Color] = [Color("ffd18f"), Color("9fc9e8"), Color("b8a7e5"), Color("9fd5b4")]
		for index: int in range(4):
			var angle: float = -0.68 + float(index) * TAU / 4.0
			var center: Vector2 = middle + Vector2(cos(angle), sin(angle)) * radius * 0.88
			var side: float = radius * 0.54
			var corners: PackedVector2Array = []
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				corners.append(center + (corner * side).rotated(angle * 0.17))
			draw_colored_polygon(corners, colors[index])
			var eye_offset: float = side * 0.28
			draw_circle(center + Vector2(-eye_offset, -side * 0.08), side * 0.07, Color("292b36"))
			draw_circle(center + Vector2(eye_offset, -side * 0.08), side * 0.07, Color("292b36"))
			draw_line(center + Vector2(-eye_offset * 0.5, side * 0.30), center + Vector2(eye_offset * 0.5, side * 0.30), Color("292b36"), maxf(2.0, side * 0.04), true)
		var star: Vector2 = middle + Vector2(radius * 1.70, -radius * 0.80)
		draw_line(star - Vector2(10, 0), star + Vector2(10, 0), Color("ffd18f"), 3.0, true)
		draw_line(star - Vector2(0, 10), star + Vector2(0, 10), Color("ffd18f"), 3.0, true)

func _ready() -> void:
	# Reuse the main menu's complete hint strip, exposing only this page's available action.
	%ReadyHints.set_mode(false, false)
	for prompt: Control in %ReadyHints.get_node("KeyboardHints").get_children():
		prompt.visible = prompt == _input_hint
	_input_hint.description = "准备"
	_input_hint.set_gamepad(false)
	_input_hint.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_hint.gui_input.connect(_ready_hint_input)
	_input_hint.mouse_entered.connect(_set_hint_hovered.bind(true))
	_input_hint.mouse_exited.connect(_set_hint_hovered.bind(false))
	_input_hint.resized.connect(_center_hint_pivot)
	visibility_changed.connect(_reset_hidden_hint)
	get_window().focus_exited.connect(_set_hint_hovered.bind(false))
	var art: PreviewArt = PreviewArt.new()
	art.name = "OriginalPreviewArt"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fallback.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.resized.connect(art.queue_redraw)
	_choice.get_popup().max_size = Vector2i(1920, 320)
	_choice.item_selected.connect(func(index: int) -> void: choice_selected.emit(_choice.get_item_text(index)))
	_video.finished.connect(_sync_video)
	visibility_changed.connect(_sync_video)
	tree_exiting.connect(_video.stop)
	resized.connect(_resize_layout)
	%RightColumn.resized.connect(_resize_preview)
	_initialized = true
	_resize_layout()
	_render_content()
	_render_state()

## cover is an optional Texture2D, video an optional local VideoStream.
## Bindings are already resolved on this client by the owning game.
func configure(content: Dictionary) -> void:
	_content = content.duplicate()
	if _initialized:
		_render_content()

## The public state contract retains technical and manual flags; each row displays one concise state.
func set_state(rows: Array[Dictionary], local_can_ready: bool, local_ready: bool, countdown: int = -1, status: String = "") -> void:
	_rows = rows.duplicate(true)
	_local_can_ready = local_can_ready
	_local_ready = local_ready
	_countdown = countdown
	_status = status
	if _initialized:
		_render_state()

func set_choice(value: String) -> void:
	for index: int in range(_choice.item_count):
		if _choice.get_item_text(index) == value:
			_choice.select(index)
			return

func focus_ready() -> void:
	if _initialized and _can_submit_ready() and is_visible_in_tree():
		grab_focus()

func _can_submit_ready() -> bool:
	return _local_can_ready and (_countdown < 0 or _local_ready)

## Confirm on release so pressing shows feedback and dragging away cancels.
func _ready_hint_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _can_submit_ready() or _choice.get_popup().visible:
		return
	var submit: bool = _hint_pressed and not event.pressed and Rect2(Vector2.ZERO, _input_hint.size).has_point(event.position)
	_hint_pressed = event.pressed
	_update_hint_feedback()
	if submit:
		ready_requested.emit()

func _set_hint_hovered(hovered: bool) -> void:
	_hint_hovered = hovered
	if not hovered:
		_hint_pressed = false
	_update_hint_feedback()

func _center_hint_pivot() -> void:
	_input_hint.pivot_offset = _input_hint.size * 0.5

func _reset_hidden_hint() -> void:
	if not is_visible_in_tree():
		_hint_hovered = false
		_hint_pressed = false
		_update_hint_feedback()

func _update_hint_feedback() -> void:
	if _hint_tween != null:
		_hint_tween.kill()
	_center_hint_pivot()
	var active: bool = _can_submit_ready() and is_visible_in_tree()
	var variation: StringName = &"CancelRed" if _local_ready else &"ReadyGreen"
	var style: StyleBoxFlat = ACTION_THEME.get_stylebox(&"normal", variation)
	var tint: Color = style.bg_color
	var zoom: float = 1.0
	if active and _hint_pressed:
		tint = ACTION_THEME.get_stylebox(&"pressed", variation).bg_color
		zoom = 0.96
	elif active and _hint_hovered:
		tint = ACTION_THEME.get_stylebox(&"hover", variation).bg_color
		zoom = 1.025
	if not is_visible_in_tree():
		_input_hint.scale = Vector2.ONE
		_input_hint.modulate = Color(tint.r, tint.g, tint.b, _input_hint.modulate.a)
		return
	_hint_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var duration: float = 0.08 if _hint_pressed else 0.16
	_hint_tween.tween_property(_input_hint, "scale", Vector2.ONE * zoom, duration)
	_hint_tween.tween_property(_input_hint, "modulate:r", tint.r, duration)
	_hint_tween.tween_property(_input_hint, "modulate:g", tint.g, duration)
	_hint_tween.tween_property(_input_hint, "modulate:b", tint.b, duration)

func _shortcut_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _can_submit_ready() or not event is InputEventKey:
		return
	if _choice.get_popup().visible or event.echo or not event.is_action_pressed(&"ui_accept"):
		return
	# A menu, settings page or other dialog owns its keys; never confirm behind it.
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != self and (focused == null or not is_ancestor_of(focused)):
		return
	get_viewport().set_input_as_handled()
	ready_requested.emit()

func _render_content() -> void:
	_title.text = str(_content.get("title", "")).trim_prefix("GodotPartyDefault · ")
	_title.tooltip_text = _title.text
	_introduction.text = str(_content.get("introduction", ""))
	var choice_options: Array = _content.get("choice_options", [])
	%ChoiceRow.visible = not choice_options.is_empty()
	%ChoiceTitle.text = str(_content.get("choice_label", ""))
	var chosen: String = _choice.get_item_text(_choice.selected) if _choice.selected >= 0 else str(_content.get("choice_default", ""))
	_choice.clear()
	for option: String in choice_options:
		_choice.add_item(option)
	set_choice(chosen)
	_cover.texture = _content.get("cover") as Texture2D
	var stream: VideoStream = _content.get("video") as VideoStream
	if _video.stream != stream:
		_video.stop()
		_video.stream = stream
	_video.visible = stream != null
	_cover.visible = stream == null and _cover.texture != null
	_fallback.visible = stream == null and _cover.texture == null
	_sync_video()
	for child: Node in _controls.get_children():
		_controls.remove_child(child)
		child.queue_free()
	var controls: Array = _content.get("controls", [])
	%ControlsTitle.visible = not controls.is_empty()
	%ControlSection.visible = not controls.is_empty()
	for item: Dictionary in controls:
		var prompt: VBoxContainer = VBoxContainer.new()
		prompt.add_theme_constant_override("separation", 3)
		_controls.add_child(prompt)
		var binding: Label = _label(prompt, str(item.get("binding", "未绑定")), 20, ACCENT)
		binding.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var description: Label = _label(prompt, str(item.get("description", "")), 20, INK)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resize_layout()

func _sync_video() -> void:
	if not _initialized:
		return
	if is_visible_in_tree() and _video.visible and _video.stream != null:
		if not _video.is_playing():
			_video.play()
	else:
		_video.stop()

func _render_state() -> void:
	var new_hash: int = hash(_rows)
	if new_hash != _rows_hash:
		_rows_hash = new_hash
		_render_roster()
	_choice.disabled = not _can_submit_ready() or _local_ready
	_input_hint.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _can_submit_ready() else Control.CURSOR_ARROW
	if _hint_enabled != _can_submit_ready() or _hint_ready != _local_ready:
		_hint_enabled = _can_submit_ready()
		_hint_ready = _local_ready
		_hint_pressed = false
		_update_hint_feedback()
	_input_hint.modulate.a = 1.0 if _can_submit_ready() or _countdown >= 0 else 0.45
	_input_hint.get_node("Icons").visible = _countdown < 0 or _can_submit_ready()
	if _countdown >= 0:
		_input_hint.description = ("取消准备 · %d 秒后开始" if _local_ready else "%d 秒后开始") % maxi(0, _countdown)
	elif _can_submit_ready() and _status.begins_with("准备消息发送失败"):
		_input_hint.description = _status
	else:
		_input_hint.description = "取消准备" if _local_ready else "准备"
	if _can_submit_ready():
		_focus_when_free.call_deferred()

## Loading never steals focus from a settings dialog or the application's menu.
func _focus_when_free() -> void:
	if is_inside_tree() and get_viewport().gui_get_focus_owner() == null:
		focus_ready()

func _render_roster() -> void:
	for child: Node in _roster.get_children():
		_roster.remove_child(child)
		child.queue_free()
	for player: Dictionary in _rows:
		if player.get("connected", true) and _roster.get_child_count() < 8:
			_player_row(player)
	_resize_rows()

func _player_row(player: Dictionary) -> void:
	var loaded: bool = player.get("loaded", false)
	var confirmed: bool = player.get("ready", false) or not player.get("participant", true)
	var state: String = "加载中" if not loaded else ("已准备" if confirmed else "未准备")
	var card: Panel = PANEL_SCENE.instantiate() as Panel
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster.add_child(card)
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "Line"
	line.add_theme_constant_override("separation", 16)
	card.add_child(line)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var display_name: Label = _label(line, str(player.get("name", "")), 25, INK)
	display_name.name = "Name"
	display_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	display_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	display_name.tooltip_text = display_name.text
	var choice_text: String = player.get("choice", "")
	if not choice_text.is_empty():
		var choice_label: Label = _label(line, choice_text, 21, ACCENT)
		choice_label.name = "Choice"
		choice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var state_label: Label = _label(line, state, 21, GREEN if state == "已准备" else (ACCENT if state == "未准备" else MUTED))
	state_label.name = "State"
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _resize_layout() -> void:
	if not _initialized:
		return
	_compact = size.x < 1500.0 or size.y < 850.0
	var horizontal: int = 64 if not _compact else 48
	var top: int = mini(top_inset, 48) if _compact else top_inset
	var bottom: int = 64 if not _compact else 48
	_layout.add_theme_constant_override("margin_left", horizontal)
	_layout.add_theme_constant_override("margin_right", horizontal)
	_layout.add_theme_constant_override("margin_top", top)
	_layout.add_theme_constant_override("margin_bottom", bottom)
	%Content.custom_minimum_size = Vector2(minf(1400.0 if not _compact else 960.0, maxf(0.0, size.x - horizontal * 2)), maxf(0.0, size.y - top - bottom))
	%Content.add_theme_constant_override("separation", 18 if not _compact else 12)
	%Columns.add_theme_constant_override("separation", 32 if not _compact else 24)
	%LeftColumn.add_theme_constant_override("separation", 20 if not _compact else 14)
	%RightColumn.add_theme_constant_override("separation", 20 if not _compact else 14)
	%LeftColumn.custom_minimum_size.x = 440 if not _compact else 400
	%LeftColumn.size_flags_stretch_ratio = 1.25 if not _compact else 1.6
	_title.add_theme_font_size_override("font_size", 48 if not _compact else 34)
	%Footer.custom_minimum_size.y = 40 if not _compact else 30
	for side: String in ["left", "right", "top", "bottom"]:
		%InformationMargin.add_theme_constant_override("margin_" + side, 22 if not _compact else 14)
	%Information.add_theme_constant_override("separation", 28 if not _compact else 20)
	%Controls.add_theme_constant_override("separation", 18 if not _compact else 8)
	%ControlSection.add_theme_constant_override("separation", 12 if not _compact else 4)
	%InformationPanel.custom_minimum_size.y = 250 if not _compact else 228
	%InformationScroll.custom_minimum_size.y = 80 if not _compact else 60
	%RuleTitle.add_theme_font_size_override("font_size", 24 if not _compact else 20)
	%ControlsTitle.add_theme_font_size_override("font_size", 24 if not _compact else 20)
	_introduction.add_theme_font_size_override("font_size", 21 if not _compact else 18)
	for prompt: VBoxContainer in _controls.get_children():
		for label: Label in prompt.get_children():
			label.add_theme_font_size_override("font_size", 20 if not _compact else 17)
	for label: Node in _input_hint.get_children():
		if label is Label:
			label.add_theme_font_size_override("font_size", 21 if not _compact else 18)
	_resize_rows()
	_resize_preview()

func _resize_preview() -> void:
	# The display viewport itself is 16:9; cover art is fitted without stretching/cropping.
	%PreviewPanel.custom_minimum_size.y = %RightColumn.size.x * 9.0 / 16.0

func _resize_rows() -> void:
	_roster.add_theme_constant_override("separation", 10 if not _compact else 7)
	for card: Panel in _roster.get_children():
		card.custom_minimum_size.y = 68 if not _compact else 48
		var line: HBoxContainer = card.get_node("Line")
		line.offset_left = 18 if not _compact else 12
		line.offset_right = -line.offset_left
		line.get_node("Name").add_theme_font_size_override("font_size", 25 if not _compact else 21)
		line.get_node("State").add_theme_font_size_override("font_size", 21 if not _compact else 18)

func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label: Label = LABEL.instantiate() as Label
	label.theme = theme
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
