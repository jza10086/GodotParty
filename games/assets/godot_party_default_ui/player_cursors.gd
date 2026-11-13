extends Control
## Opt-in pointer surface. Coordinates are presentation only, never gameplay input.
## Call setup(api) before insertion; cursor updates use unreliable ordered messages.
const CursorScene: PackedScene = preload("res://games/assets/godot_party_default_ui/appearance/player_cursor.tscn")
const SEND_INTERVAL: float = 0.05
const EXPIRY_MSEC: int = 1500
const IDLE_INTERVAL: float = 0.5
const POSITION_THRESHOLD: float = 0.001
var _sent_point: Vector2 = Vector2.ZERO
var _sent_visible: bool = false

var api: PartyAPI
var local_id: String = ""
var enabled: bool = true
var points: Dictionary[String, Dictionary] = {}
var stamps: Dictionary[String, int] = {}
var sequence: int = 0
var _clock: float = 0.0
var _visuals: Dictionary[String, Node2D] = {}
var _owns_mouse: bool = false
var _network_failed: bool = false

## The scope owns membership and appearance; the overlay owns only temporary pointer state.
func setup(value: PartyAPI) -> void:
	api = value
	for player: Dictionary in api.get_players():
		if player.is_local:
			local_id = player.player_id
	api.net.message_received.connect(_message)
	api.on_close(_suspend)

func _ready() -> void:
	assert(api != null, "PlayerCursors requires setup(api) before entering the tree.")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if not api.is_open():
		_suspend()
		return
	var active: bool = enabled and not _network_failed and is_visible_in_tree()
	var point: Vector2 = get_local_mouse_position() / size.max(Vector2.ONE)
	var local_visible: bool = active and get_window().has_focus() and Rect2(Vector2.ZERO, Vector2.ONE).has_point(point)
	local_visible = local_visible and (Input.mouse_mode == Input.MOUSE_MODE_VISIBLE or _owns_mouse and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN)
	_clock += delta
	var changed: bool = local_visible != _sent_visible or (local_visible and point.distance_to(_sent_point) >= POSITION_THRESHOLD)
	if not _network_failed and _clock >= SEND_INTERVAL and not local_id.is_empty() and (changed or _clock >= IDLE_INTERVAL):
		_clock = 0.0
		sequence += 1
		_sent_point = point
		_sent_visible = local_visible
		_check_send(api.net.send_to_host(&"pointer", {
			"seq": sequence, "visible": local_visible,
			"x": clampf(point.x, 0, 1), "y": clampf(point.y, 0, 1)
		}, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, 1))
	var show_others: bool = active and bool(api.config.get_common(&"ui.player_cursors"))
	var remote_alpha: float = 1.0 - float(api.config.get_common(&"ui.player_cursor_transparency")) / 100.0
	var now: int = Time.get_ticks_msec()
	var show_local: bool = false
	for player: Dictionary in api.get_players():
		var id: String = player.player_id
		if not _visuals.has(id):
			var visual: Node2D = CursorScene.instantiate()
			_visuals[id] = visual
			visual.hide()
			add_child(visual)
		var visual: Node2D = _visuals[id]
		visual.cursor_theme = api.config.get_common(&"ui.cursor_theme")
		visual.apply_color(Color(api.get_appearance(id).color))
		if id == local_id:
			show_local = local_visible and player.connected and not _network_failed
			visual.visible = show_local
			visual.position = point * size
			continue
		visual.modulate.a = remote_alpha
		var data: Dictionary = points.get(id, {})
		var shown: bool = show_others and player.connected and data.get("visible", false) and now - stamps.get(id, 0) <= EXPIRY_MSEC
		if shown:
			var target: Vector2 = Vector2(data.x, data.y) * size
			visual.position = visual.position.lerp(target, 1.0 - exp(-25.0 * delta)) if visual.visible else target
		visual.visible = shown
	if show_local and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		_owns_mouse = true
	elif not show_local:
		_release_mouse()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED:
		_suspend()

func _suspend() -> void:
	_release_mouse()
	for visual: Node2D in _visuals.values():
		visual.hide()
	queue_redraw()

func _exit_tree() -> void:
	_release_mouse()
	if api != null:
		api.net.message_received.disconnect(_message)

func _release_mouse() -> void:
	if _owns_mouse:
		if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_owns_mouse = false

func _check_send(error: Error) -> void:
	if error != OK:
		_network_failed = true
		push_error("Player cursor synchronization failed: " + error_string(error))
		_release_mouse()

func _message(sender: Dictionary, topic: StringName, data: Variant) -> void:
	if not api.is_open() or _network_failed or not data is Dictionary:
		return
	if topic == &"pointer" and api.is_host():
		if not valid_point(data):
			return
		for player: Dictionary in api.get_players():
			var id: String = player.player_id
			if player.connected and id in sender.player_ids:
				var previous: Dictionary = points.get(id, {})
				if int(data.seq) <= int(previous.get("seq", -1)):
					return
				var now: int = Time.get_ticks_msec()
				if now - stamps.get(id, -1000) < 30:
					return
				stamps[id] = now
				points[id] = data.duplicate()
				_check_send(api.net.send_to_group(&"cursors", {"id": id, "point": data}, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, "instance", true))
				return
	elif topic == &"cursors" and int(sender.peer_id) == 1:
		if not data.get("id") is String or not data.get("point") is Dictionary or not valid_point(data.point):
			return
		var id: String = data.id
		var connected: bool = false
		for player: Dictionary in api.get_players():
			if player.player_id == id and player.connected:
				connected = true
				break
		if not connected or int(data.point.seq) < int(points.get(id, {}).get("seq", -1)):
			return
		points[id] = data.point.duplicate()
		stamps[id] = Time.get_ticks_msec()

## Network boundary: reject malformed, non-finite, out-of-range and invalid sequence values.
static func valid_point(data: Dictionary) -> bool:
	return data.get("seq") is int and data.seq > 0 and data.get("visible") is bool and (data.get("x") is float or data.get("x") is int) and (data.get("y") is float or data.get("y") is int) and is_finite(float(data.x)) and is_finite(float(data.y)) and float(data.x) >= 0 and float(data.x) <= 1 and float(data.y) >= 0 and float(data.y) <= 1

func _draw() -> void:
	if api == null or not api.is_open():
		return
	var font: Font = get_theme_default_font()
	for player: Dictionary in api.get_players():
		var id: String = player.player_id
		if id == local_id or not _visuals.has(id) or not _visuals[id].visible:
			continue
		var visual: Node2D = _visuals[id]
		var label_position: Vector2 = visual.position + Vector2(30, 31)
		draw_string_outline(font, label_position, player.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, Color(Color("#141820"), visual.modulate.a))
		draw_string(font, label_position, player.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 1.0, 1.0, visual.modulate.a))
