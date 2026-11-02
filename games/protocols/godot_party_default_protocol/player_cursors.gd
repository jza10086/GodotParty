extends Control
## Opt-in normalized pointer overlay. Attach to the actual interaction surface.
## The game's manifest declares cursors (ordered/instance); no gameplay uses these positions.
var api: PartyAPI
var local_id: String = ""
var enabled: bool = true
var points: Dictionary = {}
var stamps: Dictionary = {}
var sequence: int = 0
var clock: float = 0.0

func setup(value: PartyAPI) -> void:
	api = value
	for player: Dictionary in api.get_players():
		if player.is_local:
			local_id = player.player_id
	api.net.message_received.connect(_message)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if api == null or not api.is_open():
		return
	clock += delta
	if clock >= 0.067 and not local_id.is_empty():
		clock = 0.0
		var point: Vector2 = get_local_mouse_position() / size.max(Vector2.ONE)
		sequence += 1
		api.net.send_to_host(&"pointer", {"seq": sequence, "visible": enabled and get_window().has_focus() and Rect2(Vector2.ZERO, Vector2.ONE).has_point(point), "x": clampf(point.x, 0, 1), "y": clampf(point.y, 0, 1)})
	queue_redraw()

func _message(sender: Dictionary, topic: StringName, data: Variant) -> void:
	if not data is Dictionary:
		return
	if topic == &"pointer" and api.is_host():
		if not valid_point(data):
			return
		for player: Dictionary in api.get_players():
			var id: String = player.player_id
			if player.connected and id in sender.get("player_ids", []):
				var previous: Dictionary = points.get(id, {})
				if int(data.seq) <= int(previous.get("seq", -1)):
					return
				var now: int = Time.get_ticks_msec()
				if now - int(stamps.get(id, -1000)) < 30:
					return
				stamps[id] = now
				points[id] = data.duplicate()
				api.net.broadcast_stream(&"cursors", {"id": id, "point": data})
				return
	elif topic == &"cursors" and int(sender.get("peer_id", 0)) == 1:
		if not data.get("id") is String or not data.get("point") is Dictionary or not valid_point(data.point):
			return
		var id: String = data.id
		if int(data.point.seq) < int(points.get(id, {}).get("seq", -1)):
			return
		points[id] = data.point.duplicate()
		stamps[id] = Time.get_ticks_msec()

static func valid_point(data: Dictionary) -> bool:
	return data.get("seq") is int and data.seq > 0 and data.get("visible") is bool and (data.get("x") is float or data.get("x") is int) and (data.get("y") is float or data.get("y") is int) and is_finite(float(data.x)) and is_finite(float(data.y)) and float(data.x) >= 0 and float(data.x) <= 1 and float(data.y) >= 0 and float(data.y) <= 1

func _draw() -> void:
	if api == null or not enabled or not bool(api.config.get_common(&"ui.player_cursors", true)):
		return
	for player: Dictionary in api.get_players():
		var id: String = player.player_id
		var point: Dictionary = points.get(id, {})
		if id == local_id or not player.connected or not point.get("visible", false) or Time.get_ticks_msec() - int(stamps.get(id, 0)) > 1500:
			continue
		var position_value: Vector2 = Vector2(point.x, point.y) * size
		var color: Color = Color(api.get_appearance(id).get("color", "#ffffff"))
		var polygon: PackedVector2Array = PackedVector2Array([position_value, position_value + Vector2(5, 24), position_value + Vector2(11, 14), position_value + Vector2(23, 12), position_value])
		draw_colored_polygon(polygon, color)
		draw_polyline(polygon, Color("#101820") if color.get_luminance() > 0.4 else Color.WHITE, 2, true)
		draw_string(get_theme_default_font(), position_value + Vector2(19, 31), player.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
