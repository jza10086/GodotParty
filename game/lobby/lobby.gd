## Presents the authoritative lobby snapshot and host-owned playlist configuration.
extends Control

@export var role_label: Label
@export var players_container: VBoxContainer
@export var ready_button: Button
@export var start_button: Button
@export var leave_button: Button
@export var status_label: Label
@export var rounds_spin_box: SpinBox
@export var intermission_spin_box: SpinBox
@export var order_option: OptionButton
@export var repeat_option: OptionButton
@export var games_container: VBoxContainer
@export var rules_label: Label

var _game_checkboxes: Dictionary[StringName, CheckBox] = {}
var _updating_config: bool = false


func _ready() -> void:
	_assert_required_references()
	GameSession.players_changed.connect(_on_players_changed)
	GameSession.phase_changed.connect(_on_phase_changed)
	GameSession.playlist_changed.connect(_on_playlist_changed)
	ready_button.pressed.connect(_on_ready_pressed)
	start_button.pressed.connect(NetworkManager.request_start_playlist)
	leave_button.pressed.connect(NetworkManager.leave_session)
	rounds_spin_box.value_changed.connect(_on_rounds_changed)
	intermission_spin_box.value_changed.connect(_on_intermission_changed)
	order_option.item_selected.connect(_on_order_selected)
	repeat_option.item_selected.connect(_on_repeat_selected)
	_setup_options()
	_build_game_checkboxes()
	ready_button.visible = not GameSession.local_is_host
	start_button.visible = GameSession.local_is_host
	role_label.text = "身份：房主" if GameSession.local_is_host else "身份：客户端"
	_refresh(GameSession.get_sorted_players())


func _on_players_changed(players: Array[SessionPlayer]) -> void:
	_refresh(players)


func _on_phase_changed(_phase: int) -> void:
	_refresh(GameSession.get_sorted_players())


func _on_playlist_changed() -> void:
	_refresh(GameSession.get_sorted_players())


func _on_ready_pressed() -> void:
	var local_player: SessionPlayer = GameSession.get_local_player()
	if local_player != null:
		NetworkManager.set_local_ready(not local_player.is_ready)


func _on_rounds_changed(value: float) -> void:
	if _updating_config or not GameSession.local_is_host:
		return
	var config: PartyPlaylistConfig = GameSession.playlist_config.duplicate_config()
	config.total_rounds = int(value)
	_apply_config(config)


func _on_intermission_changed(value: float) -> void:
	if _updating_config or not GameSession.local_is_host:
		return
	var config: PartyPlaylistConfig = GameSession.playlist_config.duplicate_config()
	config.intermission_seconds = int(value)
	_apply_config(config)


func _on_order_selected(index: int) -> void:
	if _updating_config or not GameSession.local_is_host:
		return
	var config: PartyPlaylistConfig = GameSession.playlist_config.duplicate_config()
	config.order_mode = index
	_apply_config(config)


func _on_repeat_selected(index: int) -> void:
	if _updating_config or not GameSession.local_is_host:
		return
	var config: PartyPlaylistConfig = GameSession.playlist_config.duplicate_config()
	config.repeat_policy = index
	_apply_config(config)


func _on_game_toggled(enabled: bool, game_id: StringName) -> void:
	if _updating_config or not GameSession.local_is_host:
		return
	var config: PartyPlaylistConfig = GameSession.playlist_config.duplicate_config()
	if enabled and not config.selected_game_ids.has(game_id):
		config.selected_game_ids.append(game_id)
	elif not enabled:
		config.selected_game_ids.erase(game_id)
	_apply_config(config)


func _apply_config(config: PartyPlaylistConfig) -> void:
	var update_error: Error = NetworkManager.update_playlist_config(config)
	if update_error != OK:
		status_label.text = _playlist_error_text(config)
	_refresh(GameSession.get_sorted_players())


func _refresh(players: Array[SessionPlayer]) -> void:
	_clear_player_rows()
	for player: SessionPlayer in players:
		players_container.add_child(_create_player_row(player))
	_refresh_config_controls()
	var local_player: SessionPlayer = GameSession.get_local_player()
	if local_player != null and not local_player.is_host:
		ready_button.text = "取消准备" if local_player.is_ready else "准备"
		ready_button.disabled = GameSession.phase != GameSessionState.Phase.LOBBY
	var available_ids: Array[StringName] = _available_game_ids()
	var config_valid: bool = (
		GameSession.playlist_config.validate_for_start(available_ids) == OK
		if not GameSession.playlist_config.selected_game_ids.is_empty()
		else false
	)
	start_button.disabled = not GameSession.can_host_start() or not config_valid
	if not config_valid:
		status_label.text = _playlist_error_text(GameSession.playlist_config)
	elif players.size() < 2:
		status_label.text = "至少需要 2 名玩家才能开始。"
	elif GameSession.can_host_start():
		status_label.text = "配置有效且所有玩家已准备，可以开始。"
	elif GameSession.local_is_host:
		status_label.text = "等待其他玩家准备。"
	else:
		status_label.text = "准备后等待房主开始。"


func _refresh_config_controls() -> void:
	var config: PartyPlaylistConfig = GameSession.playlist_config
	_updating_config = true
	rounds_spin_box.value = config.total_rounds
	intermission_spin_box.value = config.intermission_seconds
	order_option.select(config.order_mode)
	repeat_option.select(config.repeat_policy)
	for game_id: StringName in _game_checkboxes:
		_game_checkboxes[game_id].set_pressed_no_signal(
			config.selected_game_ids.has(game_id)
		)
	var once_only_disabled: bool = config.total_rounds > config.selected_game_ids.size()
	repeat_option.get_popup().set_item_disabled(
		PartyPlaylistConfig.RepeatPolicy.ONCE_ONLY,
		once_only_disabled
	)
	var editable: bool = GameSession.local_is_host
	rounds_spin_box.editable = editable
	intermission_spin_box.editable = editable
	order_option.disabled = not editable
	repeat_option.disabled = not editable
	for checkbox: CheckBox in _game_checkboxes.values():
		checkbox.disabled = not editable
	rules_label.text = "%d 局 · %d 秒局间等待 · %s · %s" % [
		config.total_rounds,
		config.intermission_seconds,
		"随机顺序" if config.order_mode == PartyPlaylistConfig.OrderMode.RANDOM else "勾选顺序",
		(
			"不连续重复"
			if config.repeat_policy == PartyPlaylistConfig.RepeatPolicy.NO_CONSECUTIVE
			else "整场仅一次"
		),
	]
	_updating_config = false


func _setup_options() -> void:
	if order_option.item_count == 0:
		order_option.add_item("随机顺序")
		order_option.add_item("按勾选顺序")
	if repeat_option.item_count == 0:
		repeat_option.add_item("不连续重复")
		repeat_option.add_item("整场仅出现一次")


func _build_game_checkboxes() -> void:
	for child: Node in games_container.get_children():
		games_container.remove_child(child)
		child.queue_free()
	_game_checkboxes.clear()
	for definition: MinigameDefinition in NetworkManager.get_minigame_definitions():
		var checkbox: CheckBox = CheckBox.new()
		checkbox.text = definition.display_name
		checkbox.add_theme_font_size_override("font_size", 20)
		checkbox.toggled.connect(_on_game_toggled.bind(definition.game_id))
		games_container.add_child(checkbox)
		_game_checkboxes[definition.game_id] = checkbox


func _playlist_error_text(config: PartyPlaylistConfig) -> String:
	if config.selected_game_ids.is_empty():
		return "请至少选择一个小游戏。"
	if (
		config.repeat_policy == PartyPlaylistConfig.RepeatPolicy.ONCE_ONLY
		and config.total_rounds > config.selected_game_ids.size()
	):
		return "“整场仅出现一次”要求总局数不超过已选小游戏数量。"
	if (
		config.repeat_policy == PartyPlaylistConfig.RepeatPolicy.NO_CONSECUTIVE
		and config.total_rounds > 1
		and config.selected_game_ids.size() == 1
	):
		return "只选择一个小游戏时，多局模式无法避免连续重复。"
	return "播放列表配置无效。"


func _available_game_ids() -> Array[StringName]:
	var game_ids: Array[StringName] = []
	for definition: MinigameDefinition in NetworkManager.get_minigame_definitions():
		game_ids.append(definition.game_id)
	return game_ids


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
	for child: Node in players_container.get_children():
		players_container.remove_child(child)
		child.queue_free()


func _assert_required_references() -> void:
	assert(role_label != null, "Lobby requires role_label.")
	assert(players_container != null, "Lobby requires players_container.")
	assert(ready_button != null, "Lobby requires ready_button.")
	assert(start_button != null, "Lobby requires start_button.")
	assert(leave_button != null, "Lobby requires leave_button.")
	assert(status_label != null, "Lobby requires status_label.")
	assert(rounds_spin_box != null, "Lobby requires rounds_spin_box.")
	assert(intermission_spin_box != null, "Lobby requires intermission_spin_box.")
	assert(order_option != null, "Lobby requires order_option.")
	assert(repeat_option != null, "Lobby requires repeat_option.")
	assert(games_container != null, "Lobby requires games_container.")
	assert(rules_label != null, "Lobby requires rules_label.")
