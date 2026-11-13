extends Node

## Automatic playlist parent. Queue and rewards are durable; only the host requests foreground children.
const Rules: Script = preload("res://games/maingame/godot_party_default_maingame_minigame_playlist/playlist_rules.gd")
var api: PartyAPI
var state: Dictionary = {}
var active: bool = false
var _busy: bool = false
var _queued: bool = false
var _wait: float = 0.0
var _message: Label
var _summary: Label
var _scores: Label
var _queue_label: Label
var _retry_button: Button
var _end_button: Button
var _last_button: Button

func party_setup(value: PartyAPI, _settings: Dictionary) -> void:
	api = value
	api.net.child_message_received.connect(_child_query)
	api.state_committed.connect(_state_committed)
	api.round_cancelled.connect(_round_cancelled)
	api.commit_failed.connect(_commit_failed)

## Answer a query from the host child with the request ID actually locked by this playlist.
func _child_query(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if topic != &"playlist/round_query" or sender.peer_id != 1 or state.launch.is_empty():
		return
	if not payload is Dictionary or not payload.get("nonce") is int:
		return
	var error: Error = api.net.send_to_child(&"playlist/round_info", {"nonce": payload.nonce, "request_id": state.launch.request_id})
	if error != OK:
		api.fail("round_info_failed", error_string(error))

func _ready() -> void:
	if api == null:
		push_error("请从 GodotParty 大厅启动小游戏轮换。")
		return
	var error: Error = api.mark_ready()
	if error != OK:
		api.fail("ready_failed", error_string(error))

func create_new_state(settings: Dictionary) -> Dictionary:
	return Rules.initial(api.get_pool("minigames"), settings, api.get_players(), api.get_seed())

func restore_state(value: Dictionary) -> void:
	state = value.duplicate(true)

func reduce_round_result(old_state: Dictionary, result: Dictionary) -> Dictionary:
	return Rules.settle(old_state, result)

func create_view() -> Node:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = GPPartyTheme.create()
	root.add_child(GPPartyTheme.Background.instantiate())
	var layout: MarginContainer = MarginContainer.new()
	layout.name = "Layout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "bottom"]:
		layout.add_theme_constant_override("margin_" + edge, 48)
	# This playlist presents content below the app actions; other main games own their layout.
	layout.add_theme_constant_override("margin_top", 160)
	root.add_child(layout)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 18)
	scroll.add_child(column)
	_label(column, "原版 · 小游戏轮换", 40)
	_summary = _label(column, "已完成 %d / %d 局 · %s · %s" % [state.get("completed", 0), state.get("queue", []).size(), state.get("rotation", "顺序"), "避免重复" if state.avoid_repeat else "允许重复"], 26)
	if state.get("queue", []).size() < int(state.get("requested_rounds", 0)):
		_label(column, "避免重复已开启，实际局数以所选小游戏数量为上限。", 20)
	_message = _label(column, _status_text(), 24)
	_scores = _label(column, "", 24)
	_label(column, "每局完成者获得「参赛人数 − 名次」积分，并列同分，退出者不获本局积分。", 20)
	_retry_button = _button(column, "重试本局", _retry, not api.is_host())
	_end_button = _button(column, "结束轮换并结算", _end, not api.is_host())
	_last_button = _button(column, "查看上一局成绩", _show_last, false)
	_label(column, "本次轮换队列", 28)
	_queue_label = _label(column, "", 22)
	_refresh_view()
	return root

func _label(parent: Node, value: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, caption: String, callback: Callable, disabled: bool) -> Button:
	var button: Button = Button.new()
	button.text = caption
	button.custom_minimum_size.y = 54
	button.disabled = disabled
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _game_name(id: String) -> String:
	return api.get_game_name(id)

func _player_name(id: String) -> String:
	for player: Dictionary in api.get_players():
		if player.player_id == id:
			return player.name
	return id

func _status_text() -> String:
	if not state.get("pause_reason", "").is_empty():
		return "轮换已暂停：" + str(state.pause_reason)
	var queue: Array = state.get("queue", [])
	var cursor: int = int(state.get("cursor", 0))
	if queue.is_empty():
		return "尚未选择小游戏，请结束后在大厅配置 minigames 列表。"
	if cursor >= queue.size():
		return "全部轮次完成，正在保存最终成绩。"
	return "即将自动开始：%s · 局间间隔 %d 秒" % [_game_name(queue[cursor]), int(state.get("interval", 0))]

func _presentation() -> Dictionary:
	var rows: Array[Dictionary] = []
	var scores: Dictionary = state.get("scores", {})
	for player: Dictionary in api.get_players():
		var points: int = int(scores.get(player.player_id, 0))
		var rank_value: int = 1
		for other: Dictionary in api.get_players():
			if other.connected and int(scores.get(other.player_id, 0)) > points:
				rank_value += 1
		rows.append({"player_id": player.player_id, "rank": rank_value if player.connected else 0, "status": "完成" if player.connected else "已退出", "metrics": {"points": points}})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.rank if a.rank > 0 else 999) < (b.rank if b.rank > 0 else 999))
	return {"title": "小游戏轮换 · 完成 %d / %d 局" % [state.get("completed", 0), state.get("queue", []).size()], "columns": [{"key": "points", "title": "派对积分", "format": "integer"}], "rows": rows}

func party_start() -> void:
	active = true
	_busy = false
	_wait = float(state.get("interval", 0))
	if api.is_host() and not _publish_standings():
		return
	_queue_advance()

func party_resume() -> void:
	party_start()

func party_suspend() -> void:
	active = false

func party_stop(_reason: StringName) -> void:
	active = false
	_queued = false

func _process(delta: float) -> void:
	if not active or api == null or not api.is_host() or _busy:
		return
	if _wait > 0.0:
		_wait = maxf(0.0, _wait - delta)
		if _wait == 0.0:
			_queue_advance()

## Defer until core has finished restoring the parent and emitting cancellation/commit signals.
func _queue_advance() -> void:
	if not active or not api.is_host() or _queued:
		return
	_queued = true
	_advance.call_deferred()

func _advance() -> void:
	_queued = false
	if not active or not api.is_host() or _busy or _wait > 0.0 or not state.get("pause_reason", "").is_empty():
		return
	if state.queue.is_empty():
		_pause("没有选择小游戏。请结束轮换，回到大厅勾选至少一项。")
		return
	if int(state.cursor) >= state.queue.size():
		_end()
		return
	if state.launch.is_empty():
		var participants: Array[String] = []
		for player: Dictionary in api.get_players():
			if player.connected:
				participants.append(player.player_id)
		if participants.is_empty():
			_pause("本局没有在线参赛者。")
			return
		var next: Dictionary = state.duplicate(true)
		next.attempt += 1
		next.launch = {"game_id": state.queue[state.cursor], "request_id": api.session_id + "/playlist/" + str(next.attempt), "participants": participants}
		_commit(next)
		return
	var launch: Dictionary = state.launch
	var participants: Array[String] = []
	participants.assign(launch.participants)
	_busy = true
	var error: Error = api.request_minigame(launch.game_id, {"request_id": launch.request_id, "mode": "standard"}, participants)
	if error != OK:
		_busy = false
		_pause("无法启动 %s：%s。请检查在线人数和小游戏规则。" % [_game_name(launch.game_id), error_string(error)])

func _commit(next: Dictionary) -> void:
	_busy = true
	var error: Error = api.commit_state(next)
	if error != OK:
		_busy = false
		_notice("状态提交未被接受：" + error_string(error))

func _state_committed(_revision: int) -> void:
	_refresh_view()
	_busy = false
	if active and api.is_host() and _publish_standings():
		_queue_advance()

## Publish restored/committed totals before the next child replaces the parent view.
func _publish_standings() -> bool:
	var error: Error = api.publish_standings(_presentation())
	if error != OK:
		api.fail("standings_failed", error_string(error))
		return false
	return true

func _round_cancelled(_round_id: String, reason: String) -> void:
	if api.is_host():
		_pause("本局取消：" + reason)

func _pause(reason: String) -> void:
	var next: Dictionary = state.duplicate(true)
	next.pause_reason = reason
	next.launch = {}
	_commit(next)

func _retry() -> void:
	if not active or not api.is_host() or _busy:
		return
	_wait = 0.0
	var next: Dictionary = state.duplicate(true)
	next.pause_reason = ""
	next.launch = {}
	_commit(next)

func _end() -> void:
	if not active or not api.is_host() or _busy:
		return
	_busy = true
	var error: Error = api.finish_session(_presentation())
	if error != OK:
		_busy = false
		_notice("最终结算未被接受：" + error_string(error))

func _show_last() -> void:
	api.show_results(api.get_round_presentation())

func _commit_failed(_code: String, message: String) -> void:
	_notice("保存失败，等待框架重试同一提交：" + message)

func _notice(message: String) -> void:
	if is_instance_valid(_message):
		_message.text = message


## Refresh existing controls so state commits retain keyboard focus and scroll position.
func _refresh_view() -> void:
	if not is_instance_valid(_message):
		return
	_summary.text = "已完成 %d / %d 局 · %s · %s" % [state.get("completed", 0), state.get("queue", []).size(), state.get("rotation", "顺序"), "避免重复" if state.avoid_repeat else "允许重复"]
	_message.text = _status_text()
	var score_lines: PackedStringArray = []
	for row: Dictionary in _presentation().rows:
		score_lines.append("%s  %s · %d 分" % [str(row.rank) + "." if row.rank > 0 else "—", _player_name(row.player_id), row.metrics.points])
	_scores.text = "\n".join(score_lines)
	_retry_button.visible = not state.get("pause_reason", "").is_empty()
	_end_button.visible = _retry_button.visible
	_last_button.visible = not state.get("last", {}).is_empty()
	var queue_lines: PackedStringArray = []
	var queue: Array = state.get("queue", [])
	for index: int in queue.size():
		var marker: String = "已完成" if index < int(state.get("cursor", 0)) else ("下一局" if index == int(state.get("cursor", 0)) else "待进行")
		queue_lines.append("%d. %s · %s" % [index + 1, _game_name(queue[index]), marker])
	_queue_label.text = "\n".join(queue_lines)
