## Client-responsive target-click minigame with host-authoritative progress and ranking.
extends MinigameController

const TARGET_COUNT: int = 10
const CONFIG_PATH: String = "user://minigames/target_click.cfg"
const CONFIG_SECTION_INPUT: String = "input"
const CONFIG_KEY_MOUSE_BUTTON: String = "mouse_button"
const SAFE_POSITION_MIN: float = 0.08
const SAFE_POSITION_MAX: float = 0.92

enum LocalState {
	PREPARING,
	COUNTDOWN,
	PLAYING,
	RESULTS,
	CLEANUP,
}

@export var phase_label: Label
@export var timer_label: Label
@export var status_label: Label
@export var target_area: Control
@export var target_button: Button
@export var scoreboard_container: VBoxContainer
@export var countdown_label: Label
@export var results_panel: PanelContainer
@export var results_container: VBoxContainer
@export var replay_button: Button
@export var return_button: Button
@export var leave_button: Button

var _local_state: int = LocalState.PREPARING
var _target_positions: Array[Vector2] = []
var _host_results_by_peer: Dictionary[int, MinigamePlayerResult] = {}
var _local_target_index: int = 0
var _play_started_ticks: int = 0
var _countdown_started_ticks: int = 0
var _countdown_duration_seconds: float = 0.0
var _configured_mouse_button: int = MOUSE_BUTTON_LEFT


func _ready() -> void:
	_assert_required_references()
	target_button.gui_input.connect(_on_target_gui_input)
	target_area.resized.connect(_place_current_target)
	replay_button.pressed.connect(replay_requested.emit)
	return_button.pressed.connect(return_to_lobby_requested.emit)
	leave_button.pressed.connect(leave_session_requested.emit)
	target_button.visible = false
	countdown_label.visible = false
	results_panel.visible = false
	set_process(true)


func _process(_delta: float) -> void:
	if _local_state == LocalState.COUNTDOWN:
		var elapsed_seconds: float = (
			float(Time.get_ticks_msec() - _countdown_started_ticks) / 1000.0
		)
		var remaining_seconds: float = maxf(
			_countdown_duration_seconds - elapsed_seconds,
			0.0
		)
		countdown_label.text = str(maxi(ceili(remaining_seconds), 1))
	elif _local_state == LocalState.PLAYING:
		var elapsed_ms: int = Time.get_ticks_msec() - _play_started_ticks
		var time_limit_ms: int = _get_time_limit_ms()
		var remaining_ms: int = maxi(time_limit_ms - elapsed_ms, 0)
		timer_label.text = "%.1f 秒" % (float(remaining_ms) / 1000.0)
		if remaining_ms == 0:
			target_button.visible = false


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
	var config_error: Error = _load_or_create_config()
	if config_error != OK:
		return config_error

	_local_state = LocalState.PREPARING
	_local_target_index = 0
	_play_started_ticks = 0
	_countdown_started_ticks = 0
	_target_positions.clear()
	_host_results_by_peer.clear()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = random_seed_value
	var index: int = 0
	while index < TARGET_COUNT:
		_target_positions.append(
			Vector2(
				random.randf_range(SAFE_POSITION_MIN, SAFE_POSITION_MAX),
				random.randf_range(SAFE_POSITION_MIN, SAFE_POSITION_MAX)
			)
		)
		index += 1
	for player: SessionPlayer in players:
		_host_results_by_peer[player.peer_id] = MinigamePlayerResult.new(
			player.peer_id,
			player.display_name
		)

	phase_label.text = "正在加载"
	timer_label.text = "%.1f 秒" % active_definition.time_limit_seconds
	status_label.text = "所有玩家加载完成后开始倒计时。"
	target_button.visible = false
	countdown_label.visible = false
	results_panel.visible = false
	replay_button.visible = GameSession.local_is_host
	return_button.visible = GameSession.local_is_host
	_refresh_scoreboard(_get_host_results())
	return OK


func begin_countdown(duration_seconds: float) -> void:
	_local_state = LocalState.COUNTDOWN
	_countdown_duration_seconds = duration_seconds
	_countdown_started_ticks = Time.get_ticks_msec()
	phase_label.text = "倒计时"
	status_label.text = "准备点击目标！"
	countdown_label.text = str(maxi(ceili(duration_seconds), 1))
	countdown_label.visible = true
	target_button.visible = false


func begin_play() -> void:
	_local_state = LocalState.PLAYING
	_local_target_index = 0
	_play_started_ticks = Time.get_ticks_msec()
	phase_label.text = "进行中"
	status_label.text = "依次点击出现的 10 个目标。"
	countdown_label.visible = false
	results_panel.visible = false
	target_button.visible = true
	_place_current_target()


func apply_authoritative_results(results: Array[MinigamePlayerResult]) -> void:
	super.apply_authoritative_results(results)
	_host_results_by_peer.clear()
	for result: MinigamePlayerResult in results:
		_host_results_by_peer[result.peer_id] = result.duplicate_result()
	_refresh_scoreboard(results)


func show_final_results(results: Array[MinigamePlayerResult]) -> void:
	super.show_final_results(results)
	_local_state = LocalState.RESULTS
	phase_label.text = "本局结束"
	timer_label.text = "0.0 秒"
	status_label.text = "房主可以再来一局或返回大厅。"
	target_button.visible = false
	countdown_label.visible = false
	results_panel.visible = true
	replay_button.visible = GameSession.local_is_host
	return_button.visible = GameSession.local_is_host
	_build_final_results(results)


func cleanup_round() -> void:
	_local_state = LocalState.CLEANUP
	target_button.visible = false
	super.cleanup_round()


func handle_authoritative_action(
		peer_id: int,
		action_id: StringName,
		payload: Dictionary
) -> Error:
	if action_id != LobbyProtocol.TARGET_HIT_ACTION:
		return ERR_UNAVAILABLE
	if (
		not payload.has(LobbyProtocol.KEY_HIT_INDEX)
		or not payload.has(LobbyProtocol.KEY_ELAPSED_MS)
	):
		return ERR_INVALID_DATA
	var raw_hit_index: Variant = payload[LobbyProtocol.KEY_HIT_INDEX]
	var raw_elapsed_ms: Variant = payload[LobbyProtocol.KEY_ELAPSED_MS]
	if typeof(raw_hit_index) != TYPE_INT or typeof(raw_elapsed_ms) != TYPE_INT:
		return ERR_INVALID_DATA

	var result: MinigamePlayerResult = (
		_host_results_by_peer.get(peer_id) as MinigamePlayerResult
	)
	if result == null or result.is_withdrawn or result.is_complete:
		return ERR_INVALID_DATA
	var hit_index: int = int(raw_hit_index)
	var elapsed_ms: int = int(raw_elapsed_ms)
	if hit_index != result.hit_count or hit_index < 0 or hit_index >= TARGET_COUNT:
		return ERR_INVALID_DATA
	if elapsed_ms < result.elapsed_ms or elapsed_ms < 0 or elapsed_ms > _get_time_limit_ms():
		return ERR_INVALID_DATA

	result.hit_count = hit_index + 1
	result.elapsed_ms = elapsed_ms
	result.is_complete = result.hit_count == TARGET_COUNT
	var results: Array[MinigamePlayerResult] = _get_host_results()
	var all_complete: bool = true
	for current_result: MinigamePlayerResult in results:
		if not current_result.is_withdrawn and not current_result.is_complete:
			all_complete = false
			break
	authoritative_progress_updated.emit(results, all_complete)
	return OK


func handle_authoritative_time_expired() -> void:
	authoritative_progress_updated.emit(_get_host_results(), true)


func _on_target_gui_input(event: InputEvent) -> void:
	if _local_state != LocalState.PLAYING:
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != _configured_mouse_button:
		return
	var elapsed_ms: int = Time.get_ticks_msec() - _play_started_ticks
	if elapsed_ms < 0 or elapsed_ms > _get_time_limit_ms():
		target_button.visible = false
		return

	var hit_index: int = _local_target_index
	_local_target_index += 1
	var payload: Dictionary[StringName, Variant] = {}
	payload[LobbyProtocol.KEY_HIT_INDEX] = hit_index
	payload[LobbyProtocol.KEY_ELAPSED_MS] = elapsed_ms
	local_action_requested.emit(LobbyProtocol.TARGET_HIT_ACTION, payload)
	target_button.accept_event()
	if _local_target_index >= TARGET_COUNT:
		target_button.visible = false
		status_label.text = "已完成，等待其他玩家。"
	else:
		_place_current_target()


func _place_current_target() -> void:
	if _local_target_index < 0 or _local_target_index >= _target_positions.size():
		return
	if target_area.size.x <= 0.0 or target_area.size.y <= 0.0:
		call_deferred("_place_current_target")
		return
	var normalized_position: Vector2 = _target_positions[_local_target_index]
	var available_size: Vector2 = Vector2(
		maxf(target_area.size.x - target_button.size.x, 0.0),
		maxf(target_area.size.y - target_button.size.y, 0.0)
	)
	target_button.position = Vector2(
		available_size.x * normalized_position.x,
		available_size.y * normalized_position.y
	)
	target_button.text = str(_local_target_index + 1)


func _refresh_scoreboard(results: Array[MinigamePlayerResult]) -> void:
	_clear_container(scoreboard_container)
	var sorted_results: Array[MinigamePlayerResult] = _duplicate_results(results)
	sorted_results.sort_custom(Callable(MinigamePlayerResult, "is_before"))
	for result: MinigamePlayerResult in sorted_results:
		var label: Label = Label.new()
		var suffix: String = ""
		if result.is_withdrawn:
			suffix = "（已退出）"
		elif result.is_complete:
			suffix = "（%.3f 秒）" % (float(result.elapsed_ms) / 1000.0)
		label.text = "%s：%d/%d %s" % [
			result.display_name,
			result.hit_count,
			TARGET_COUNT,
			suffix,
		]
		label.add_theme_font_size_override("font_size", 22)
		scoreboard_container.add_child(label)


func _build_final_results(results: Array[MinigamePlayerResult]) -> void:
	_clear_container(results_container)
	for result: MinigamePlayerResult in results:
		var label: Label = Label.new()
		if result.is_withdrawn:
			label.text = "%d. %s — 已退出" % [result.rank, result.display_name]
		elif result.is_complete:
			label.text = "%d. %s — %.3f 秒" % [
				result.rank,
				result.display_name,
				float(result.elapsed_ms) / 1000.0,
			]
		else:
			label.text = "%d. %s — %d/%d" % [
				result.rank,
				result.display_name,
				result.hit_count,
				TARGET_COUNT,
			]
		label.add_theme_font_size_override("font_size", 24)
		results_container.add_child(label)


func _get_host_results() -> Array[MinigamePlayerResult]:
	var results: Array[MinigamePlayerResult] = []
	var values: Array = _host_results_by_peer.values()
	for value: Variant in values:
		var result: MinigamePlayerResult = value as MinigamePlayerResult
		if result != null:
			results.append(result.duplicate_result())
	results.sort_custom(Callable(MinigamePlayerResult, "is_before"))
	return results


func _get_time_limit_ms() -> int:
	if active_definition == null:
		return 0
	return int(active_definition.time_limit_seconds * 1000.0)


func _load_or_create_config() -> Error:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(CONFIG_PATH)
	if load_error == ERR_FILE_NOT_FOUND:
		var absolute_directory: String = ProjectSettings.globalize_path(
			"user://minigames"
		)
		var directory_error: Error = DirAccess.make_dir_recursive_absolute(
			absolute_directory
		)
		if directory_error != OK:
			return directory_error
		config.set_value(
			CONFIG_SECTION_INPUT,
			CONFIG_KEY_MOUSE_BUTTON,
			MOUSE_BUTTON_LEFT
		)
		var save_error: Error = config.save(CONFIG_PATH)
		if save_error != OK:
			return save_error
	elif load_error != OK:
		return load_error

	var raw_button: Variant = config.get_value(
		CONFIG_SECTION_INPUT,
		CONFIG_KEY_MOUSE_BUTTON,
		MOUSE_BUTTON_LEFT
	)
	if typeof(raw_button) != TYPE_INT:
		return ERR_INVALID_DATA
	var parsed_button: int = int(raw_button)
	if parsed_button < MOUSE_BUTTON_LEFT or parsed_button > MOUSE_BUTTON_XBUTTON2:
		return ERR_INVALID_DATA
	_configured_mouse_button = parsed_button
	return OK


func _clear_container(container: VBoxContainer) -> void:
	var children: Array[Node] = []
	for child: Node in container.get_children():
		children.append(child)
	for child: Node in children:
		container.remove_child(child)
		child.queue_free()


func _assert_required_references() -> void:
	assert(phase_label != null, "TargetClick requires phase_label.")
	assert(timer_label != null, "TargetClick requires timer_label.")
	assert(status_label != null, "TargetClick requires status_label.")
	assert(target_area != null, "TargetClick requires target_area.")
	assert(target_button != null, "TargetClick requires target_button.")
	assert(scoreboard_container != null, "TargetClick requires scoreboard_container.")
	assert(countdown_label != null, "TargetClick requires countdown_label.")
	assert(results_panel != null, "TargetClick requires results_panel.")
	assert(results_container != null, "TargetClick requires results_container.")
	assert(replay_button != null, "TargetClick requires replay_button.")
	assert(return_button != null, "TargetClick requires return_button.")
	assert(leave_button != null, "TargetClick requires leave_button.")
