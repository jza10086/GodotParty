## Verifies that every peer retained the same session state across the scene transition.
extends Control

@export var session_label: Label
@export var players_container: VBoxContainer
@export var leave_button: Button


func _ready() -> void:
	assert(session_label != null, "PlaceholderGame requires session_label.")
	assert(players_container != null, "PlaceholderGame requires players_container.")
	assert(leave_button != null, "PlaceholderGame requires leave_button.")
	GameSession.players_changed.connect(_on_players_changed)
	leave_button.pressed.connect(_on_leave_pressed)
	_refresh(GameSession.get_sorted_players())


func _on_players_changed(players: Array[SessionPlayer]) -> void:
	_refresh(players)


func _on_leave_pressed() -> void:
	NetworkManager.leave_session()


func _refresh(players: Array[SessionPlayer]) -> void:
	var local_player: SessionPlayer = GameSession.get_local_player()
	var local_description: String = "未知玩家"
	if local_player != null:
		local_description = "%s / Peer %d / %s" % [
			local_player.display_name,
			local_player.peer_id,
			"房主" if local_player.is_host else "客户端",
		]
	session_label.text = "游戏 ID：%s\n随机种子：%d\n本机：%s" % [
		GameSession.current_game_id,
		GameSession.random_seed,
		local_description,
	]
	_clear_player_rows()
	var index: int = 0
	while index < players.size():
		var player: SessionPlayer = players[index]
		var label: Label = Label.new()
		label.text = "%d. %s  [Peer %d]%s" % [
			index + 1,
			player.display_name,
			player.peer_id,
			"（房主）" if player.is_host else "",
		]
		players_container.add_child(label)
		index += 1


func _clear_player_rows() -> void:
	var rows: Array[Node] = []
	for child: Node in players_container.get_children():
		rows.append(child)
	for child: Node in rows:
		players_container.remove_child(child)
		child.queue_free()
