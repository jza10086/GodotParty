## Presents the authoritative lobby snapshot and exposes role-appropriate actions.
extends Control

@export var role_label: Label
@export var players_container: VBoxContainer
@export var ready_button: Button
@export var start_button: Button
@export var leave_button: Button
@export var status_label: Label


func _ready() -> void:
	_assert_required_references()
	GameSession.players_changed.connect(_on_players_changed)
	GameSession.phase_changed.connect(_on_phase_changed)
	ready_button.pressed.connect(_on_ready_pressed)
	start_button.pressed.connect(_on_start_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	ready_button.visible = not GameSession.local_is_host
	start_button.visible = GameSession.local_is_host
	role_label.text = "身份：房主" if GameSession.local_is_host else "身份：客户端"
	_refresh(GameSession.get_sorted_players())


func _on_players_changed(players: Array[SessionPlayer]) -> void:
	_refresh(players)


func _on_phase_changed(_phase: int) -> void:
	_refresh(GameSession.get_sorted_players())


func _on_ready_pressed() -> void:
	var local_player: SessionPlayer = GameSession.get_local_player()
	if local_player == null:
		return
	NetworkManager.set_local_ready(not local_player.is_ready)


func _on_start_pressed() -> void:
	NetworkManager.request_start_game()


func _on_leave_pressed() -> void:
	NetworkManager.leave_session()


func _refresh(players: Array[SessionPlayer]) -> void:
	_clear_player_rows()
	var index: int = 0
	while index < players.size():
		players_container.add_child(_create_player_row(players[index]))
		index += 1

	var local_player: SessionPlayer = GameSession.get_local_player()
	if local_player != null and not local_player.is_host:
		ready_button.text = "取消准备" if local_player.is_ready else "准备"
		ready_button.disabled = GameSession.phase != GameSessionState.Phase.LOBBY

	start_button.disabled = not GameSession.can_host_start()
	if GameSession.phase == GameSessionState.Phase.STARTING_GAME:
		status_label.text = "正在启动游戏……"
	elif players.size() < 2:
		status_label.text = "至少需要 2 名玩家才能开始。"
	elif GameSession.can_host_start():
		status_label.text = "所有玩家已准备，可以开始。"
	elif GameSession.local_is_host:
		status_label.text = "等待其他玩家准备。"
	else:
		status_label.text = "准备后等待房主开始。"


func _create_player_row(player: SessionPlayer) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var name_label: Label = Label.new()
	name_label.text = "%s  [Peer %d]%s" % [
		player.display_name,
		player.peer_id,
		"（房主）" if player.is_host else "",
	]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ready_label: Label = Label.new()
	ready_label.text = "已准备" if player.is_ready else "未准备"
	row.add_child(name_label)
	row.add_child(ready_label)
	return row


func _clear_player_rows() -> void:
	var rows: Array[Node] = []
	for child: Node in players_container.get_children():
		rows.append(child)
	for child: Node in rows:
		players_container.remove_child(child)
		child.queue_free()


func _assert_required_references() -> void:
	assert(role_label != null, "Lobby requires role_label.")
	assert(players_container != null, "Lobby requires players_container.")
	assert(ready_button != null, "Lobby requires ready_button.")
	assert(start_button != null, "Lobby requires start_button.")
	assert(leave_button != null, "Lobby requires leave_button.")
	assert(status_label != null, "Lobby requires status_label.")
