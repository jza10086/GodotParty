## Shared intermission and final playlist results screen.
class_name PlaylistResultsScreen
extends Control

@export var title_label: Label
@export var round_label: Label
@export var next_game_label: Label
@export var countdown_label: Label
@export var round_results_container: VBoxContainer
@export var standings_container: VBoxContainer
@export var pause_button: Button
@export var next_button: Button
@export var return_button: Button
@export var leave_button: Button
@export var client_hint_label: Label

var _countdown_duration_seconds: float = 0.0
var _countdown_started_ticks: int = 0
var _next_game_id: StringName = &""


func _ready() -> void:
	_assert_required_references()
	pause_button.pressed.connect(NetworkManager.pause_intermission_auto_advance)
	next_button.pressed.connect(NetworkManager.request_next_round)
	return_button.pressed.connect(NetworkManager.request_return_to_lobby)
	leave_button.pressed.connect(NetworkManager.leave_session)
	set_process(true)


func setup_intermission(duration_seconds: float, next_game_id: StringName) -> void:
	_countdown_duration_seconds = duration_seconds
	_countdown_started_ticks = Time.get_ticks_msec()
	_next_game_id = next_game_id
	refresh_from_session()


func setup_session_results() -> void:
	_countdown_duration_seconds = 0.0
	_countdown_started_ticks = 0
	_next_game_id = &""
	refresh_from_session()


func refresh_from_session() -> void:
	var is_intermission: bool = GameSession.phase == GameSessionState.Phase.INTERMISSION
	title_label.text = "本局结果" if is_intermission else "整场排名"
	round_label.text = "第 %d / %d 局" % [
		GameSession.current_round_index + 1,
		GameSession.playlist_config.total_rounds,
	]
	next_game_label.visible = is_intermission
	countdown_label.visible = is_intermission
	pause_button.visible = is_intermission and GameSession.local_is_host
	next_button.visible = is_intermission and GameSession.local_is_host
	return_button.visible = GameSession.local_is_host
	client_hint_label.visible = not GameSession.local_is_host
	if is_intermission:
		var definition: MinigameDefinition = NetworkManager.get_minigame_definition(_next_game_id)
		var next_name: String = definition.display_name if definition != null else String(_next_game_id)
		next_game_label.text = "下一局：%s" % next_name
		pause_button.disabled = GameSession.intermission_paused
		pause_button.text = "已暂停自动推进" if GameSession.intermission_paused else "暂停自动推进"
		client_hint_label.text = (
			"房主已暂停，等待房主手动开始下一局。"
			if GameSession.intermission_paused
			else "等待房主，倒计时结束后自动进入下一局。"
		)
	else:
		client_hint_label.text = "等待房主返回大厅。"
	_build_round_results()
	_build_standings()


func _process(_delta: float) -> void:
	if GameSession.phase != GameSessionState.Phase.INTERMISSION:
		return
	if GameSession.intermission_paused:
		countdown_label.text = "已暂停"
		return
	var elapsed: float = float(
		Time.get_ticks_msec() - _countdown_started_ticks
	) / 1000.0
	var remaining: int = maxi(ceili(_countdown_duration_seconds - elapsed), 0)
	countdown_label.text = "%d 秒后自动进入下一局" % remaining


func _build_round_results() -> void:
	_clear_container(round_results_container)
	for result: MinigamePlayerResult in GameSession.get_ranked_results_for_display():
		var label: Label = Label.new()
		var performance: String = "%d 分" % result.score
		var definition: MinigameDefinition = NetworkManager.get_minigame_definition(
			GameSession.current_game_id
		)
		if (
			definition != null
			and definition.ranking_mode == MinigameDefinition.RankingMode.STRICT_ORDER
		):
			performance = (
				"%.3f 秒" % (float(result.elapsed_ms) / 1000.0)
				if result.is_complete
				else "%d 分" % result.score
			)
		label.text = "%d. %s — %s%s" % [
			result.rank,
			result.display_name,
			performance,
			"（已退出）" if result.is_withdrawn else "",
		]
		label.add_theme_font_size_override("font_size", 22)
		round_results_container.add_child(label)


func _build_standings() -> void:
	_clear_container(standings_container)
	for standing: PartyStanding in GameSession.get_sorted_standings():
		var label: Label = Label.new()
		label.text = "%d. %s — %d 积分%s" % [
			standing.rank,
			standing.display_name,
			standing.points,
			"（已退出）" if standing.is_withdrawn else "",
		]
		label.add_theme_font_size_override("font_size", 24)
		standings_container.add_child(label)


func _clear_container(container: VBoxContainer) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _assert_required_references() -> void:
	assert(title_label != null, "PlaylistResults requires title_label.")
	assert(round_label != null, "PlaylistResults requires round_label.")
	assert(next_game_label != null, "PlaylistResults requires next_game_label.")
	assert(countdown_label != null, "PlaylistResults requires countdown_label.")
	assert(round_results_container != null, "PlaylistResults requires round_results_container.")
	assert(standings_container != null, "PlaylistResults requires standings_container.")
	assert(pause_button != null, "PlaylistResults requires pause_button.")
	assert(next_button != null, "PlaylistResults requires next_button.")
	assert(return_button != null, "PlaylistResults requires return_button.")
	assert(leave_button != null, "PlaylistResults requires leave_button.")
	assert(client_hint_label != null, "PlaylistResults requires client_hint_label.")
