extends Control
## Shared standard-round transport/UI for the five original arcade games.
## Subclasses own gameplay, snapshots and ranking. No rewards or parent state live here.
const Pages = preload("res://games/protocols/godot_party_default_protocol/round_pages.gd")
var pages: Pages
var api: PartyAPI
var request: Dictionary = {}
var settings: Dictionary = {}
var players: Array[Dictionary] = []
var local_id: String = ""
var running: bool = false
var elapsed: float = 0.0
var clock: float = 0.0
var sequence: int = 0
var received_sequence: int = -1
var action_sequences: Dictionary = {}
var disconnected: Dictionary = {}
var view: Dictionary = {}
@onready var stage: Control = %Stage
@onready var sidebar: VBoxContainer = %Sidebar
@onready var heading: Label = %Heading
@onready var status: Label = %Status
const StandingRow: PackedScene = preload("res://games/protocols/godot_party_default_protocol/standing_row.tscn")
var _rows: Dictionary[String, Label] = {}
@onready var standings: VBoxContainer = %Standings
@onready var footer: Label = %Footer

func party_setup(value: PartyAPI, config: Dictionary) -> void:
	api = value
	request = config.duplicate(true)
	settings = api.get_settings()
	players = api.get_players()
	for player: Dictionary in players:
		if player.is_local:
			local_id = player.player_id
	api.net.message_received.connect(_message)
	api.players_changed.connect(_players_changed)

func _ready() -> void:
	if api == null:
		push_error("请从 GodotParty 大厅启动")
		return
	if request.get("mode") != "standard":
		api.fail("unsupported_mode", "只支持普通局")
		return
	status.text = "等待所有玩家就绪"
	build_game()
	pages = Pages.new()
	var ready_error: Error = pages.prepare(self, api, request, _start_gameplay)
	if ready_error != OK:
		api.fail("load_failed", error_string(ready_error))

## Entries keep the round roster order, including withdrawn players.
func update_standing(player_id: String, caption: String) -> void:
	if not _rows.has(player_id):
		var row: Label = StandingRow.instantiate()
		standings.add_child(row)
		_rows[player_id] = row
	if _rows[player_id].text != caption:
		_rows[player_id].text = caption

func player_name(id: String) -> String:
	for player: Dictionary in players:
		if player.player_id == id:
			return player.name
	return "观战者"

func player_color(id: String) -> Color:
	return Color(api.get_appearance(id).get("color", "#ffffff"))

func party_start() -> void:
	pages.transport_started()

func _start_gameplay() -> void:
	running = true
	start_game()
	if api.is_host():
		publish()

func party_stop(_reason: StringName) -> void:
	running = false
	set_process(false)
	set_physics_process(false)

func _process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	tick_game(delta)
	clock += delta
	if clock >= 0.1:
		clock = 0.0
		if api.is_host():
			publish()
		render_game()

func send_action(data: Dictionary) -> void:
	if not running or local_id.is_empty():
		return
	sequence += 1
	data = data.duplicate(true)
	data["seq"] = sequence
	api.net.send_to_host(&"action", data)

func _message(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if not running:
		return
	if topic == &"state" and int(sender.get("peer_id", 0)) == 1 and payload is Dictionary:
		var revision: int = int(payload.get("_sequence", -1))
		if revision <= received_sequence:
			return
		received_sequence = revision
		view = payload
		render_game()
	elif topic == &"private_view" and int(sender.get("peer_id", 0)) == 1 and payload is Dictionary:
		receive_private(payload)
	elif topic == &"action" and api.is_host() and payload is Dictionary:
		if not payload.get("seq") is int or payload.seq < 1:
			return
		for player: Dictionary in api.get_players():
			var id: String = player.player_id
			if player.connected and id in sender.get("player_ids", []) and not disconnected.has(id):
				if payload.seq <= int(action_sequences.get(id, 0)):
					return
				action_sequences[id] = payload.seq
				handle_action(id, payload)
				return

func publish() -> void:
	var snapshot: Dictionary = make_snapshot()
	snapshot["_sequence"] = int(snapshot.get("_sequence", 0)) + int(elapsed * 1000000)
	api.net.broadcast_stream(&"state", snapshot)

func _players_changed() -> void:
	if not api.is_host() or not running:
		return
	for player: Dictionary in api.get_players():
		if not player.connected and not disconnected.has(player.player_id):
			disconnected[player.player_id] = true
			player_left(player.player_id)

func finish_scores(scores: Dictionary, metrics: Dictionary = {}, columns: Array = []) -> void:
	if not running or not api.is_host():
		return
	var rows: Array = []
	for player: Dictionary in players:
		var id: String = player.player_id
		var rank_value: int = 1
		for other: Dictionary in players:
			if not disconnected.has(other.player_id) and float(scores.get(other.player_id, 0)) > float(scores.get(id, 0)):
				rank_value += 1
		var row_metrics: Dictionary = metrics.get(id, {"score": scores.get(id, 0)}).duplicate(true)
		rows.append({"player_id": id, "rank": 0 if disconnected.has(id) else rank_value, "status": "withdrawn" if disconnected.has(id) else "completed", "metrics": row_metrics})
	finish_rows(rows, columns)

func finish_rows(rows: Array, columns: Array = [], reason: String = "completed") -> void:
	if not running or not api.is_host():
		return
	running = false
	var result: Dictionary = {"request_id": request.request_id, "reason": reason, "rankings": rows, "columns": columns if not columns.is_empty() else [{"key": "score", "title": "积分", "format": "integer"}]}
	var error: Error = pages.present(result)
	if error != OK:
		api.fail("result_rejected", error_string(error))

func build_game() -> void:
	pass
func start_game() -> void:
	pass
func tick_game(_delta: float) -> void:
	pass
func make_snapshot() -> Dictionary:
	return {}
func render_game() -> void:
	pass
func handle_action(_id: String, _data: Dictionary) -> void:
	pass
func receive_private(_data: Dictionary) -> void:
	pass
func player_left(_id: String) -> void:
	pass
