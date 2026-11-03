extends Control
## Self-contained example: load, confirm, play, present the local result, then finish once.
## Core readiness stays technical; the parent receives only the final standard result.
enum Phase { PREPARING, RUNNING, SETTLING, SUBMITTED, STOPPED }
const PRESS_TOPIC: StringName = &"blank/press"
const RESULT_TOPIC: StringName = &"blank/result"
var api: PartyAPI
var request: Dictionary
var phase: Phase = Phase.PREPARING
var _briefing: Control
var _settlement: Control
var _cursors: Control
var _result: Dictionary = {}
var _press_order: Array[String] = []
@onready var finish_button: Button = %Finish
@onready var _content: CenterContainer = $Content

func party_setup(value: PartyAPI, config: Dictionary) -> void:
	api = value
	request = config.duplicate(true)
	api.net.message_received.connect(_message)

func _ready() -> void:
	if api == null:
		push_error("请从 GodotParty 大厅启动空白小游戏。")
		return
	finish_button.text = api.i18n.text(&"game.finish")
	finish_button.tooltip_text = api.i18n.text(&"game.settings_hint") + "\n" + api.i18n.text(&"game.locale", {"locale": api.i18n.effective_locale()})
	_content.hide()
	var cursor_scene: PackedScene = api.load_asset({"package_id": api.protocol_id, "resource_key": "player_cursors"}) as PackedScene
	if cursor_scene == null:
		api.fail("cursors_missing", "原版协议缺少玩家鼠标场景。")
		return
	_cursors = cursor_scene.instantiate()
	_cursors.setup(api)
	_cursors.enabled = false
	_cursors.hide()
	add_child(_cursors)
	var gate_script: Script = api.load_asset({"package_id": api.protocol_id, "resource_key": "briefing_gate"}) as Script
	if gate_script == null:
		api.fail("briefing_missing", "原版协议缺少加载场景。")
		return
	_briefing = gate_script.new()
	var content: Dictionary = gate_script.read_content(get_script().resource_path.get_base_dir().path_join("manifest.json"), api)
	content["controls"] = [{"binding": api.i18n.text(&"game.mouse"), "description": api.i18n.text(&"game.controls")}]
	_briefing.configure(api, content)
	_briefing.play_requested.connect(_begin_play)
	add_child(_briefing)
	await get_tree().process_frame
	if not api.is_open():
		return
	finish_button.pressed.connect(_press_finish)
	api.players_changed.connect(_try_settle)
	var error: Error = api.mark_ready()
	if error != OK:
		api.fail("load_failed", error_string(error))

func party_start() -> void:
	_briefing.transport_started()

func _begin_play() -> void:
	phase = Phase.RUNNING
	_content.show()
	_cursors.enabled = true
	_cursors.show()
	for player: Dictionary in api.get_players():
		if player.connected and player.is_local:
			finish_button.disabled = false
			break
	_try_settle()

func _press_finish() -> void:
	if phase != Phase.RUNNING or finish_button.disabled:
		return
	finish_button.disabled = true
	finish_button.text = api.i18n.text(&"game.waiting")
	var error: Error = api.net.send_to_host(PRESS_TOPIC, {})
	if error != OK:
		api.fail("press_send_failed", error_string(error))

## The host derives identity from the sender and records the first press in receipt order.
func _record_press(sender: Dictionary) -> void:
	for player: Dictionary in api.get_players():
		if player.connected and player.peer_id == sender.peer_id and player.player_id in sender.player_ids:
			if player.player_id not in _press_order:
				_press_order.append(player.player_id)
				_try_settle()
			return

func _try_settle() -> void:
	if phase != Phase.RUNNING or not api.is_host():
		return
	var roster: Array[Dictionary] = api.get_players()
	for player: Dictionary in roster:
		if not player.connected:
			_press_order.erase(player.player_id)
		elif player.player_id not in _press_order:
			return
	var rows: Array[Dictionary] = []
	for player: Dictionary in roster:
		var place: int = _press_order.find(player.player_id) + 1
		var score: int = _press_order.size() - place + 1 if place > 0 else 0
		rows.append({"player_id": player.player_id, "rank": place,
			"status": "completed" if player.connected else "withdrawn", "metrics": {"score": score}})
	var result: Dictionary = {"request_id": request.request_id, "reason": "completed",
		"rankings": rows, "columns": [{"key": "score", "title": "分数", "format": "integer"}]}
	_open_settlement(result)
	if phase != Phase.SETTLING:
		return
	var error: Error = api.net.broadcast(RESULT_TOPIC, {"session": api.session_id,
		"scope": api.scope_id, "result": result})
	if error != OK:
		api.fail("result_send_failed", error_string(error))

func _message(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if phase != Phase.RUNNING:
		return
	if topic == PRESS_TOPIC:
		if api.is_host() and payload is Dictionary and payload.is_empty():
			_record_press(sender)
		return
	if topic != RESULT_TOPIC or sender.get("peer_id") != 1 or not payload is Dictionary:
		return
	if payload.get("session") != api.session_id or payload.get("scope") != api.scope_id or not payload.get("result") is Dictionary:
		return
	var contract_script: Script = api.load_asset({"package_id": api.protocol_id, "resource_key": "contract"}) as Script
	if contract_script == null:
		api.fail("contract_missing", "原版协议缺少结果契约。")
		return
	var checked: Dictionary = contract_script.new().validate_result(payload.result, request, api.get_players())
	if not checked.ok:
		api.fail(checked.code, checked.message)
		return
	_open_settlement(payload.result)

func _open_settlement(result: Dictionary) -> void:
	if phase != Phase.RUNNING:
		return
	var gate_script: Script = api.load_asset({"package_id": api.protocol_id, "resource_key": "settlement_gate"}) as Script
	if gate_script == null:
		api.fail("settlement_missing", "原版协议缺少结算场景。")
		return
	_result = result.duplicate(true)
	phase = Phase.SETTLING
	_cursors.enabled = false
	_cursors.hide()
	finish_button.disabled = true
	_content.hide()
	_settlement = gate_script.new()
	_settlement.configure(api, {"title": api.i18n.text(&"game.results"), "rows": _result.rankings}, request.request_id)
	_settlement.continued.connect(_submit_result)
	add_child(_settlement)

## Every client mounted the result and the host's delay elapsed; only now submit once.
func _submit_result() -> void:
	if phase != Phase.SETTLING or not api.is_host():
		return
	phase = Phase.SUBMITTED
	var error: Error = api.finish(_result)
	if error != OK:
		api.fail("result_rejected", error_string(error))

func party_stop(_reason: StringName) -> void:
	if is_instance_valid(_cursors):
		_cursors.enabled = false
		_cursors.hide()
	if is_instance_valid(_briefing):
		_briefing.stop()
	if is_instance_valid(_settlement):
		_settlement.stop()
	if api != null and api.net.message_received.is_connected(_message):
		api.net.message_received.disconnect(_message)
	if api.players_changed.is_connected(_try_settle):
		api.players_changed.disconnect(_try_settle)
	phase = Phase.STOPPED
	set_process(false)
	if is_node_ready():
		finish_button.disabled = true
