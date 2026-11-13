extends Control

## Content-owned gameplay rules, independent of package compatibility.
static func party_definition() -> Dictionary:
	return {"player_counts": [1, 2, 3, 4, 5, 6, 7, 8]}

## Formal entry: protocol readiness, authoritative press order and final publication.
## DemoHub owns editable demonstrations, input presentation and local audio controls.
const DemoHub: GDScript = preload("examples/demo_hub.gd")
const RandomPool: GDScript = preload("res://games/protocols/godot_party_default_protocol/random/least_played_pool.gd")
const DRAW_TOPIC: StringName = &"blank/draw"
var _random_pool: RandomPool = RandomPool.new(DemoHub.RANDOM_DEMOS)
enum Phase { PREPARING, RUNNING, SETTLING, SUBMITTED, STOPPED }
const PRESS_TOPIC: StringName = &"blank/press"
const RESULT_TOPIC: StringName = &"blank/result"
var api: PartyAPI
var request: Dictionary
var phase: Phase = Phase.PREPARING
@export var briefing: Control
@export var settlement: Control
var _cursors: Control
var _result: Dictionary = {}
var _press_order: Array[String] = []
@onready var _demo: DemoHub = %DemoHub
@onready var _pages: CanvasLayer = %ProtocolPages

func party_setup(value: PartyAPI, config: Dictionary) -> void:
	api = value
	request = config.duplicate(true)
	%DemoHub.configure(api.i18n, api.config, _input_allowed)
	api.net.message_received.connect(_message)

func godot_party_audio_target() -> PartyGameAudio:
	return %DemoHub.audio_target()

func godot_party_graphics_targets() -> Dictionary:
	return %DemoHub.graphics_targets()

func _input_allowed() -> bool:
	return phase == Phase.RUNNING and not api.input.input_blocked

func _demo_failed(error: Error) -> void:
	api.fail("audio_settings_failed", error_string(error))

func _ready() -> void:
	if api == null:
		return
	# Resolve the package path from the formal API; F6 never reaches this branch.
	var stats_path: String = api.input.storage_directory().path_join(
		"minigame/%s/config/random_pool_stats.json" % api.package_id)
	var storage_error: Error = _random_pool.open_file(stats_path)
	if storage_error != OK:
		_random_failed(storage_error)
		return
	_demo.finish_requested.connect(_press_finish)
	_demo.failed.connect(_demo_failed)
	var cursor_scene: PackedScene = preload("res://games/assets/godot_party_default_ui/player_cursors.tscn")
	if cursor_scene == null:
		api.fail("cursors_missing", "原版协议缺少玩家鼠标场景。")
		return
	_cursors = cursor_scene.instantiate()
	_cursors.setup(api)
	_cursors.enabled = false
	_cursors.hide()
	_pages.add_child(_cursors)
	var content: Dictionary = briefing.read_content(get_script().resource_path.get_base_dir().path_join("manifest.json"), api)
	content["controls"] = [{"binding": api.i18n.text(&"game.mouse"), "description": api.i18n.text(&"game.controls")}]
	briefing.configure(api, content)
	briefing.play_requested.connect(_begin_play)
	await get_tree().process_frame
	if not api.is_open():
		return
	api.players_changed.connect(_try_settle)
	var error: Error = api.mark_ready()
	if error != OK:
		api.fail("load_failed", error_string(error))

func party_start() -> void:
	briefing.transport_started()

func _begin_play() -> void:
	phase = Phase.RUNNING
	if api.is_host():
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = api.get_seed()
		var chosen: Array[String] = [_random_pool.choose(rng)]
		var error: Error = _random_pool.accept_history(chosen)
		if error != OK:
			_random_failed(error)
			return
		error = api.net.broadcast(DRAW_TOPIC, {"session": api.session_id,
			"scope": api.scope_id, "draws": _random_pool.history()}, MultiplayerPeer.TRANSFER_MODE_RELIABLE, false)
		if error != OK:
			_random_failed(error)
			return
	if not _random_pool.history().is_empty():
		_activate_demo()

func _activate_demo() -> void:
	_demo.show_demo(_random_pool.history()[0])
	_cursors.enabled = true
	_cursors.show()
	var can_finish: bool = false
	for player: Dictionary in api.get_players():
		if player.connected and player.is_local:
			can_finish = true
			break
	_demo.begin_play(can_finish)
	_try_settle()

func _press_finish() -> void:
	if phase != Phase.RUNNING or api.input.input_blocked or _demo.finish_button.disabled:
		return
	_demo.wait_for_players()
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
	if topic == DRAW_TOPIC:
		if phase in [Phase.PREPARING, Phase.RUNNING]:
			_receive_draw(sender, payload)
		return
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
	var contract_script: Script = api.load_asset({"package_id": api.protocol_id, "resource_path": "protocol.gd"}) as Script
	if contract_script == null:
		api.fail("contract_missing", "原版协议缺少结果契约。")
		return
	var checked: Dictionary = contract_script.new().validate_result(payload.result, request, api.get_players())
	if not checked.ok:
		api.fail(checked.code, checked.message)
		return
	_open_settlement(payload.result)

## Sender/session/scope and this example's one-draw limit are entry boundaries.
## The pool separately validates IDs, sequence consistency and persistence.
func _receive_draw(sender: Dictionary, payload: Variant) -> void:
	if api.is_host() or sender.get("peer_id") != 1 or not payload is Dictionary:
		return
	if payload.get("session") != api.session_id or payload.get("scope") != api.scope_id:
		return
	if not payload.get("draws") is Array or payload.draws.size() != 1:
		_random_failed(ERR_INVALID_DATA)
		return
	var first_draw: bool = _random_pool.history().is_empty()
	var error: Error = _random_pool.accept_history(payload.draws)
	if error != OK:
		_random_failed(error)
		return
	if first_draw and phase == Phase.RUNNING:
		_activate_demo()

func _random_failed(error: Error) -> void:
	party_stop(&"random_pool_failed")
	var report_error: Error = api.fail("random_pool_failed", error_string(error))
	if report_error != OK:
		push_error("Random pool: %s; reporting failed: %s" % [error_string(error), error_string(report_error)])

func _open_settlement(result: Dictionary) -> void:
	if phase != Phase.RUNNING:
		return
	_result = result.duplicate(true)
	phase = Phase.SETTLING
	_demo.stop_demo()
	_cursors.enabled = false
	_cursors.hide()
	settlement.configure(api, {"title": api.i18n.text(&"game.results"), "rows": _result.rankings}, request.request_id)
	settlement.continued.connect(_submit_result)

## Every client mounted the result and the host's delay elapsed; only now submit once.
func _submit_result() -> void:
	if phase != Phase.SETTLING or not api.is_host():
		return
	phase = Phase.SUBMITTED
	var error: Error = api.finish(_result)
	if error != OK:
		api.fail("result_rejected", error_string(error))

func party_stop(_reason: StringName) -> void:
	%DemoHub.audio_target().close_scope()
	if is_instance_valid(_cursors):
		_cursors.enabled = false
		_cursors.hide()
	if is_instance_valid(briefing):
		briefing.stop()
	if is_instance_valid(settlement):
		settlement.stop()
	if api != null and api.net.message_received.is_connected(_message):
		api.net.message_received.disconnect(_message)
	if api.players_changed.is_connected(_try_settle):
		api.players_changed.disconnect(_try_settle)
	phase = Phase.STOPPED
	if is_node_ready():
		_demo.stop_demo()
