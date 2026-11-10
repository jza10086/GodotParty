extends Control
## Editor-run Avalon interaction lab. No PartyAPI, lobby or multiplayer peer.
## Uses the production UI/session and the real match model with scenario actions.
const Simulation: Script = preload("res://local_simulation/avalon_simulation.gd")
const AvalonUI: Script = preload("res://games/minigame/gp_avalon/scripts/ui/avalon.gd")
const AvalonTable: PackedScene = preload("res://games/minigame/gp_avalon/scenes/avalon.tscn")
const Session: Script = preload("res://games/minigame/gp_avalon/scripts/session/game_session.gd")
const FONT: Font = preload("res://games/minigame/gp_avalon/assets/fonts/NotoSansSC-Regular.otf")
@export var initial_case: String = "intro"
@export_range(5, 8) var initial_player_count: int = 5
var simulation: RefCounted
var stage: Control
var session: Node
var viewer: int = 1
var selected_case: int = 0
var replay_buttons: Array[BaseButton] = []
var replay_remaining: float = 0.0
var selection_remaining: int = 0
var automation_elapsed: float = 0.0
var paused: bool = false
var saved_time_scale: float = 1.0
var drawer: PanelContainer
var toggle_button: Button
var case_choice: OptionButton
var count_choice: OptionButton
var viewer_choice: OptionButton
var speed_choice: OptionButton
var hint: Label
var status: Label
var feedback: Label
var players_box: VBoxContainer
var auto_results: CheckButton
var auto_players: CheckButton
var negative_actions: CheckButton
var reduced: CheckButton
var pause_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	saved_time_scale = Engine.time_scale
	_build_console()
	for index: int in Simulation.CASES.size():
		if str(Simulation.CASES[index].id) == initial_case:
			selected_case = index
	count_choice.select(clampi(initial_player_count, 5, 8) - 5)
	load_case(selected_case)

func _exit_tree() -> void:
	Engine.time_scale = saved_time_scale

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			toggle_console()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F2:
			load_case(selected_case)
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not paused:
		_tick(delta)

func _tick(delta: float) -> void:
	if simulation == null:
		return
	if replay_remaining > 0.0:
		replay_remaining -= delta
		if replay_remaining <= 0.0:
			_finish_replay()
		return
	if not is_instance_valid(stage) or stage.subtitles.intro_active or stage.exited:
		return
	if auto_results.button_pressed and simulation.model.advance_time(delta):
		publish()
	if auto_players.button_pressed and not simulation.model.finished():
		automation_elapsed += delta
		if automation_elapsed >= 0.8:
			automation_elapsed = 0.0
			step_other()

func _label(text: String, parent: Node, font_size: int = 17) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(text: String, parent: Node, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 38
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _row(parent: Node) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row

func _check(text: String, parent: Node) -> CheckButton:
	var button: CheckButton = CheckButton.new()
	button.text = text
	button.custom_minimum_size.y = 34
	parent.add_child(button)
	return button

func _build_console() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var chrome: Control = Control.new()
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var console_theme: Theme = Theme.new()
	console_theme.default_font = FONT
	console_theme.default_font_size = 17
	chrome.theme = console_theme
	layer.add_child(chrome)
	toggle_button = _button("收起控制台 · F1", chrome, toggle_console)
	toggle_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toggle_button.offset_left = -224
	toggle_button.offset_right = -20
	toggle_button.offset_top = 16
	toggle_button.offset_bottom = 58
	drawer = PanelContainer.new()
	drawer.name = "SimulatorConsole"
	chrome.add_child(drawer)
	drawer.anchor_left = 1.0
	drawer.anchor_right = 1.0
	drawer.anchor_bottom = 1.0
	drawer.offset_left = -444
	drawer.offset_right = -20
	drawer.offset_top = 70
	drawer.offset_bottom = -20
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#12232af5")
	style.border_color = Color("#d9bb79")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	drawer.add_theme_stylebox_override("panel", style)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	drawer.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size.x = 376
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	_label("阿瓦隆 · 离线模拟台", box, 23)
	_label("F1 收起/展开 · F2 重播当前场景\n控制台为全知调试视角；牌桌仍按当前玩家过滤身份。", box, 15)
	var setup: HBoxContainer = _row(box)
	count_choice = OptionButton.new()
	for count: int in range(5, 9):
		count_choice.add_item("%d 人" % count, count)
	setup.add_child(count_choice)
	count_choice.item_selected.connect(func(_index: int): load_case(selected_case))
	viewer_choice = OptionButton.new()
	viewer_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewer_choice.fit_to_longest_item = false
	setup.add_child(viewer_choice)
	viewer_choice.item_selected.connect(func(index: int): switch_view(index))
	case_choice = OptionButton.new()
	case_choice.fit_to_longest_item = false
	for entry: Dictionary in Simulation.CASES:
		case_choice.add_item(str(entry.name))
	box.add_child(case_choice)
	case_choice.item_selected.connect(load_case)
	var navigation: HBoxContainer = _row(box)
	_button("上一个", navigation, func(): load_case(posmod(selected_case - 1, Simulation.CASES.size())))
	_button("重播 · F2", navigation, func(): load_case(selected_case))
	_button("下一个", navigation, func(): load_case((selected_case + 1) % Simulation.CASES.size()))
	hint = _label("", box, 16)
	hint.add_theme_color_override("font_color", Color("#d9bb79"))
	status = _label("", box, 16)
	var timing: HBoxContainer = _row(box)
	speed_choice = OptionButton.new()
	for speed: String in ["0.25× 慢放", "0.5× 慢放", "1× 正常", "2× 快放"]:
		speed_choice.add_item(speed)
	speed_choice.select(2)
	timing.add_child(speed_choice)
	speed_choice.item_selected.connect(func(index: int): Engine.time_scale = [0.25, 0.5, 1.0, 2.0][index])
	pause_button = _button("暂停", timing, toggle_pause)
	_button("步进 1/30 秒", timing, step_frame)
	auto_results = _check("结果满 3 秒自动推进", box)
	auto_players = _check("每 0.8 秒代操作其他玩家", box)
	negative_actions = _check("代操作偏向反对 / 破坏", box)
	reduced = _check("减少动态效果", box)
	reduced.toggled.connect(func(value: bool):
		if is_instance_valid(stage):
			stage.reduced_motion = value
			stage._render())
	var flow: HBoxContainer = _row(box)
	_button("推进结果", flow, advance_result)
	_button("切到待行动者", flow, focus_pending)
	var others: HBoxContainer = _row(box)
	_button("代操作下一人", others, step_other)
	_button("完成其他玩家", others, complete_others)
	var stress: HBoxContainer = _row(box)
	_button("重复快照 ×10", stress, repeat_snapshot)
	_button("模拟过期请求", stress, stale_request)
	_label("各玩家代操作（可包含当前玩家）", box, 18)
	players_box = VBoxContainer.new()
	players_box.add_theme_constant_override("separation", 6)
	box.add_child(players_box)
	var endings: HBoxContainer = _row(box)
	_button("模拟退出取消", endings, cancel_match)
	_button("打开身份百科", endings, func():
		if is_instance_valid(stage): stage._show_role_guide())
	feedback = _label("", box, 15)
	feedback.add_theme_color_override("font_color", Color("#f1b99b"))

func toggle_console() -> void:
	drawer.visible = not drawer.visible
	toggle_button.text = "收起控制台 · F1" if drawer.visible else "模拟控制台 · F1"

## Reconstruct only this disposable fixture, leaving the production UI unchanged.
func load_case(index: int) -> void:
	selected_case = clampi(index, 0, Simulation.CASES.size() - 1)
	case_choice.select(selected_case)
	simulation = Simulation.new()
	var entry: Dictionary = Simulation.CASES[selected_case]
	if not simulation.build(str(entry.id), count_choice.get_selected_id()):
		feedback.text = "场景构造失败：" + "；".join(simulation.errors)
		return
	count_choice.select(simulation.player_count - 5)
	viewer = simulation.preferred_seat
	hint.text = str(entry.hint)
	feedback.text = "已载入。默认停留在结果页；可勾选自动推进完整游玩。"
	automation_elapsed = 0.0
	selection_remaining = 0
	_mount_stage()
	replay_remaining = 0.6 if not simulation.before_views.is_empty() or str(entry.id) == "selected" else 0.0
	if replay_remaining > 0.0:
		var before: Dictionary = simulation.before_views.get(viewer, simulation.snapshot(viewer))
		session.present(before)
	else:
		session.present(simulation.snapshot(viewer))
	if str(entry.id) != "intro":
		stage.subtitles.skip()
		stage.subtitles.advance_clock(3.0)
	_rebuild_viewers()
	_refresh_console()
	if replay_remaining > 0.0:
		_lock_table()
	if simulation.model.cancelled:
		session.error_occurred.emit(simulation.model.cancel_message)

func _mount_stage() -> void:
	replay_buttons.clear()
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
	if is_instance_valid(session):
		remove_child(session)
		session.queue_free()
	session = Session.new()
	session.game_id = "avalon"
	session.is_host = true
	session.self_id = viewer
	add_child(session)
	session.action_requested.connect(_on_action)
	stage = AvalonTable.instantiate()
	stage.reduced_motion = reduced.button_pressed
	add_child(stage)
	move_child(stage, 0)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.bind_session(session)
	stage.exit_requested.connect(func():
		feedback.text = "已结束当前预览。按 F2 重播，或切换其他场景。")
	stage.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT

func _unlock_table() -> void:
	for button: BaseButton in replay_buttons:
		if is_instance_valid(button):
			button.disabled = false
	replay_buttons.clear()

func _lock_table() -> void:
	for button: BaseButton in stage.find_children("*", "BaseButton", true, false):
		if not button.disabled:
			replay_buttons.append(button)
			button.disabled = true

func _finish_replay() -> void:
	_unlock_table()
	if str(Simulation.CASES[selected_case].id) == "selected":
		if selection_remaining == 0:
			publish()
			selection_remaining = mini(2, stage._quest_size())
		var team: Array[int] = simulation.team_for_quest()
		var index: int = mini(2, stage._quest_size()) - selection_remaining
		stage._toggle_team(team[index])
		selection_remaining -= 1
		if selection_remaining > 0:
			replay_remaining = 0.45
	else:
		publish()
	_refresh_console()

func _on_action(action: String, payload: Variant) -> void:
	if replay_remaining > 0.0:
		return
	var response: Dictionary = simulation.act(viewer, action, payload)
	if not response.get("ok", false):
		session.error_occurred.emit(str(response.get("error", "行动失败")))
	else:
		feedback.text = "已提交：" + action
		publish()

func publish() -> void:
	session.present(simulation.snapshot(viewer))
	_refresh_console()

func _rebuild_viewers() -> void:
	viewer_choice.clear()
	viewer_choice.add_item("观战者", 0)
	for seat: int in range(1, simulation.player_count + 1):
		var role: String = str(AvalonUI.AVALON_ROLES.get(simulation.role_for(seat), ""))
		viewer_choice.add_item("%d · %s · %s" % [seat, str(simulation.roster[seat - 1].name), role], seat)
	viewer_choice.select(viewer)

func switch_view(seat: int) -> void:
	viewer = clampi(seat, 0, simulation.player_count)
	replay_remaining = 0.0
	selection_remaining = 0
	_mount_stage()
	publish()
	stage.subtitles.skip()
	stage.subtitles.advance_clock(3.0)
	viewer_choice.select(viewer)
	feedback.text = "已切换玩家视角；身份信息仍来自该玩家的过滤快照。"

func _refresh_console() -> void:
	var phase: String = str(simulation.model.rules.state.phase)
	var pending: Array = simulation.pending()
	var pending_names: PackedStringArray = []
	for seat: int in pending:
		pending_names.append(str(simulation.roster[seat - 1].name))
	status.text = "%d/5 回合 · %s\n待行动：%s" % [
		int(simulation.model.rules.state.quest_number),
		str(AvalonUI.AVALON_PHASES.get(phase, phase)),
		"、".join(pending_names) if not pending_names.is_empty() else "无"]
	if simulation.model.cancelled:
		status.text = "本局已取消\n" + simulation.model.cancel_message
	elif replay_remaining > 0.0:
		status.text += "\n正在播放过渡前的画面…"
	for child: Node in players_box.get_children():
		players_box.remove_child(child)
		child.queue_free()
	for seat: int in range(1, simulation.player_count + 1):
		var row: HBoxContainer = _row(players_box)
		var role: String = str(AvalonUI.AVALON_ROLES.get(simulation.role_for(seat), ""))
		var label: Label = _label("%d %s · %s%s" % [seat, str(simulation.roster[seat - 1].name), role, "（当前）" if seat == viewer else ""], row, 14)
		label.custom_minimum_size.x = 212
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var positive_text: String = "赞成"
		var negative_text: String = "反对"
		if phase == "quest":
			positive_text = "成功"
			negative_text = "失败"
		elif phase == "assassination":
			positive_text = "刺错"
			negative_text = "刺中"
		elif phase == "team_proposal":
			positive_text = "选队"
		var positive: Button = _button(positive_text, row, func(): act_for(seat, true))
		var negative: Button = _button(negative_text, row, func(): act_for(seat, false))
		positive.disabled = seat not in pending or replay_remaining > 0.0
		negative.disabled = positive.disabled or phase == "team_proposal" or (phase == "quest" and not simulation.is_evil(seat))

func act_for(seat: int, positive: bool) -> void:
	if replay_remaining > 0.0:
		return
	var response: Dictionary = simulation.step(seat, positive)
	feedback.text = "已代操作 %s" % str(simulation.roster[seat - 1].name) if response.get("ok", false) else str(response.get("error", "行动失败"))
	publish()

func step_other() -> void:
	if replay_remaining > 0.0:
		return
	for seat: int in simulation.pending():
		if seat != viewer:
			act_for(seat, not negative_actions.button_pressed)
			return
	feedback.text = "其他玩家已完成；请操作当前玩家，或推进结果。"

func complete_others() -> void:
	if replay_remaining > 0.0:
		return
	# Capture one phase's pending seats, so this cannot spill into a later phase.
	var pending: Array = simulation.pending().duplicate()
	for seat: int in pending:
		if seat != viewer:
			act_for(seat, not negative_actions.button_pressed)

func advance_result() -> void:
	if replay_remaining > 0.0:
		return
	if simulation.advance():
		publish()
	else:
		feedback.text = "当前不是可推进的结果阶段，请先完成必要行动。"

func focus_pending() -> void:
	if not simulation.pending().is_empty():
		switch_view(int(simulation.pending()[0]))

func repeat_snapshot() -> void:
	if replay_remaining > 0.0:
		return
	for index: int in 10:
		publish()
	feedback.text = "重复呈现同一快照 10 次；观察动画和字幕是否连续。"

func stale_request() -> void:
	if replay_remaining > 0.0:
		return
	var response: Dictionary = simulation.model.act(simulation.player_key(viewer), "team_vote", 1, simulation.model.epoch - 1)
	feedback.text = str(response.get("error", "意外接受了过期请求"))
	session.error_occurred.emit(feedback.text)

func cancel_match() -> void:
	_unlock_table()
	simulation.model.cancel("模拟玩家退出，本局取消，不计胜负。", simulation.player_key(viewer))
	replay_remaining = 0.0
	publish()
	session.error_occurred.emit(simulation.model.cancel_message)

func toggle_pause() -> void:
	paused = not paused
	pause_button.text = "继续" if paused else "暂停"
	if is_instance_valid(stage):
		stage.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT

## Advance the known presentation clocks while the table is paused.
func step_frame() -> void:
	if not paused:
		toggle_pause()
	_tick(1.0 / 30.0)
	if not is_instance_valid(stage):
		return
	stage.subtitles.advance_clock(1.0 / 30.0)
	stage.table_effects.advance_clock(1.0 / 30.0)
	stage.atmosphere._process(1.0 / 30.0)
	for ornament: Node in stage.find_children("HeraldicOrnament", "", true, false):
		ornament._process(1.0 / 30.0)
		if is_instance_valid(ornament.hover_tween):
			ornament.hover_tween.custom_step(1.0 / 30.0)
