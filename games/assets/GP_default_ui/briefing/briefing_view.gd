## Optional presentation only. Games supply content and authoritative readiness snapshots.
## Minigames inherit this view to override default content or mount custom pre-round controls
## (for example difficulty selection in GP_rhythm_game) inside %ExtraSlot.
extends Control

signal ready_requested()
signal choice_selected(value: String)

const MAX_ROSTER_PLAYERS: int = 12
const DEFAULT_PLAYER_COLOR: Color = Color(0.58, 0.78, 0.94, 1.0)
const BRIGHT_TEXT: Color = Color(0.96, 0.97, 0.99, 1.0)
const MUTED_TEXT: Color = Color(0.66, 0.74, 0.83, 1.0)
const READY_TAG_BG: Color = Color(0.14, 0.58, 0.35, 0.94)
const WAIT_TAG_BG: Color = Color(0.14, 0.20, 0.28, 0.78)

@export var player_row_scene: PackedScene
@export var control_hint_scene: PackedScene

var _content: Dictionary = {}
var _rows: Array[Dictionary] = []
var _local_can_ready: bool = false
var _local_ready: bool = false
var _countdown: int = -1
var _status: String = ""
var _roster_rows: Dictionary[String, PanelContainer] = {}
var _live_roster: bool = false
var _has_state: bool = false
var _initialized: bool = false

@onready var _title: Label = %Title
@onready var _cover: TextureRect = %Cover
@onready var _video: VideoStreamPlayer = %Video
@onready var _fallback: Control = %Fallback
@onready var _introduction: Label = %Introduction
@onready var _controls: GridContainer = %Controls
@onready var _roster: GridContainer = %Roster
@onready var _ready_button: Button = %ReadyButton
@onready var _extra_slot: VBoxContainer = %ExtraSlot


func _ready() -> void:
	_ready_button.pressed.connect(_on_ready_button_pressed)
	_video.finished.connect(_sync_video)
	visibility_changed.connect(_sync_video)
	tree_exiting.connect(_video.stop)
	_initialized = true
	assert(player_row_scene != null and control_hint_scene != null, "Assign briefing row scenes")
	if _extra_slot != null:
		_extra_slot.visible = _extra_slot.get_child_count() > 0
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


## Virtual hook for inheriting briefing views that expose a per-player choice (e.g. difficulty).
func set_choice(_value: String) -> void:
	pass


func focus_ready() -> void:
	if _initialized and _can_submit_ready() and is_visible_in_tree():
		_ready_button.grab_focus()


func _can_submit_ready() -> bool:
	return _local_can_ready and (_countdown < 0 or _local_ready)


func _on_ready_button_pressed() -> void:
	if _can_submit_ready():
		ready_requested.emit()


func _shortcut_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _can_submit_ready() or not event is InputEventKey:
		return
	if event.echo or not event.is_action_pressed(&"ui_accept"):
		return
	# A menu, settings page or other dialog owns its keys; never confirm behind it.
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and focused != self and not is_ancestor_of(focused):
		return
	if focused == _ready_button:
		return
	get_viewport().set_input_as_handled()
	ready_requested.emit()


func _render_content() -> void:
	_title.text = str(_content.get("title", "")).trim_prefix("GodotPartyDefault · ")
	_title.tooltip_text = _title.text
	_introduction.text = str(_content.get("introduction", ""))
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
	var has_custom_hints: bool = %ControlSection.has_node("BriefingHints")
	var show_controls: bool = not controls.is_empty() or has_custom_hints
	%Divider.visible = show_controls
	%ControlsTitle.visible = show_controls
	%ControlSection.visible = show_controls
	for item: Dictionary in controls:
		var prompt: Control = control_hint_scene.instantiate() as Control
		_controls.add_child(prompt)
		(prompt.get_node("%Binding") as Label).text = str(item.get("binding", "未绑定"))
		(prompt.get_node("%Description") as Label).text = str(item.get("description", ""))


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
	var can_submit: bool = _can_submit_ready()
	_ready_button.disabled = not can_submit
	if _countdown >= 0:
		_ready_button.text = ("取消准备 · %d 秒后开始" if _local_ready else "%d 秒后开始") % maxi(0, _countdown)
	elif can_submit and _status.begins_with("准备消息发送失败"):
		_ready_button.text = _status
	elif not can_submit and not _local_ready:
		_ready_button.text = "观战中" if _status.begins_with("你正在观战") else "加载中"
	else:
		_ready_button.text = "取消准备" if _local_ready else "准备"
	_ready_button.set("semantic_color", "red" if _local_ready else "green")
	_ready_button.set("enabled_state", _local_ready)
	if can_submit:
		_focus_when_free.call_deferred()


## Loading never steals focus from a settings dialog or the application's menu.
func _focus_when_free() -> void:
	if is_inside_tree() and get_viewport().gui_get_focus_owner() == null:
		focus_ready()


func _parse_player_color(raw: Variant) -> Color:
	if raw is Color:
		return raw as Color
	if raw is String and Color.html_is_valid(raw as String):
		return Color.from_string(raw as String, DEFAULT_PLAYER_COLOR)
	return DEFAULT_PLAYER_COLOR


## Keep live rows by player ID (up to 12 players); editor examples never enter the runtime roster.
func _render_roster() -> void:
	if not _live_roster:
		for child: Node in _roster.get_children():
			_roster.remove_child(child)
			child.queue_free()
		_live_roster = true

	var connected_players: Array[Dictionary] = []
	for player: Dictionary in _rows:
		if player.get("connected", true) and connected_players.size() < MAX_ROSTER_PLAYERS:
			connected_players.append(player)

	var compact: bool = connected_players.size() > 4
	var active_ids: Array[String] = []
	for player: Dictionary in connected_players:
		var id: String = str(player.get("player_id", ""))
		active_ids.append(id)
		if not _roster_rows.has(id):
			var card: PanelContainer = player_row_scene.instantiate() as PanelContainer
			_roster.add_child(card)
			_roster_rows[id] = card
		var card: PanelContainer = _roster_rows[id]
		_roster.move_child(card, active_ids.size() - 1)
		card.custom_minimum_size.y = 44.0 if compact else 54.0

		var loaded: bool = bool(player.get("loaded", false))
		var confirmed: bool = bool(player.get("ready", false)) or not bool(player.get("participant", true))
		var pcol: Color = _parse_player_color(player.get("color"))

		var panel_style: StyleBoxFlat = card.get_theme_stylebox(&"panel") as StyleBoxFlat
		if panel_style != null:
			panel_style.border_color = Color(pcol.r, pcol.g, pcol.b, 0.92 if loaded else 0.42)

		var display_name: Label = card.get_node("%Name") as Label
		display_name.text = str(player.get("name", ""))
		display_name.tooltip_text = display_name.text
		display_name.add_theme_font_size_override(&"font_size", 18 if compact else 20)
		display_name.add_theme_color_override(&"font_color", pcol if loaded else Color(pcol.r, pcol.g, pcol.b, 0.58))

		var choice_badge: PanelContainer = card.get_node("%ChoiceBadge") as PanelContainer
		var choice_label: Label = card.get_node("%Choice") as Label
		var choice_text: String = str(player.get("choice", ""))
		choice_label.text = choice_text
		choice_label.add_theme_font_size_override(&"font_size", 14 if compact else 15)
		choice_badge.visible = not choice_text.is_empty()

		var state_badge: PanelContainer = card.get_node("%StateBadge") as PanelContainer
		var state_label: Label = card.get_node("%State") as Label
		var is_ready_tag: bool = loaded and confirmed
		state_label.text = "加载中" if not loaded else ("已准备" if confirmed else "未准备")
		state_label.add_theme_font_size_override(&"font_size", 14 if compact else 15)
		state_label.add_theme_color_override(&"font_color", BRIGHT_TEXT if is_ready_tag else MUTED_TEXT)
		var state_style: StyleBoxFlat = state_badge.get_theme_stylebox(&"panel") as StyleBoxFlat
		if state_style != null:
			state_style.bg_color = READY_TAG_BG if is_ready_tag else WAIT_TAG_BG

	for id: String in _roster_rows.keys():
		if id not in active_ids:
			var card: PanelContainer = _roster_rows[id]
			_roster.remove_child(card)
			card.queue_free()
			_roster_rows.erase(id)
