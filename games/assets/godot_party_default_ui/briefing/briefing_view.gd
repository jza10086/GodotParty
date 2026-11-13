## Optional presentation only. Games supply content and authoritative readiness snapshots.
## This view does not start gameplay or interpret transport messages.
extends Control

signal ready_requested()
signal choice_selected(value: String)

const MUTED: Color = Color(0.6, 0.64, 0.7)
const ACCENT: Color = Color(0.5843, 0.7804, 0.9255)
const GREEN: Color = Color("a6c8a7")
const ACTION_THEME: Theme = preload("res://games/assets/godot_party_default_ui/source/ui/lobby_action_theme.tres")

@export var player_row_scene: PackedScene
@export var control_hint_scene: PackedScene
var _content: Dictionary = {}
var _rows: Array[Dictionary] = []
var _local_can_ready: bool = false
var _local_ready: bool = false
var _countdown: int = -1
var _status: String = ""
var _roster_rows: Dictionary[String, Panel] = {}
var _live_roster: bool = false
var _has_state: bool = false
var _initialized: bool = false
var _hint_hovered: bool = false
var _hint_pressed: bool = false
var _hint_enabled: bool = false
var _hint_ready: bool = false
var _hint_tween: Tween

@onready var _title: Label = %Title
@onready var _cover: TextureRect = %Cover
@onready var _video: VideoStreamPlayer = %Video
@onready var _fallback: Control = %Fallback
@onready var _introduction: Label = %Introduction
@onready var _controls: VBoxContainer = %Controls
@onready var _roster: VBoxContainer = %Roster
@onready var _choice: OptionButton = %PlayerChoice
@onready var _input_hint: HBoxContainer = %ReadyHints.get_node("KeyboardHints/Accept")

func _ready() -> void:
	_input_hint.gui_input.connect(_ready_hint_input)
	_input_hint.mouse_entered.connect(_set_hint_hovered.bind(true))
	_input_hint.mouse_exited.connect(_set_hint_hovered.bind(false))
	_input_hint.resized.connect(_center_hint_pivot)
	visibility_changed.connect(_reset_hidden_hint)
	get_window().focus_exited.connect(_set_hint_hovered.bind(false))
	_choice.get_popup().max_size = Vector2i(1920, 320)
	_choice.item_selected.connect(func(index: int) -> void: choice_selected.emit(_choice.get_item_text(index)))
	_video.finished.connect(_sync_video)
	visibility_changed.connect(_sync_video)
	tree_exiting.connect(_video.stop)
	_initialized = true
	_update_hint_feedback()
	assert(player_row_scene != null and control_hint_scene != null, "Assign briefing row scenes")
	if not _content.is_empty():
		_render_content()
	if _has_state:
		_render_state()

## cover is an optional Texture2D, video an optional local VideoStream.
## Bindings are already resolved on this client by the owning game.
func configure(content: Dictionary) -> void:
	_content = content.duplicate()
	if _initialized:
		_render_content()

## The public state contract retains technical and manual flags; each row displays one concise state.
func set_state(rows: Array[Dictionary], local_can_ready: bool, local_ready: bool, countdown: int = -1, status: String = "") -> void:
	_has_state = true
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
		var prompt: VBoxContainer = control_hint_scene.instantiate()
		_controls.add_child(prompt)
		prompt.get_node("Binding").text = str(item.get("binding", "未绑定"))
		prompt.get_node("Description").text = str(item.get("description", ""))

func _sync_video() -> void:
	if not _initialized:
		return
	if is_visible_in_tree() and _video.visible and _video.stream != null:
		if not _video.is_playing():
			_video.play()
	else:
		_video.stop()

func _render_state() -> void:
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

## Keep live rows by player ID; editor examples never enter the runtime roster.
func _render_roster() -> void:
	if not _live_roster:
		for child: Node in _roster.get_children():
			_roster.remove_child(child)
			child.queue_free()
		_live_roster = true
	var active_ids: Array[String] = []
	for player: Dictionary in _rows:
		if not player.connected or active_ids.size() == 8:
			continue
		var id: String = player.player_id
		active_ids.append(id)
		if not _roster_rows.has(id):
			var card: Panel = player_row_scene.instantiate()
			_roster.add_child(card)
			_roster_rows[id] = card
		var card: Panel = _roster_rows[id]
		_roster.move_child(card, active_ids.size() - 1)
		var line: HBoxContainer = card.get_node("Line")
		var display_name: Label = line.get_node("Name")
		display_name.text = player.name
		display_name.tooltip_text = player.name
		var choice_label: Label = line.get_node("Choice")
		choice_label.text = player.get("choice", "")
		choice_label.visible = not choice_label.text.is_empty()
		var confirmed: bool = player.get("ready", false) or not player.get("participant", true)
		var state: Label = line.get_node("State")
		state.text = "加载中" if not player.get("loaded", false) else ("已准备" if confirmed else "未准备")
		state.modulate = GREEN if state.text == "已准备" else (ACCENT if state.text == "未准备" else MUTED)
	for id: String in _roster_rows.keys():
		if id not in active_ids:
			var card: Panel = _roster_rows[id]
			_roster.remove_child(card)
			card.queue_free()
			_roster_rows.erase(id)
