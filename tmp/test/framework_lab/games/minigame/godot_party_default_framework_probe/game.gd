extends Control
## Test-only child. All probes use real scope APIs; static observations outlive freed scenes.
static var observations: Dictionary = {}
enum Phase { PREPARING, RUNNING, SUBMITTED, STOPPED }
var api: PartyAPI
var request: Dictionary
var phase: Phase = Phase.PREPARING
var events: Array[String] = []
var token: int = 0
var pending: bool = false
var deadline: float = 0.0
var expected: Array[int] = []
var replies: Dictionary = {}
var receipts: Dictionary = {}
var excluded: Dictionary = {}
var parent_reply: bool = false
var errors: Array[String] = []
var _ready_timer: Timer
var _status: Label
var _log: RichTextLabel
var _run: Button
var _finish: Button
var _action: Button

func party_setup(value: PartyAPI, config: Dictionary) -> void:
	api = value
	request = config.duplicate(true)
	observations[api.scope_id] = {"setup": 1, "ready": 0, "start": 0, "stop": 0,
		"cleanup": 0, "exit": 0, "parent_reply": false, "failures": 0, "node": weakref(self), "api": api}
	api.net.message_received.connect(_message)
	api.net.parent_message_received.connect(_parent_message)
	api.players_changed.connect(_players_changed)
	var error: Error = api.on_close(_cleanup)
	if error != OK:
		push_error("Cannot register probe cleanup: " + error_string(error))

func _ready() -> void:
	_build_ui()
	_event("setup → 入树初始化；尚未允许参赛输入")
	_ready_timer = Timer.new()
	_ready_timer.one_shot = true
	add_child(_ready_timer)
	_ready_timer.timeout.connect(_mark_ready)
	var delay: float = float(api.get_settings().ready_delay)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--lab-delay="):
			delay = argument.trim_prefix("--lab-delay=").to_float()
	_ready_timer.start(maxf(0.01, delay))

func _mark_ready() -> void:
	observations[api.scope_id].ready += 1
	_event("mark_ready")
	_checked(api.mark_ready(), "就绪")

func party_start() -> void:
	phase = Phase.RUNNING
	observations[api.scope_id].start += 1
	if observations[api.scope_id].ready != 1:
		_error("party_start 早于本端就绪")
	_event("party_start · " + ("房主" if api.is_host() else "客户端"))
	_run.disabled = not api.is_host()
	_action.disabled = not _participating()
	_checked(api.net.send_to_parent(&"lab_started", {"scope": api.scope_id}), "子→父")

func run_checks() -> void:
	if phase != Phase.RUNNING or not api.is_host() or pending:
		return
	token += 1
	replies.clear()
	receipts.clear()
	excluded.clear()
	errors.clear()
	expected.clear()
	for player: Dictionary in api.get_room_players():
		if player.connected and int(player.peer_id) not in expected:
			expected.append(int(player.peer_id))
	pending = true
	deadline = 10.0
	_run.disabled = true
	_finish.disabled = true
	_event("开始检查 %d；预期接收端 %s" % [token, expected])
	if not _checked(api.net.broadcast(&"challenge", {"token": token}), "广播（包含本机）"):
		return
	if expected.size() > 1:
		_checked(api.net.broadcast(&"excluded", {"token": token}, false), "广播（排除本机）")

func _message(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if phase != Phase.RUNNING:
		return
	if not payload is Dictionary or not payload.get("token") is int:
		_error("探针消息结构错误")
		return
	var peer: int = int(sender.peer_id)
	if topic in [&"challenge", &"excluded", &"receipt"]:
		if peer != 1:
			_error("探针控制消息不是来自房主")
			return
		if topic == &"challenge":
			token = payload.token
			_checked(api.net.send_to_host(&"reply", {"token": token, "participant": _participating()}), "客户端→房主")
		elif topic == &"excluded":
			if api.is_host():
				_error("include_self=false 仍投递给本机")
				return
			_checked(api.net.send_to_host(&"excluded_ack", {"token": payload.token}), "排除本机回执")
		else:
			_checked(api.net.send_to_host(&"receipt_ack", {"token": payload.token}), "定向流回执")
		return
	if not api.is_host() or payload.token != token:
		return
	if peer not in expected:
		_error("收到非预期端消息")
		return
	if topic == &"action":
		if not _sender_participates(sender):
			_error("观战者试图提交参赛操作")
			return
		_event("参赛操作来自 peer " + str(peer))
		return
	if not pending:
		_error("检查完成后收到多余回执：" + str(topic))
		return
	if topic == &"reply":
		if replies.has(peer) or not payload.get("participant") is bool or payload.participant != _sender_participates(sender):
			_error("重复回执或参赛身份不一致")
			return
		replies[peer] = payload.participant
		_event("peer %d：上行回执，参赛=%s" % [peer, payload.participant])
		_checked(api.net.send_to_peer(peer, &"receipt", {"token": token}), "定向可靠流")
	elif topic == &"receipt_ack":
		if receipts.has(peer):
			_error("重复定向回执")
			return
		receipts[peer] = true
		_event("peer %d：定向流回执" % peer)
	elif topic == &"excluded_ack":
		if peer == 1 or excluded.has(peer):
			_error("排除本机回执范围/次数错误")
			return
		excluded[peer] = true
		_event("peer %d：排除本机广播回执" % peer)
	else:
		_error("未知探针消息：" + str(topic))
		return
	_evaluate()

func _sender_participates(sender: Dictionary) -> bool:
	for player: Dictionary in api.get_players():
		if player.connected and player.player_id in sender.player_ids:
			return true
	return false

func _participating() -> bool:
	for player: Dictionary in api.get_players():
		if player.is_local and player.connected:
			return true
	return false

func _parent_message(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if int(sender.peer_id) != 1 or topic != &"lab_parent_ack" or not payload is Dictionary or payload.get("scope") != api.scope_id:
		_error("父→子回执不匹配")
		return
	parent_reply = true
	observations[api.scope_id].parent_reply = true
	_event("父→子回执已收到")
	if api.is_host():
		_evaluate()

func _evaluate() -> void:
	if not pending or not errors.is_empty():
		return
	if replies.size() == expected.size() and receipts.size() == expected.size() and excluded.size() == expected.size() - 1 and parent_reply:
		pending = false
		_finish.disabled = false
		_run.disabled = false
		if expected.size() > 1:
			_event("通过：广播、排除本机、客户端→房主、定向流、参赛身份、父子通信")
		else:
			_event("通过：本端回环、参赛身份、父子通信；远端通信及排除本机广播不适用")

func send_action() -> void:
	if phase == Phase.RUNNING and _participating():
		_checked(api.net.send_to_host(&"action", {"token": token}), "参赛操作")

func finish_round() -> void:
	if not api.is_host() or phase != Phase.RUNNING or pending or receipts.size() != expected.size() or expected.is_empty() or not errors.is_empty() or not parent_reply:
		return
	var rows: Array[Dictionary] = []
	for player: Dictionary in api.get_players():
		rows.append({"player_id": player.player_id, "rank": 0,
			"status": "unranked" if player.connected else "withdrawn"})
	var result: Dictionary = {"request_id": request.request_id, "reason": "completed", "rankings": rows,
		"game_data": {"scope": api.scope_id, "peers": expected, "receipts": receipts.size(),
			"spectators": api.get_spectators().size(), "host_participating": _participating()}}
	if not _checked(api.finish(result), "提交普通结果"):
		return
	phase = Phase.SUBMITTED
	_finish.disabled = true
	_run.disabled = true
	_action.disabled = true
	_event("候选已接受；正式提交由父游戏观察")

func _process(delta: float) -> void:
	if pending:
		deadline -= delta
		if deadline <= 0.0:
			pending = false
			_error("回执超时：replies=%s receipts=%s excluded=%s" % [replies.keys(), receipts.keys(), excluded.keys()])
			_run.disabled = false

func _players_changed() -> void:
	_action.disabled = phase != Phase.RUNNING or not _participating()
	if pending:
		pending = false
		_error("检查期间名单变化，请重新检查")
		_run.disabled = not api.is_host()

func party_stop(reason: StringName) -> void:
	phase = Phase.STOPPED
	observations[api.scope_id].stop += 1
	_ready_timer.stop()
	set_process(false)
	_event("party_stop: " + str(reason))

func _cleanup() -> void:
	observations[api.scope_id].cleanup += 1
	observations[api.scope_id].timer_stopped = _ready_timer.is_stopped()
	print("LAB_CLOSE ", api.scope_id, " stop=", observations[api.scope_id].stop)

func _exit_tree() -> void:
	observations[api.scope_id].exit += 1

func _checked(error: Error, operation: String) -> bool:
	if error == OK:
		return true
	_error(operation + "：" + error_string(error))
	return false

func _error(message: String) -> void:
	errors.append(message)
	observations[api.scope_id].failures += 1
	_finish.disabled = true
	_event("失败：" + message)
	push_error(message)

func _event(message: String) -> void:
	events.append(message)
	_status.text = "轮次 %s · %s · %s" % [api.round_id, "房主" if api.is_host() else "客户端", "参赛" if _participating() else "观战"]
	_log.text = "\n".join(events)

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var title: Label = Label.new()
	title.text = "框架验证 · 基础闭环（无玩法）"
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var roster: Label = Label.new()
	var names: PackedStringArray = []
	for player: Dictionary in api.get_room_players():
		names.append("%s · peer %d" % [player.name, player.peer_id])
	roster.text = "房间：" + " / ".join(names)
	roster.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(roster)
	var buttons: HBoxContainer = HBoxContainer.new()
	column.add_child(buttons)
	_run = _button(buttons, "运行通信检查（房主）", run_checks)
	_action = _button(buttons, "发送参赛操作", send_action)
	_finish = _button(buttons, "结束并提交普通结果（房主）", finish_round)
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	column.add_child(_log)

func _button(parent: Node, caption: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = caption
	button.disabled = true
	button.custom_minimum_size.y = 52
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
