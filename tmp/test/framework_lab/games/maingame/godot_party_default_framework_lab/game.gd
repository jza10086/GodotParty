extends Node
## Test parent: real durable state, pure round reduction, host-only foreground requests.
const MINI: String = "godot_party_default_framework_probe"
const BLANK: String = "godot_party_default_blank"
var api: PartyAPI
var state: Dictionary = {}
var active: bool = false
var busy: bool = false
var queued: bool = false
var committed_notifications: int = 0
var resumed: int = 0
var audit: Dictionary = {}
var _starts: Dictionary = {}
var _selection: Array[CheckBox] = []
var _summary: Label
var _notice_text: String = ""
var _probe_script: Script

func party_setup(value: PartyAPI, _settings: Dictionary) -> void:
	api = value
	api.state_committed.connect(_committed)
	api.round_committed.connect(_round_committed)
	api.round_cancelled.connect(_cancelled)
	api.commit_failed.connect(_commit_failed)
	api.net.child_message_received.connect(_child_message)
	_probe_script = api.load_asset({"package_id": MINI, "resource_key": "probe_script"}) as Script
	assert(_probe_script != null, "Required probe script is missing")

func _ready() -> void:
	_check(api.mark_ready(), "主游戏就绪")

func create_new_state(_settings: Dictionary) -> Dictionary:
	return {"remaining": 0, "attempt": 0, "participants": [], "game": MINI,
		"launch": {}, "history": [], "pause": ""}

func get_state() -> Dictionary:
	return state.duplicate(true)

func restore_state(value: Dictionary) -> void:
	state = value.duplicate(true)

## No IO, messages, rewards or counters outside the returned state.
func reduce_round_result(old_state: Dictionary, result: Dictionary) -> Dictionary:
	var next: Dictionary = old_state.duplicate(true)
	next.history.append(result.duplicate(true))
	next.remaining -= 1
	next.launch = {}
	return next

func party_start() -> void:
	active = true
	busy = false
	_queue_advance()

func party_suspend() -> void:
	active = false

func party_resume() -> void:
	resumed += 1
	party_start()

func party_stop(_reason: StringName) -> void:
	active = false
	set_process(false)

## Start exactly two real rounds; an empty UI selection is refused, not expanded to everyone.
func start_rounds(participants: Array[String], game_id: String = MINI) -> void:
	if not api.is_host() or not active or busy or state.remaining > 0:
		return
	if participants.is_empty():
		_notice("请至少选择一位参赛者。")
		return
	_notice_text = ""
	var next: Dictionary = state.duplicate(true)
	next.participants = participants.duplicate()
	next.game = game_id
	next.remaining = 2
	next.pause = ""
	_commit(next)

func _queue_advance() -> void:
	if not active or not api.is_host() or queued:
		return
	queued = true
	_advance.call_deferred()

func _advance() -> void:
	queued = false
	if not active or busy or state.remaining == 0 or not state.pause.is_empty():
		return
	if state.launch.is_empty():
		var next: Dictionary = state.duplicate(true)
		next.attempt += 1
		next.launch = {"request_id": api.session_id + "/lab/" + str(next.attempt), "mode": "standard"}
		_commit(next)
		return
	var participants: Array[String] = []
	participants.assign(state.participants)
	busy = true
	var error: Error = api.request_minigame(state.game, state.launch, participants)
	if error != OK:
		busy = false
		_pause("启动失败：" + error_string(error))

func _commit(next: Dictionary) -> void:
	busy = true
	if not _check(api.commit_state(next), "父状态提交"):
		busy = false

func _committed(_revision: int) -> void:
	busy = false
	_queue_advance()

func _round_committed(_round: String, _result: Dictionary) -> void:
	committed_notifications += 1

func _cancelled(_round: String, reason: String) -> void:
	busy = false
	if api.is_host():
		_pause("本轮取消：" + reason)

func _pause(reason: String) -> void:
	var next: Dictionary = state.duplicate(true)
	next.pause = reason
	next.remaining = 0
	next.launch = {}
	_commit(next)

func _commit_failed(code: String, message: String) -> void:
	_notice("保存失败，使用框架重试按钮：" + code + " / " + message)

func _child_message(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if topic != &"lab_started" or not payload is Dictionary or not payload.get("scope") is String:
		push_error("Invalid child probe message")
		return
	var scope: String = payload.scope
	if not _starts.has(scope):
		_starts[scope] = {}
	var peers: Dictionary = _starts[scope]
	if peers.has(sender.peer_id):
		push_error("Duplicate child start from peer " + str(sender.peer_id))
		return
	peers[sender.peer_id] = true
	var expected: int = 0
	for player: Dictionary in api.get_room_players():
		if player.connected:
			expected += 1
	if peers.size() == expected:
		_check(api.net.send_to_child(&"lab_parent_ack", {"scope": scope}), "父→子")

## Observe cleanup after queue_free, without retaining a Node or depending on old callbacks.
func _process(_delta: float) -> void:
	for scope: String in _probe_script.observations:
		if audit.has(scope):
			continue
		var observation: Dictionary = _probe_script.observations[scope]
		if observation.exit == 0 or observation.node.get_ref() != null:
			continue
		var closed_api: PartyAPI = observation.api
		var passed: bool = observation.setup == 1 and observation.ready == 1 and observation.start == 1 and observation.stop == 1 and observation.cleanup == 1 and observation.exit == 1 and observation.timer_stopped and observation.parent_reply and observation.failures == 0 and not closed_api.is_open()
		passed = passed and closed_api.net.send_to_host(&"stale_probe", {}) == ERR_UNAVAILABLE
		audit[scope] = passed
		if not passed:
			push_error("LAB cleanup failed: " + scope)
		print("LAB_AUDIT ", scope, " passed=", passed)
	if active and is_instance_valid(_summary):
		_summary.text = "已正式提交 %d 局 · 剩余 %d 局\n本端提交通知 %d · 视图恢复 %d\n本端旧作用域清理：%s\n%s" % [
			state.history.size(), state.remaining, committed_notifications, resumed, audit, state.pause + "\n" + _notice_text]

func create_view() -> Node:
	_selection.clear()
	var root: MarginContainer = MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + edge, 24)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	scroll.add_child(column)
	_label(column, "框架验证 · 基础闭环", 32)
	_label(column, "选择参赛者，其他人观战。可以取消勾选房主，验证房主观战时仍负责协调。", 22)
	for player: Dictionary in api.get_players():
		var box: CheckBox = CheckBox.new()
		box.text = player.name + (" · 房主" if player.peer_id == 1 else "")
		box.button_pressed = player.connected
		box.disabled = not api.is_host() or not player.connected
		box.set_meta("player_id", player.player_id)
		column.add_child(box)
		_selection.append(box)
	_button(column, "启动两轮测试小游戏", _selected_start.bind(MINI), not api.is_host())
	_button(column, "启动两轮空白模板（每轮由房主手动结束）", _selected_start.bind(BLANK), not api.is_host())
	_button(column, "查看最近一次正式成绩", _show_result, state.history.is_empty())
	_summary = _label(column, "", 22)
	_label(column, "测试小游戏：房主运行通信检查，实际收到各端回执后才能提交；提交成功自动进入第二轮。\n每端单独显示清理证据。单人不代表远端通信通过，视觉和真实多人操作仍需人工验收。", 20)
	return root

func _selected_start(id: String) -> void:
	var selected: Array[String] = []
	for box: CheckBox in _selection:
		if box.button_pressed and not box.disabled:
			selected.append(box.get_meta("player_id"))
	start_rounds(selected, id)

func _show_result() -> void:
	_check(api.show_results(api.get_round_presentation()), "显示成绩")

func _label(parent: Node, caption: String, size: int) -> Label:
	var label: Label = Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _button(parent: Node, caption: String, callback: Callable, disabled: bool) -> void:
	var button: Button = Button.new()
	button.text = caption
	button.disabled = disabled
	button.custom_minimum_size.y = 48
	button.pressed.connect(callback)
	parent.add_child(button)

func _notice(message: String) -> void:
	_notice_text = message
	if is_instance_valid(_summary):
		_summary.text = message
	push_error(message)

func _check(error: Error, operation: String) -> bool:
	if error == OK:
		return true
	_notice(operation + "：" + error_string(error))
	return false
