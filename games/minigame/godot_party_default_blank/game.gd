extends Control
## Self-contained example: load, confirm, play, present the local result, then finish once.
## Core readiness stays technical; the parent receives only the final standard result.
## 同一场景在编辑器、F6 画面预览与正式联机中实例化；调校资源在 graphics_lab.tscn 中编辑。
const NavigationDemo = preload("res://games/minigame/godot_party_default_blank/navigation_2d.gd")
const GraphicsLabView = preload("res://games/minigame/godot_party_default_blank/graphics_lab.gd")
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
@onready var _content: CenterContainer = $GameHUD/Content
@onready var _graphics: GraphicsLabView = %GraphicsLab
@onready var _navigation: NavigationDemo = %Navigation2D
@onready var _game_hud: CanvasLayer = $GameHUD
@onready var _details_3d: Control = $GameHUD/HUD
@onready var _switch: Button = %SwitchView
@onready var _pages: Control = %ProtocolPages

func party_setup(value: PartyAPI, config: Dictionary) -> void:
	api = value
	request = config.duplicate(true)
	$GameAudio.prepare_scope()
	api.net.message_received.connect(_message)

func godot_party_audio_target() -> PartyGameAudio:
	return $GameAudio

func _audio_input_allowed() -> bool:
	return api == null or (phase == Phase.RUNNING and not api.input.input_blocked)

func _ready() -> void:
	%AudioPanel.configure(%GameAudio, api, _audio_input_allowed)
	_graphics.orbit_camera.input_allowed = _camera_input_allowed
	_navigation.input_allowed = _controls_allowed
	# Keep both sample HUDs below the framework's session menu on canvas 0.
	_navigation.hud.layer = -3
	_switch.pressed.connect(_switch_view)
	_game_hud.visible = api == null
	if api == null:
		# F6 只预览画面；正式流程仍由大厅注入 API。
		_content.hide()
		%Status.text = "画面预览"
		%Controls.text = "滚轮缩放 · 中键拖动旋转\nShift＋中键平移"
		return
	_navigation.localize(api.i18n)
	_switch.text = api.i18n.text(&"game.show_2d")
	%Title.text = api.i18n.text(&"空白小游戏")
	%Status.text = api.i18n.text(&"game.hud_ready")
	%Controls.text = api.i18n.text(&"game.hud_controls")
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
	_pages.add_child(_cursors)
	var gate_script: Script = api.load_asset({"package_id": api.protocol_id, "resource_key": "briefing_gate"}) as Script
	if gate_script == null:
		api.fail("briefing_missing", "原版协议缺少加载场景。")
		return
	_briefing = gate_script.new()
	var content: Dictionary = gate_script.read_content(get_script().resource_path.get_base_dir().path_join("manifest.json"), api)
	content["controls"] = [{"binding": api.i18n.text(&"game.mouse"), "description": api.i18n.text(&"game.controls")}]
	_briefing.configure(api, content)
	_briefing.play_requested.connect(_begin_play)
	_pages.add_child(_briefing)
	await get_tree().process_frame
	if not api.is_open():
		return
	finish_button.pressed.connect(_press_finish)
	api.players_changed.connect(_try_settle)
	var error: Error = api.mark_ready()
	if error != OK:
		api.fail("load_failed", error_string(error))

func _switch_view() -> void:
	if not _controls_allowed():
		return
	var show_2d: bool = not _navigation.visible
	_navigation.visible = show_2d
	_graphics.visible = not show_2d
	_details_3d.visible = not show_2d
	if api == null:
		_switch.text = "查看 3D 展台" if show_2d else "查看 2D 航道"
	else:
		_switch.text = api.i18n.text(&"game.show_3d" if show_2d else &"game.show_2d")

func _camera_input_allowed() -> bool:
	return _graphics.visible and _controls_allowed()

func _controls_allowed() -> bool:
	return _audio_input_allowed() and not %AudioPanel.is_expanded()

func party_start() -> void:
	_briefing.transport_started()

func _begin_play() -> void:
	phase = Phase.RUNNING
	_game_hud.show()
	%Status.text = api.i18n.text(&"game.hud_playing")
	_content.show()
	_cursors.enabled = true
	_cursors.show()
	for player: Dictionary in api.get_players():
		if player.connected and player.is_local:
			finish_button.disabled = false
			break
	_try_settle()

func _press_finish() -> void:
	if phase != Phase.RUNNING or api.input.input_blocked or finish_button.disabled:
		return
	finish_button.disabled = true
	finish_button.text = api.i18n.text(&"game.waiting")
	%Status.text = api.i18n.text(&"game.waiting")
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
	%GameAudio.stop_all()
	phase = Phase.SETTLING
	_game_hud.hide()
	_navigation.hud.hide()
	_cursors.enabled = false
	_cursors.hide()
	finish_button.disabled = true
	_content.hide()
	_settlement = gate_script.new()
	_settlement.configure(api, {"title": api.i18n.text(&"game.results"), "rows": _result.rankings}, request.request_id)
	_settlement.continued.connect(_submit_result)
	_pages.add_child(_settlement)

## Every client mounted the result and the host's delay elapsed; only now submit once.
func _submit_result() -> void:
	if phase != Phase.SETTLING or not api.is_host():
		return
	phase = Phase.SUBMITTED
	var error: Error = api.finish(_result)
	if error != OK:
		api.fail("result_rejected", error_string(error))

func party_stop(_reason: StringName) -> void:
	$GameAudio.close_scope()
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
