## Keeps the persistent application root and coordinates screens with the minigame lifecycle.
extends Node

@export var screen_root: Node
@export var start_menu_scene: PackedScene
@export var lobby_scene: PackedScene
@export var minigame_definitions: Array[MinigameDefinition] = []

var _active_controller: MinigameController = null


func _ready() -> void:
	_assert_required_references()
	var registration_error: Error = NetworkManager.register_minigames(
		minigame_definitions
	)
	assert(
		registration_error == OK,
		"Main requires unique and valid exported minigame definitions."
	)
	NetworkManager.lobby_joined.connect(_on_lobby_joined)
	NetworkManager.session_left.connect(_on_session_left)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.round_loading_started.connect(_on_round_loading_started)
	NetworkManager.round_countdown_started.connect(_on_round_countdown_started)
	NetworkManager.round_play_started.connect(_on_round_play_started)
	NetworkManager.round_progress_changed.connect(_on_round_progress_changed)
	NetworkManager.round_results_ready.connect(_on_round_results_ready)
	NetworkManager.lobby_returned.connect(_on_lobby_returned)
	NetworkManager.minigame_action_received.connect(_on_minigame_action_received)
	NetworkManager.round_time_expired.connect(_on_round_time_expired)
	_show_start_menu()


func _on_lobby_joined() -> void:
	call_deferred("_show_lobby")


func _on_session_left(_reason: String) -> void:
	call_deferred("_show_start_menu")


func _on_connection_failed(_reason: String) -> void:
	call_deferred("_show_start_menu")


func _on_lobby_returned() -> void:
	call_deferred("_show_lobby")


func _on_round_loading_started(
		round_id: int,
		game_id: StringName,
		random_seed_value: int
) -> void:
	var definition: MinigameDefinition = NetworkManager.get_minigame_definition(
		game_id
	)
	if definition == null:
		NetworkManager.report_local_game_loaded(
			round_id,
			game_id,
			false,
			"本机没有游戏定义"
		)
		return

	var instance: Node = definition.scene.instantiate()
	if not instance is MinigameController:
		instance.queue_free()
		NetworkManager.report_local_game_loaded(
			round_id,
			game_id,
			false,
			"小游戏根节点没有继承 MinigameController"
		)
		return

	_replace_screen_instance(instance)
	_active_controller = instance as MinigameController
	_connect_active_controller()
	var prepare_error: Error = _active_controller.prepare_round(
		round_id,
		random_seed_value,
		GameSession.get_sorted_players(),
		definition
	)
	if prepare_error != OK:
		NetworkManager.report_local_game_loaded(
			round_id,
			game_id,
			false,
			error_string(prepare_error)
		)
		return

	await get_tree().process_frame
	if GameSession.phase != GameSessionState.Phase.LOADING_GAME:
		return
	if GameSession.round_id != round_id:
		return
	NetworkManager.report_local_game_loaded(round_id, game_id, true, "")


func _on_round_countdown_started(round_id: int, duration_seconds: float) -> void:
	if not _is_active_round(round_id):
		return
	_active_controller.begin_countdown(duration_seconds)


func _on_round_play_started(round_id: int) -> void:
	if not _is_active_round(round_id):
		return
	_active_controller.begin_play()


func _on_round_progress_changed(
		round_id: int,
		results: Array[MinigamePlayerResult]
) -> void:
	if not _is_active_round(round_id):
		return
	_active_controller.apply_authoritative_results(results)


func _on_round_results_ready(
		round_id: int,
		results: Array[MinigamePlayerResult]
) -> void:
	if not _is_active_round(round_id):
		return
	_active_controller.show_final_results(results)


func _on_minigame_action_received(
		peer_id: int,
		round_id: int,
		action_id: StringName,
		payload: Dictionary
) -> void:
	if not GameSession.local_is_host or not _is_active_round(round_id):
		return
	var action_error: Error = _active_controller.handle_authoritative_action(
		peer_id,
		action_id,
		payload
	)
	if action_error != OK:
		push_warning(
			"Ignored invalid '%s' action from peer %d: %s"
			% [String(action_id), peer_id, error_string(action_error)]
		)


func _on_round_time_expired(round_id: int) -> void:
	if not GameSession.local_is_host or not _is_active_round(round_id):
		return
	_active_controller.handle_authoritative_time_expired()


func _on_local_action_requested(action_id: StringName, payload: Dictionary) -> void:
	if _active_controller == null:
		return
	NetworkManager.submit_minigame_action(
		_active_controller.active_round_id,
		action_id,
		payload
	)


func _on_authoritative_progress_updated(
		results: Array[MinigamePlayerResult],
	finish_requested: bool
) -> void:
	if _active_controller == null:
		return
	NetworkManager.publish_minigame_progress(
		_active_controller.active_round_id,
		results,
		finish_requested
	)


func _on_replay_requested() -> void:
	NetworkManager.request_replay_round()


func _on_return_to_lobby_requested() -> void:
	NetworkManager.request_return_to_lobby()


func _on_leave_session_requested() -> void:
	NetworkManager.leave_session()


func _show_start_menu() -> void:
	_replace_screen(start_menu_scene)


func _show_lobby() -> void:
	_replace_screen(lobby_scene)


func _replace_screen(scene: PackedScene) -> void:
	assert(scene != null)
	_replace_screen_instance(scene.instantiate())


func _replace_screen_instance(instance: Node) -> void:
	if _active_controller != null:
		_active_controller.cleanup_round()
		_active_controller = null
	var existing_children: Array[Node] = []
	for child: Node in screen_root.get_children():
		existing_children.append(child)
	for child: Node in existing_children:
		screen_root.remove_child(child)
		child.queue_free()
	screen_root.add_child(instance)


func _connect_active_controller() -> void:
	assert(_active_controller != null)
	_active_controller.local_action_requested.connect(_on_local_action_requested)
	_active_controller.authoritative_progress_updated.connect(
		_on_authoritative_progress_updated
	)
	_active_controller.replay_requested.connect(_on_replay_requested)
	_active_controller.return_to_lobby_requested.connect(
		_on_return_to_lobby_requested
	)
	_active_controller.leave_session_requested.connect(_on_leave_session_requested)


func _is_active_round(round_id: int) -> bool:
	return (
		_active_controller != null
		and _active_controller.active_round_id == round_id
	)


func _assert_required_references() -> void:
	assert(screen_root != null, "Main requires an exported screen_root.")
	assert(start_menu_scene != null, "Main requires an exported start_menu_scene.")
	assert(lobby_scene != null, "Main requires an exported lobby_scene.")
	assert(not minigame_definitions.is_empty(), "Main requires a minigame definition.")
