## Predicted realtime top-down race with host-authoritative movement and scoring.
extends MinigameController

const LOGICAL_SIZE: Vector2 = Vector2(1600.0, 800.0)
const PLAYER_RADIUS: float = 28.0
const TARGET_RADIUS: float = 42.0
const PLAYER_SPEED: float = 420.0
const NETWORK_INTERVAL: float = 1.0 / 20.0
const INTERPOLATION_SECONDS: float = 0.1
const SNAP_DISTANCE: float = 96.0
const TARGET_CLEARANCE: float = PLAYER_RADIUS + TARGET_RADIUS

const KEY_DIRECTION: StringName = &"direction"
const KEY_SERVER_TICK: StringName = &"server_tick"
const KEY_POSITIONS: StringName = &"positions"
const KEY_ACKNOWLEDGED_INPUTS: StringName = &"acknowledged_inputs"
const KEY_TARGET_POSITION: StringName = &"target_position"
const KEY_SCORES: StringName = &"scores"

enum LocalState {
	PREPARING,
	COUNTDOWN,
	PLAYING,
	CLEANUP,
}

@export var phase_label: Label
@export var timer_label: Label
@export var status_label: Label
@export var arena: TargetRaceArena
@export var scoreboard_container: VBoxContainer
@export var countdown_label: Label
@export var leave_button: Button

var _local_state: int = LocalState.PREPARING
var _authoritative_positions: Dictionary[int, Vector2] = {}
var _render_positions: Dictionary[int, Vector2] = {}
var _remote_from_positions: Dictionary[int, Vector2] = {}
var _remote_to_positions: Dictionary[int, Vector2] = {}
var _player_names: Dictionary[int, String] = {}
var _latest_inputs: Dictionary[int, Vector2] = {}
var _last_input_sequences: Dictionary[int, int] = {}
var _host_results_by_peer: Dictionary[int, MinigamePlayerResult] = {}
var _target_position: Vector2 = LOGICAL_SIZE * 0.5
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _local_input_sequence: int = 0
var _state_sequence: int = 0
var _last_applied_state_sequence: int = -1
var _server_tick: int = 0
var _input_accumulator: float = 0.0
var _state_accumulator: float = 0.0
var _interpolation_elapsed: float = 0.0
var _play_started_ticks: int = 0
var _countdown_started_ticks: int = 0
var _countdown_duration_seconds: float = 0.0
var _simulation_stopped: bool = true


func _ready() -> void:
	_assert_required_references()
	leave_button.pressed.connect(leave_session_requested.emit)
	countdown_label.visible = false
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_update_countdown_and_timer()
	if _local_state != LocalState.PLAYING:
		return
	var direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	if not GameSession.local_is_host and not _simulation_stopped:
		var predicted: Vector2 = _render_positions.get(
			GameSession.local_peer_id,
			Vector2.ZERO
		)
		_render_positions[GameSession.local_peer_id] = _clamp_player_position(
			predicted + direction * PLAYER_SPEED * delta
		)
	if GameSession.local_is_host:
		_latest_inputs[GameSession.local_peer_id] = direction
		if not _simulation_stopped:
			_simulate_host(delta)
	else:
		_update_remote_interpolation(delta)
	_input_accumulator += delta
	if _input_accumulator >= NETWORK_INTERVAL:
		_input_accumulator = fmod(_input_accumulator, NETWORK_INTERVAL)
		_local_input_sequence += 1
		var input_payload: Dictionary[StringName, Variant] = {}
		input_payload[KEY_DIRECTION] = direction
		local_realtime_input_requested.emit(_local_input_sequence, input_payload)
	if GameSession.local_is_host and not _simulation_stopped:
		_state_accumulator += delta
		if _state_accumulator >= NETWORK_INTERVAL:
			_state_accumulator = fmod(_state_accumulator, NETWORK_INTERVAL)
			_publish_host_state()
	_refresh_arena()


func prepare_round(
		round_id: int,
		random_seed_value: int,
		players: Array[SessionPlayer],
		definition: MinigameDefinition
) -> Error:
	var base_error: Error = super.prepare_round(
		round_id,
		random_seed_value,
		players,
		definition
	)
	if base_error != OK:
		return base_error
	_local_state = LocalState.PREPARING
	_authoritative_positions.clear()
	_render_positions.clear()
	_remote_from_positions.clear()
	_remote_to_positions.clear()
	_player_names.clear()
	_latest_inputs.clear()
	_last_input_sequences.clear()
	_host_results_by_peer.clear()
	_local_input_sequence = 0
	_state_sequence = 0
	_last_applied_state_sequence = -1
	_server_tick = 0
	_input_accumulator = 0.0
	_state_accumulator = 0.0
	_interpolation_elapsed = 0.0
	_simulation_stopped = true
	var sorted_players: Array[SessionPlayer] = players.duplicate()
	sorted_players.sort_custom(Callable(self, "_is_player_before"))
	var angle_offset: float = float(random_seed_value % 360) * PI / 180.0
	for index: int in range(sorted_players.size()):
		var player: SessionPlayer = sorted_players[index]
		var angle: float = angle_offset + TAU * float(index) / float(sorted_players.size())
		var position: Vector2 = LOGICAL_SIZE * 0.5 + Vector2(
			cos(angle) * 560.0,
			sin(angle) * 270.0
		)
		position = _clamp_player_position(position)
		_authoritative_positions[player.peer_id] = position
		_render_positions[player.peer_id] = position
		_remote_from_positions[player.peer_id] = position
		_remote_to_positions[player.peer_id] = position
		_player_names[player.peer_id] = player.display_name
		_latest_inputs[player.peer_id] = Vector2.ZERO
		_last_input_sequences[player.peer_id] = -1
		_host_results_by_peer[player.peer_id] = MinigamePlayerResult.new(
			player.peer_id,
			player.display_name
		)
	_random.seed = random_seed_value ^ 0x51A7C3
	_spawn_target()
	phase_label.text = "正在加载"
	timer_label.text = "%.1f 秒" % definition.time_limit_seconds
	status_label.text = "WASD 移动，率先碰到目标即可得分。"
	countdown_label.visible = false
	_refresh_scoreboard(_get_host_results())
	_refresh_arena()
	return OK


func begin_countdown(duration_seconds: float) -> void:
	_local_state = LocalState.COUNTDOWN
	_countdown_duration_seconds = duration_seconds
	_countdown_started_ticks = Time.get_ticks_msec()
	phase_label.text = "倒计时"
	countdown_label.text = str(maxi(ceili(duration_seconds), 1))
	countdown_label.visible = true
	_simulation_stopped = true


func begin_play() -> void:
	_local_state = LocalState.PLAYING
	_play_started_ticks = Time.get_ticks_msec()
	phase_label.text = "进行中"
	status_label.text = "WASD 移动，抢到黄色目标得 1 分。"
	countdown_label.visible = false
	_simulation_stopped = false
	if GameSession.local_is_host:
		_publish_host_state()


func apply_authoritative_results(results: Array[MinigamePlayerResult]) -> void:
	super.apply_authoritative_results(results)
	_host_results_by_peer.clear()
	for result: MinigamePlayerResult in results:
		_host_results_by_peer[result.peer_id] = result.duplicate_result()
	_refresh_scoreboard(results)


func cleanup_round() -> void:
	_local_state = LocalState.CLEANUP
	_simulation_stopped = true
	super.cleanup_round()


func handle_authoritative_realtime_input(
		peer_id: int,
		sequence: int,
		payload: Dictionary
) -> Error:
	if not payload.has(KEY_DIRECTION) or typeof(payload[KEY_DIRECTION]) != TYPE_VECTOR2:
		return ERR_INVALID_DATA
	if not _authoritative_positions.has(peer_id):
		return ERR_DOES_NOT_EXIST
	if sequence <= _last_input_sequences.get(peer_id, -1):
		return ERR_ALREADY_EXISTS
	var direction: Vector2 = payload[KEY_DIRECTION] as Vector2
	if direction.length_squared() > 1.0001:
		return ERR_INVALID_DATA
	_last_input_sequences[peer_id] = sequence
	_latest_inputs[peer_id] = direction
	return OK


func apply_authoritative_realtime_state(
		state_sequence: int,
		payload: Dictionary
) -> Error:
	if state_sequence <= _last_applied_state_sequence:
		return OK
	var required_keys: Array[StringName] = [
		KEY_SERVER_TICK,
		KEY_POSITIONS,
		KEY_ACKNOWLEDGED_INPUTS,
		KEY_TARGET_POSITION,
		KEY_SCORES,
	]
	for key: StringName in required_keys:
		if not payload.has(key):
			return ERR_INVALID_DATA
	if (
		typeof(payload[KEY_SERVER_TICK]) != TYPE_INT
		or typeof(payload[KEY_POSITIONS]) != TYPE_DICTIONARY
		or typeof(payload[KEY_ACKNOWLEDGED_INPUTS]) != TYPE_DICTIONARY
		or typeof(payload[KEY_TARGET_POSITION]) != TYPE_VECTOR2
		or typeof(payload[KEY_SCORES]) != TYPE_DICTIONARY
	):
		return ERR_INVALID_DATA
	var positions: Dictionary = payload[KEY_POSITIONS] as Dictionary
	for raw_peer_id: Variant in positions:
		if typeof(raw_peer_id) != TYPE_INT or typeof(positions[raw_peer_id]) != TYPE_VECTOR2:
			return ERR_INVALID_DATA
		var peer_id: int = int(raw_peer_id)
		if not _render_positions.has(peer_id):
			continue
		var authority_position: Vector2 = positions[raw_peer_id] as Vector2
		authority_position = _clamp_player_position(authority_position)
		_authoritative_positions[peer_id] = authority_position
		if peer_id == GameSession.local_peer_id and not GameSession.local_is_host:
			var current: Vector2 = _render_positions[peer_id]
			if current.distance_to(authority_position) > SNAP_DISTANCE:
				_render_positions[peer_id] = authority_position
			else:
				_render_positions[peer_id] = current.lerp(authority_position, 0.25)
		else:
			_remote_from_positions[peer_id] = _render_positions[peer_id]
			_remote_to_positions[peer_id] = authority_position
	_target_position = payload[KEY_TARGET_POSITION] as Vector2
	var scores: Dictionary = payload[KEY_SCORES] as Dictionary
	for raw_peer_id: Variant in scores:
		if typeof(raw_peer_id) != TYPE_INT or typeof(scores[raw_peer_id]) != TYPE_INT:
			return ERR_INVALID_DATA
		var result: MinigamePlayerResult = (
			_host_results_by_peer.get(int(raw_peer_id)) as MinigamePlayerResult
		)
		if result != null:
			result.score = maxi(int(scores[raw_peer_id]), 0)
	_last_applied_state_sequence = state_sequence
	_interpolation_elapsed = 0.0
	_refresh_scoreboard(_get_host_results())
	_refresh_arena()
	return OK


func handle_authoritative_time_expired() -> void:
	_simulation_stopped = true
	authoritative_progress_updated.emit(_get_host_results(), true)


func _simulate_host(delta: float) -> void:
	_server_tick += 1
	for peer_id: int in _authoritative_positions:
		var direction: Vector2 = _latest_inputs.get(peer_id, Vector2.ZERO)
		var position: Vector2 = _authoritative_positions[peer_id]
		position = _clamp_player_position(position + direction * PLAYER_SPEED * delta)
		_authoritative_positions[peer_id] = position
		_render_positions[peer_id] = position
	var winner_id: int = _find_capture_winner()
	if winner_id > 0:
		var result: MinigamePlayerResult = (
			_host_results_by_peer.get(winner_id) as MinigamePlayerResult
		)
		if result != null and not result.is_withdrawn:
			result.score += 1
			_spawn_target()
			authoritative_progress_updated.emit(_get_host_results(), false)
			_publish_host_state()
	if Time.get_ticks_msec() - _play_started_ticks >= _get_time_limit_ms():
		_simulation_stopped = true


func _find_capture_winner() -> int:
	var candidates: Array[int] = []
	for peer_id: int in _authoritative_positions:
		var result: MinigamePlayerResult = (
			_host_results_by_peer.get(peer_id) as MinigamePlayerResult
		)
		if result == null or result.is_withdrawn:
			continue
		if _authoritative_positions[peer_id].distance_to(_target_position) <= TARGET_CLEARANCE:
			candidates.append(peer_id)
	if candidates.is_empty():
		return 0
	candidates.sort_custom(Callable(self, "_is_capture_candidate_before"))
	return candidates[0]


func _is_capture_candidate_before(left_peer_id: int, right_peer_id: int) -> bool:
	var left_distance: float = _authoritative_positions[left_peer_id].distance_squared_to(
		_target_position
	)
	var right_distance: float = _authoritative_positions[right_peer_id].distance_squared_to(
		_target_position
	)
	if not is_equal_approx(left_distance, right_distance):
		return left_distance < right_distance
	return left_peer_id < right_peer_id


func _spawn_target() -> void:
	for _attempt: int in range(64):
		var candidate: Vector2 = Vector2(
			_random.randf_range(TARGET_RADIUS, LOGICAL_SIZE.x - TARGET_RADIUS),
			_random.randf_range(TARGET_RADIUS, LOGICAL_SIZE.y - TARGET_RADIUS)
		)
		if _is_target_clear(candidate):
			_target_position = candidate
			return
	var step: float = TARGET_CLEARANCE * 2.0
	var y: float = TARGET_RADIUS
	while y <= LOGICAL_SIZE.y - TARGET_RADIUS:
		var x: float = TARGET_RADIUS
		while x <= LOGICAL_SIZE.x - TARGET_RADIUS:
			var fallback: Vector2 = Vector2(x, y)
			if _is_target_clear(fallback):
				_target_position = fallback
				return
			x += step
		y += step


func _is_target_clear(candidate: Vector2) -> bool:
	for position: Vector2 in _authoritative_positions.values():
		if position.distance_to(candidate) < TARGET_CLEARANCE:
			return false
	return true


func _publish_host_state() -> void:
	_state_sequence += 1
	var payload: Dictionary[StringName, Variant] = {}
	payload[KEY_SERVER_TICK] = _server_tick
	payload[KEY_POSITIONS] = _authoritative_positions.duplicate()
	payload[KEY_ACKNOWLEDGED_INPUTS] = _last_input_sequences.duplicate()
	payload[KEY_TARGET_POSITION] = _target_position
	var scores: Dictionary[int, int] = {}
	for peer_id: int in _host_results_by_peer:
		var result: MinigamePlayerResult = _host_results_by_peer[peer_id]
		scores[peer_id] = result.score
	payload[KEY_SCORES] = scores
	authoritative_realtime_state_updated.emit(_state_sequence, payload)


func _update_remote_interpolation(delta: float) -> void:
	_interpolation_elapsed += delta
	var weight: float = clampf(_interpolation_elapsed / INTERPOLATION_SECONDS, 0.0, 1.0)
	for peer_id: int in _remote_to_positions:
		if peer_id == GameSession.local_peer_id:
			continue
		var from_position: Vector2 = _remote_from_positions.get(
			peer_id,
			_remote_to_positions[peer_id]
		)
		_render_positions[peer_id] = from_position.lerp(
			_remote_to_positions[peer_id],
			weight
		)


func _update_countdown_and_timer() -> void:
	if _local_state == LocalState.COUNTDOWN:
		var elapsed: float = float(
			Time.get_ticks_msec() - _countdown_started_ticks
		) / 1000.0
		countdown_label.text = str(maxi(ceili(_countdown_duration_seconds - elapsed), 1))
	elif _local_state == LocalState.PLAYING:
		var remaining_ms: int = maxi(
			_get_time_limit_ms() - (Time.get_ticks_msec() - _play_started_ticks),
			0
		)
		timer_label.text = "%.1f 秒" % (float(remaining_ms) / 1000.0)


func _refresh_scoreboard(results: Array[MinigamePlayerResult]) -> void:
	for child: Node in scoreboard_container.get_children():
		scoreboard_container.remove_child(child)
		child.queue_free()
	var sorted_results: Array[MinigamePlayerResult] = _duplicate_results(results)
	sorted_results.sort_custom(Callable(self, "_is_score_before"))
	for result: MinigamePlayerResult in sorted_results:
		var label: Label = Label.new()
		label.text = "%s：%d%s" % [
			result.display_name,
			result.score,
			"（已退出）" if result.is_withdrawn else "",
		]
		label.add_theme_font_size_override("font_size", 22)
		scoreboard_container.add_child(label)


func _is_score_before(left: MinigamePlayerResult, right: MinigamePlayerResult) -> bool:
	if left.is_withdrawn != right.is_withdrawn:
		return not left.is_withdrawn
	if left.score != right.score:
		return left.score > right.score
	return left.peer_id < right.peer_id


func _get_host_results() -> Array[MinigamePlayerResult]:
	var results: Array[MinigamePlayerResult] = []
	for value: Variant in _host_results_by_peer.values():
		var result: MinigamePlayerResult = value as MinigamePlayerResult
		if result != null:
			results.append(result.duplicate_result())
	results.sort_custom(Callable(self, "_is_score_before"))
	return results


func _refresh_arena() -> void:
	arena.set_display_state(
		_render_positions,
		_player_names,
		_target_position,
		GameSession.local_peer_id
	)


func _clamp_player_position(position: Vector2) -> Vector2:
	return Vector2(
		clampf(position.x, PLAYER_RADIUS, LOGICAL_SIZE.x - PLAYER_RADIUS),
		clampf(position.y, PLAYER_RADIUS, LOGICAL_SIZE.y - PLAYER_RADIUS)
	)


func _get_time_limit_ms() -> int:
	return int(active_definition.time_limit_seconds * 1000.0) if active_definition != null else 0


func _is_player_before(left: SessionPlayer, right: SessionPlayer) -> bool:
	return left.peer_id < right.peer_id


func _assert_required_references() -> void:
	assert(phase_label != null, "TargetRace requires phase_label.")
	assert(timer_label != null, "TargetRace requires timer_label.")
	assert(status_label != null, "TargetRace requires status_label.")
	assert(arena != null, "TargetRace requires arena.")
	assert(scoreboard_container != null, "TargetRace requires scoreboard_container.")
	assert(countdown_label != null, "TargetRace requires countdown_label.")
	assert(leave_button != null, "TargetRace requires leave_button.")
