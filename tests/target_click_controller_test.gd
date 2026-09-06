## Focused rule checks for target-click action validation and completion.
extends SceneTree

var _failures: Array[String] = []
var _latest_results: Array[MinigamePlayerResult] = []
var _finish_requested: bool = false
var _local_action_count: int = 0
var _leave_signal_count: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene: PackedScene = load(
		"res://game/minigames/target_click/target_click.tscn"
	) as PackedScene
	var definition: MinigameDefinition = load(
		"res://game/minigames/target_click/target_click_definition.tres"
	) as MinigameDefinition
	_expect(packed_scene != null, "Target-click scene should load.")
	_expect(definition != null, "Target-click definition should load.")
	if packed_scene == null or definition == null:
		_finish()
		return

	var controller: MinigameController = packed_scene.instantiate() as MinigameController
	_expect(controller != null, "Target-click root should implement MinigameController.")
	if controller == null:
		_finish()
		return
	root.add_child(controller)
	await process_frame
	controller.authoritative_progress_updated.connect(_on_progress_updated)
	controller.local_action_requested.connect(_on_local_action_requested)
	controller.leave_session_requested.connect(_on_leave_session_requested)

	var players: Array[SessionPlayer] = [
		SessionPlayer.new(1, "Host", true, true),
		SessionPlayer.new(2, "Client", false, true),
	]
	_expect(
		controller.prepare_round(1, 12345, players, definition) == OK,
		"A valid round should prepare."
	)
	controller.begin_play()
	await process_frame

	var target_button: Button = controller.get_node(
		"Margin/Layout/Body/Arena/TargetArea/TargetButton"
	) as Button
	await _click_control(target_button)
	_expect(
		_local_action_count == 1,
		"A real viewport click should reach the gameplay target."
	)
	var leave_button: Button = controller.get_node(
		"Margin/Layout/Header/LeaveButton"
	) as Button
	await _click_control(leave_button)
	_expect(
		_leave_signal_count == 1,
		"A real viewport click should reach the leave-session button."
	)

	_expect(
		_submit_hit(controller, 2, 0, 100) == OK,
		"The first sequential hit should be accepted."
	)
	_expect(
		_submit_hit(controller, 2, 0, 110) != OK,
		"A duplicate hit index should be rejected."
	)
	_expect(
		_submit_hit(controller, 2, 2, 120) != OK,
		"A skipped hit index should be rejected."
	)
	_expect(
		_submit_hit(controller, 2, 1, -1) != OK,
		"A negative elapsed time should be rejected."
	)
	_expect(
		_submit_hit(controller, 2, 1, 99) != OK,
		"Elapsed time must not move backwards."
	)
	_expect(
		_submit_hit(controller, 2, 1, 20001) != OK,
		"A hit after the time limit should be rejected."
	)

	var hit_index: int = 1
	while hit_index < 10:
		var elapsed_ms: int = 100 + hit_index * 100
		_expect(
			_submit_hit(controller, 2, hit_index, elapsed_ms) == OK,
			"Sequential hit %d should be accepted." % hit_index
		)
		hit_index += 1

	var client_result: MinigamePlayerResult = _find_result(2)
	_expect(client_result != null, "Client progress should be published.")
	if client_result != null:
		_expect(client_result.score == 10, "Ten accepted hits should be recorded.")
		_expect(client_result.is_complete, "The tenth hit should complete the player.")
		_expect(client_result.elapsed_ms == 1000, "Completion time should use the final valid hit.")
	_expect(
		not _finish_requested,
		"One completed player should not finish while another active player remains."
	)

	controller.cleanup_round()
	controller.queue_free()
	await process_frame
	_finish()


func _submit_hit(
		controller: MinigameController,
		peer_id: int,
		hit_index: int,
		elapsed_ms: int
) -> Error:
	var payload: Dictionary[StringName, Variant] = {}
	payload[LobbyProtocol.KEY_HIT_INDEX] = hit_index
	payload[LobbyProtocol.KEY_ELAPSED_MS] = elapsed_ms
	return controller.handle_authoritative_action(
		peer_id,
		LobbyProtocol.TARGET_HIT_ACTION,
		payload
	)


func _on_progress_updated(
		results: Array[MinigamePlayerResult],
		finish_requested: bool
) -> void:
	_latest_results.clear()
	for result: MinigamePlayerResult in results:
		_latest_results.append(result.duplicate_result())
	_finish_requested = finish_requested


func _on_local_action_requested(
		_action_id: StringName,
		_payload: Dictionary
) -> void:
	_local_action_count += 1


func _on_leave_session_requested() -> void:
	_leave_signal_count += 1


func _click_control(control: Control) -> void:
	var click_position: Vector2 = control.get_global_rect().get_center()
	var press_event: InputEventMouseButton = InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.position = click_position
	press_event.global_position = click_position
	press_event.pressed = true
	root.push_input(press_event, true)
	await process_frame
	var release_event: InputEventMouseButton = InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.position = click_position
	release_event.global_position = click_position
	release_event.pressed = false
	root.push_input(release_event, true)
	await process_frame


func _find_result(peer_id: int) -> MinigamePlayerResult:
	for result: MinigamePlayerResult in _latest_results:
		if result.peer_id == peer_id:
			return result
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TARGET_CLICK_CONTROLLER_TEST: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("TARGET_CLICK_CONTROLLER_TEST: %s" % failure)
	quit(1)
