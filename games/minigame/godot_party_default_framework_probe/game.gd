extends Control
## Interactive diagnostics for one real minigame scope. Only the most recent local
## lifecycle record survives scene release so the next round can inspect it.
static var last_round: Dictionary = {}
enum Phase { PREPARING, RUNNING, SUBMITTED, STOPPED }
var api: PartyAPI
var request_id: String
var phase: Phase = Phase.PREPARING
var previous: Dictionary
var record: Dictionary
var started: Dictionary[int, bool] = {}
var expected: Array[int] = []
var replies: Dictionary[int, bool] = {}
var receipts: Dictionary[int, bool] = {}
var excluded: Dictionary[int, bool] = {}
var token: int = 0
var pending: bool = false
var passed: bool = false
var parent_status: String = "未检查"
var parent_nonce: int = 0
var parent_deadline: int = 0
var deadline: int = 0
@onready var log_view: RichTextLabel = %Evidence
@onready var run_button: Button = %Run
@onready var action_button: Button = %Action
@onready var finish_button: Button = %Finish
@onready var parent_button: Button = %ParentCheck
@onready var delay_timer: Timer = %ReadyDelay

func party_setup(value: PartyAPI, request: Dictionary) -> void:
	api = value
	request_id = request.request_id
	previous = last_round if last_round.get("session") == api.session_id else {}
	record = {"session": api.session_id, "scope": api.scope_id, "node": weakref(self),
		"api": api, "ready": 0, "start": 0, "stop": 0, "close": 0, "exit": 0}
	last_round = record
	api.net.message_received.connect(_message)
	api.net.parent_message_received.connect(_parent_message)
	var error: Error = api.on_close(_closed)
	if error != OK:
		api.fail("probe_cleanup", error_string(error))

func _ready() -> void:
	if api == null:
		push_error("请从原版小游戏轮换启动框架测试小游戏。")
		return
	run_button.pressed.connect(run_checks)
	action_button.pressed.connect(send_action)
	parent_button.pressed.connect(check_parent)
	finish_button.pressed.connect(finish_round)
	api.players_changed.connect(_roster_changed)
	_roster_changed()
	_note("已初始化，等待各端技术就绪")
	var delay: float = api.get_settings().ready_delay
	if delay > 0.0:
		delay_timer.timeout.connect(_mark_ready)
		delay_timer.start(delay)
	else:
		_mark_ready()

func _mark_ready() -> void:
	record.ready += 1
	var error: Error = api.mark_ready()
	if error != OK:
		api.fail("probe_ready", error_string(error))

func party_start() -> void:
	record.start += 1
	if record.ready != 1 or record.start != 1:
		api.fail("probe_lifecycle", "本端就绪和开始次数错误")
		return
	phase = Phase.RUNNING
	if not previous.is_empty():
		var old: PartyAPI = previous.api
		var clean: bool = previous.stop == 1 and previous.close == 1 and previous.exit == 1 and previous.node.get_ref() == null and not old.is_open()
		if not clean or old.net.send_to_host(&"stale", {}) != ERR_UNAVAILABLE:
			api.fail("probe_cleanup", "上一轮作用域未正确关闭：" + str(previous.scope))
			return
		_note("上一轮通过：stop / close / exit 各一次，节点已释放，旧 API 拒绝发送")
		previous = {}
	_note("本端就绪并开始 · %s · %s" % ["房主" if api.is_host() else "客户端", "参赛" if _participating() else "观战"])
	_roster_changed()
	var error: Error = api.net.send_to_host(&"probe_started", {})
	if error != OK:
		api.fail("probe_start_message", error_string(error))

func _connected_peers() -> Array[int]:
	var peers: Array[int] = []
	for player: Dictionary in api.get_room_players():
		if player.connected:
			peers.append(player.peer_id)
	peers.sort()
	return peers

func _participating() -> bool:
	for player: Dictionary in api.get_players():
		if player.is_local and player.connected:
			return true
	return false

func _roster_changed() -> void:
	var peers: Array[int] = _connected_peers()
	var names: PackedStringArray = []
	var spectators: Array[Dictionary] = api.get_spectators()
	var roster: Array[Dictionary] = api.get_room_players()
	for index: int in roster.size():
		var player: Dictionary = roster[index]
		var watching: bool = spectators.any(func(member: Dictionary) -> bool: return member.player_id == player.player_id)
		var role: String = "观战" if watching else "参赛"
		names.append("%d. %s · %s" % [index + 1, player.name, role if player.connected else "已退出"])
	%Roster.text = "轮次 %s　参赛 %d　观战 %d\n%s" % [api.round_id, api.get_players().size(), api.get_spectators().size(), "　/　".join(names)]
	if (pending or passed) and peers != expected:
		_reject("在线名单发生变化，请重新运行通信检查")
	_update_buttons()

func _update_buttons() -> void:
	var running: bool = phase == Phase.RUNNING
	var peers: Array[int] = _connected_peers()
	run_button.disabled = not running or not api.is_host() or pending or not peers.all(func(peer: int) -> bool: return started.has(peer))
	action_button.disabled = not running or not _participating()
	parent_button.disabled = not running or not api.is_host() or parent_deadline != 0
	finish_button.disabled = not running or not api.is_host() or not passed or parent_deadline != 0

func run_checks() -> void:
	if run_button.disabled:
		return
	token += 1
	expected = _connected_peers()
	replies.clear()
	receipts.clear()
	excluded.clear()
	passed = false
	pending = true
	deadline = Time.get_ticks_msec() + 10000
	_update_buttons()
	_note("第 %d 次检查，等待端点 %s" % [token, expected])
	if not _sent(api.net.broadcast(&"challenge", {"token": token}), "广播"):
		return
	if expected.size() > 1:
		_sent(api.net.broadcast(&"excluded", {"token": token}, false), "排除本机广播")

func send_action() -> void:
	if not action_button.disabled:
		_sent(api.net.send_to_host(&"action", {}), "发送参赛操作")

func _message(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	var peer: int = sender.peer_id
	if topic == &"probe_started" and api.is_host():
		started[peer] = true
		_update_buttons()
		return
	if phase != Phase.RUNNING:
		return
	if topic == &"action" and api.is_host():
		if not _sender_participates(sender):
			_reject("观战者提交了参赛操作")
			return
		_note("收到参赛操作 · peer %d" % peer)
		return
	if not payload is Dictionary or not payload.get("token") is int:
		_reject("探针消息格式无效")
		return
	if topic in [&"challenge", &"excluded", &"receipt"]:
		if peer != 1 or (topic == &"excluded" and api.is_host()):
			_reject("控制消息来源或接收范围错误")
			return
		var response: Dictionary = {"token": payload.token}
		if topic == &"challenge":
			response.participant = _participating()
			_sent(api.net.send_to_host(&"reply", response), "上行回执")
		elif topic == &"receipt":
			_sent(api.net.send_to_host(&"receipt_ack", response), "定向流回执")
		else:
			_sent(api.net.send_to_host(&"excluded_ack", response), "广播回执")
		return
	if not api.is_host() or payload.token != token:
		return
	if not pending or peer not in expected:
		_reject("收到额外或未知端点的回执")
		return
	match topic:
		&"reply":
			if replies.has(peer) or not payload.get("participant") is bool or payload.participant != _sender_participates(sender):
				_reject("回执重复或参赛身份不匹配")
				return
			replies[peer] = payload.participant
			_note("peer %d 上行已达，参赛=%s" % [peer, payload.participant])
			if not _sent(api.net.send_to_peer(peer, &"receipt", {"token": token}), "定向流"):
				return
		&"receipt_ack":
			if receipts.has(peer) or not replies.has(peer):
				_reject("定向回执重复或顺序错误")
				return
			receipts[peer] = true
			_note("peer %d 定向回执已达" % peer)
		&"excluded_ack":
			if excluded.has(peer) or peer == 1:
				_reject("排除本机广播范围或次数错误")
				return
			excluded[peer] = true
		_:
			_reject("未知回执 " + str(topic))
			return
	if pending and receipts.size() == expected.size() and excluded.size() == expected.size() - 1:
		pending = false
		passed = true
		_note("通信检查通过" if expected.size() > 1 else "本机回环通过，远端与排除本机广播不适用")
		_update_buttons()

func _sender_participates(sender: Dictionary) -> bool:
	for player: Dictionary in api.get_players():
		if player.connected and player.player_id in sender.player_ids:
			return true
	return false

## Separate optional probe. The playlist answers using its actual active launch request.
func check_parent() -> void:
	if parent_button.disabled:
		return
	parent_nonce += 1
	parent_status = "等待回执"
	parent_deadline = Time.get_ticks_msec() + 5000
	_note("正在向父游戏查询本局请求")
	_update_buttons()
	var error: Error = api.net.send_to_parent(&"playlist/round_query", {"nonce": parent_nonce})
	if error != OK:
		_parent_result("发送失败：" + error_string(error))

func _parent_message(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if topic != &"playlist/round_info" or parent_deadline == 0:
		return
	if sender.peer_id != 1 or not payload is Dictionary or payload.get("nonce") != parent_nonce or payload.get("request_id") != request_id:
		_parent_result("父游戏回执不匹配")
		return
	_parent_result("通过")

func _parent_result(message: String) -> void:
	parent_deadline = 0
	parent_status = message
	_note("父子通信 · " + message)
	_update_buttons()

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if pending and now >= deadline:
		_reject("回执超时，已收到定向回执 %s，排除本机回执 %s" % [receipts.keys(), excluded.keys()])
	if parent_deadline != 0 and now >= parent_deadline:
		_parent_result("超时，未收到父游戏回执")

func finish_round() -> void:
	if finish_button.disabled:
		return
	var rows: Array[Dictionary] = []
	for player: Dictionary in api.get_players():
		rows.append({"player_id": player.player_id, "rank": 0, "status": "unranked" if player.connected else "withdrawn"})
	var result: Dictionary = {"request_id": request_id, "reason": "completed", "rankings": rows,
		"game_data": {"peers": expected, "receipts": receipts.size(), "parent": parent_status}}
	var error: Error = api.finish(result)
	if error != OK:
		_reject("结果未被接受：" + error_string(error))
		return
	phase = Phase.SUBMITTED
	_update_buttons()
	_note("候选已接受，等待父游戏正式提交")

func party_stop(_reason: StringName) -> void:
	record.stop += 1
	phase = Phase.STOPPED
	pending = false
	parent_deadline = 0
	if is_node_ready():
		delay_timer.stop()
	set_process(false)

func _closed() -> void:
	record.close += 1

func _exit_tree() -> void:
	if api != null:
		record.exit += 1

func _sent(error: Error, operation: String) -> bool:
	if error != OK:
		_reject(operation + "：" + error_string(error))
	return error == OK

func _reject(message: String) -> void:
	pending = false
	passed = false
	_note("失败 · " + message)
	_update_buttons()
	push_error(message)

func _note(message: String) -> void:
	log_view.add_text(message + "\n")
