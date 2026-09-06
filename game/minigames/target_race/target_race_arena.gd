## Draws the logical target-race arena without external art assets.
class_name TargetRaceArena
extends Control

const LOGICAL_SIZE: Vector2 = Vector2(1600.0, 800.0)
const PLAYER_RADIUS: float = 28.0
const TARGET_RADIUS: float = 42.0

var player_positions: Dictionary[int, Vector2] = {}
var player_names: Dictionary[int, String] = {}
var target_position: Vector2 = LOGICAL_SIZE * 0.5
var local_peer_id: int = 0


func set_display_state(
		positions: Dictionary[int, Vector2],
		names: Dictionary[int, String],
		next_target_position: Vector2,
		next_local_peer_id: int
) -> void:
	player_positions = positions.duplicate()
	player_names = names.duplicate()
	target_position = next_target_position
	local_peer_id = next_local_peer_id
	queue_redraw()


func logical_to_local(logical_position: Vector2) -> Vector2:
	var scale_factor: float = minf(size.x / LOGICAL_SIZE.x, size.y / LOGICAL_SIZE.y)
	var drawn_size: Vector2 = LOGICAL_SIZE * scale_factor
	var origin: Vector2 = (size - drawn_size) * 0.5
	return origin + logical_position * scale_factor


func _draw() -> void:
	var scale_factor: float = minf(size.x / LOGICAL_SIZE.x, size.y / LOGICAL_SIZE.y)
	if scale_factor <= 0.0:
		return
	var drawn_size: Vector2 = LOGICAL_SIZE * scale_factor
	var origin: Vector2 = (size - drawn_size) * 0.5
	draw_rect(Rect2(origin, drawn_size), Color(0.035, 0.075, 0.12, 1.0), true)
	draw_rect(Rect2(origin, drawn_size), Color(0.25, 0.55, 0.78, 1.0), false, 4.0)
	var target_local: Vector2 = logical_to_local(target_position)
	draw_circle(target_local, TARGET_RADIUS * scale_factor, Color(1.0, 0.72, 0.12, 1.0))
	draw_circle(target_local, TARGET_RADIUS * 0.55 * scale_factor, Color(1.0, 0.93, 0.48, 1.0))
	for peer_id: int in player_positions:
		var player_local: Vector2 = logical_to_local(player_positions[peer_id])
		var color: Color = _color_for_peer(peer_id)
		draw_circle(player_local, PLAYER_RADIUS * scale_factor, color)
		var outline: Color = Color.WHITE if peer_id == local_peer_id else Color(0.05, 0.08, 0.12, 1.0)
		draw_arc(
			player_local,
			PLAYER_RADIUS * scale_factor,
			0.0,
			TAU,
			32,
			outline,
			5.0 if peer_id == local_peer_id else 3.0
		)


func _color_for_peer(peer_id: int) -> Color:
	var hue: float = fmod(float(peer_id * 47), 360.0) / 360.0
	return Color.from_hsv(hue, 0.68, 0.95)
