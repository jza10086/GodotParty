## Hosts an existing single-player scene inside a standard one-participant round.
## Its completed signal carries final metrics. Spectators never instantiate the simulation.
extends Control
const Pages = preload("res://games/protocols/godot_party_default_protocol/round_pages.gd")
const Contract = preload("res://games/protocols/godot_party_default_protocol/protocol.gd")
const Store = preload("res://core/config/party_config_store.gd")
const REPORT: StringName = &"godot_party_default/solo_completed"
@export var gameplay: PackedScene
@export var columns: Array[Dictionary]
## Optional personal record. Times are stored in milliseconds, scores in points.
@export var record_metric: String = ""
var _record_path: String
var _best: int = -1
var _gameplay: Node
var pages: Pages
var api: PartyAPI
var request: Dictionary
var participant: String
var playing: bool = false

func party_setup(context: PartyAPI, config: Dictionary) -> void:
	api = context
	request = config.duplicate(true)
	participant = api.get_players()[0].player_id

func _ready() -> void:
	if api == null:
		push_error("请从小游戏轮换启动本局。")
		return
	if gameplay == null or columns.is_empty() or request.get("mode") != "standard":
		api.fail("solo_setup", "单人游戏缺少玩法场景或成绩列，或请求不是普通局。")
		return
	api.net.message_received.connect(_report)
	api.players_changed.connect(_players_changed)
	pages = Pages.new()
	var error: Error = pages.prepare(self, api, request, _play)
	if error != OK:
		api.fail("solo_ready", error_string(error))

func party_start() -> void:
	pages.transport_started()

func _play() -> void:
	playing = true
	var player: Dictionary = api.get_players()[0]
	if player.is_local and player.connected:
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
		_gameplay.connect(&"completed", _completed, CONNECT_ONE_SHOT)
		add_child(_gameplay)
	_players_changed()

func _completed(metrics: Dictionary) -> void:
	_gameplay.process_mode = Node.PROCESS_MODE_DISABLED
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

func _report(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if topic != REPORT or not api.is_host() or not playing:
		return
	var player: Dictionary = api.get_players()[0]
	if player.connected and player.peer_id == sender.peer_id and participant in sender.player_ids and payload is Dictionary:
		_settle("completed", payload)

func _players_changed() -> void:
	if playing and api.is_host() and not api.get_players()[0].connected:
		_settle("withdrawn", {})

func _settle(status: String, metrics: Dictionary) -> void:
	var result: Dictionary = {"request_id": request.request_id, "reason": "completed",
		"columns": columns, "rankings": [{"player_id": participant, "rank": 1 if status == "completed" else 0,
		"status": status, "metrics": metrics}]}
	var checked: Dictionary = Contract.new().validate_result(result, request, api.get_players())
	if not checked.ok:
		api.fail(checked.code, checked.message)
		return
	playing = false
	var error: Error = pages.present(result)
	if error != OK:
		api.fail("solo_result", error_string(error))

func party_stop(_reason: StringName) -> void:
	playing = false
