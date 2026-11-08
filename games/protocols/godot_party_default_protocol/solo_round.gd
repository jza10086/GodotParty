extends Control
## One participant computes locally; the host validates and publishes the result.
## Gameplay is prepared before settings attach, and stopped explicitly before settlement.
const Briefing = preload("res://games/protocols/godot_party_default_protocol/briefing/briefing_gate.gd")
const Settlement = preload("res://games/protocols/godot_party_default_protocol/settlement/settlement_gate.gd")
const Contract = preload("res://games/protocols/godot_party_default_protocol/protocol.gd")
const GameAudio = preload("res://games/protocols/godot_party_default_protocol/audio/game_audio.gd")
const Store = preload("res://core/config/party_config_store.gd")
const REPORT: StringName = &"godot_party_default/solo_completed"
const RESULT: StringName = &"godot_party_default/round_result"
@export var gameplay: PackedScene
@export var columns: Array[Dictionary]
@export var record_metric: String = ""
var api: PartyAPI
var request: Dictionary
var participant: String
var playing: bool = false
var _gameplay: Node
var _briefing: Briefing
var _settlement: Settlement
var _record_path: String
var _best: int = -1
var _reported: bool = false
var _stopped: bool = false
var _host_result: Dictionary

func party_setup(context: PartyAPI, config: Dictionary) -> void:
	api = context
	request = config.duplicate(true)
	add_to_group("party_minimal_hud")
	var players: Array[Dictionary] = api.get_players()
	if gameplay == null or columns.is_empty() or request.get("mode") != "standard" or players.size() != 1:
		api.fail("solo_setup", "单人游戏需要玩法场景、成绩列和一位 standard 参赛者。")
		return
	participant = players[0].player_id
	if players[0].is_local and players[0].connected:
		if not record_metric.is_empty():
			_record_path = api.input.storage_directory().path_join("minigame").path_join(api.package_id).path_join("config/record.json")
			if FileAccess.file_exists(_record_path):
				var record: Dictionary = PartyAPI.Data.read_json(_record_path)
				if not record.get(record_metric) is int or record[record_metric] < 0:
					api.fail("record_invalid", "本机个人纪录无法读取或数值无效。")
					return
				_best = record[record_metric]
		_gameplay = gameplay.instantiate()
		if not record_metric.is_empty():
			_gameplay.personal_best = maxi(0, _best)
		_gameplay.solo_setup(api.input, api.i18n)
		_gameplay.connect(&"completed", _completed)
		add_child(_gameplay)
	api.net.message_received.connect(_message)
	api.players_changed.connect(_players_changed)
	api.on_close(party_stop.bind(&"scope_closed"))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if api == null:
		push_error("请从小游戏轮换启动本局；F6 预览请打开包内玩法场景。")
		return
	if _stopped or not api.is_open():
		return
	_briefing = Briefing.new()
	_briefing.configure(api, Briefing.read_content(scene_file_path.get_base_dir().path_join("manifest.json"), api))
	_briefing.play_requested.connect(_play, CONNECT_ONE_SHOT)
	add_child(_briefing)
	var error: Error = api.mark_ready()
	if error != OK:
		api.fail("solo_ready", error_string(error))

func party_start() -> void:
	if not _stopped:
		_briefing.transport_started()

func _play() -> void:
	if _stopped:
		return
	playing = true
	if _gameplay != null:
		_gameplay.solo_start()
	_players_changed()

## Empty/null explicitly means this peer has no 3D view/audio (2D or spectating).
func godot_party_graphics_targets() -> Dictionary:
	return _gameplay.solo_graphics_targets() if _gameplay != null else {}

func godot_party_audio_target() -> GameAudio:
	return _gameplay.solo_audio_target() if _gameplay != null else null

func _stop_gameplay() -> void:
	if _gameplay != null:
		_gameplay.solo_stop()

func _completed(metrics: Dictionary) -> void:
	if _stopped or not playing or _reported:
		return
	_reported = true
	_stop_gameplay()
	var checked: Dictionary = Contract.new().validate_result(_result("completed", metrics), request, api.get_players())
	if not checked.ok:
		api.fail(checked.code, checked.message)
		return
	if not record_metric.is_empty():
		var value: int = metrics[record_metric]
		if _best < 0 or (value < _best if record_metric == "time" else value > _best):
			var save_error: Error = Store.write_configs({_record_path: JSON.stringify({record_metric: value})})
			if save_error != OK:
				api.fail("record_write", error_string(save_error))
				return
	var error: Error = api.net.send_to_host(REPORT, metrics)
	if error != OK:
		api.fail("solo_report", error_string(error))

func _message(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if _stopped or not playing:
		return
	if topic == REPORT and api.is_host():
		var player: Dictionary = api.get_players()[0]
		if player.connected and player.peer_id == sender.peer_id and participant in sender.player_ids and payload is Dictionary:
			_settle("completed", payload)
	elif topic == RESULT and not api.is_host() and sender.peer_id == 1:
		if not payload is Dictionary or not Contract.new().validate_result(payload, request, api.get_players()).ok:
			api.fail("invalid_result_page", "房主发送的结算数据无效。")
			return
		_show_result(payload)

func _players_changed() -> void:
	if playing and not _stopped and api.is_host() and not api.get_players()[0].connected:
		_settle("withdrawn", {})

func _result(status: String, metrics: Dictionary) -> Dictionary:
	return {"request_id": request.request_id, "reason": "completed", "columns": columns,
		"rankings": [{"player_id": participant, "rank": 1 if status == "completed" else 0,
		"status": status, "metrics": metrics}]}

func _settle(status: String, metrics: Dictionary) -> void:
	var result: Dictionary = _result(status, metrics)
	var checked: Dictionary = Contract.new().validate_result(result, request, api.get_players())
	if not checked.ok:
		api.fail(checked.code, checked.message)
		return
	_host_result = result
	var error: Error = api.net.broadcast(RESULT, result)
	if error != OK:
		api.fail("solo_result", error_string(error))
		return
	_show_result(result)

func _show_result(result: Dictionary) -> void:
	playing = false
	_stop_gameplay()
	_briefing.stop()
	_settlement = Settlement.new()
	_settlement.configure(api, {"title": api.i18n.text(&"solo.result_title", {}, api.protocol_id),
		"rows": result.rankings, "columns": result.columns}, request.request_id)
	if api.is_host():
		_settlement.continued.connect(_submit, CONNECT_ONE_SHOT)
	add_child(_settlement)

func _submit() -> void:
	var error: Error = api.finish(_host_result)
	if error != OK:
		api.fail("result_rejected", error_string(error))

func party_stop(_reason: StringName) -> void:
	if _stopped:
		return
	_stopped = true
	playing = false
	_stop_gameplay()
	if _briefing != null:
		_briefing.stop()
	if _settlement != null:
		_settlement.stop()
	if _gameplay != null and _gameplay.is_connected(&"completed", _completed):
		_gameplay.disconnect(&"completed", _completed)
	if api != null:
		if api.net.message_received.is_connected(_message):
			api.net.message_received.disconnect(_message)
		if api.players_changed.is_connected(_players_changed):
			api.players_changed.disconnect(_players_changed)
