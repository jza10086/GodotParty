extends Control
## Minimal standard round. The framework owns readiness, authority and durable publication.
enum Phase { PREPARING, RUNNING, SUBMITTED, STOPPED }
var api: PartyAPI
var request: Dictionary
var phase: Phase = Phase.PREPARING
@onready var status: Label = %Status
@onready var players: Label = %Players
@onready var finish_button: Button = %Finish

func party_setup(value: PartyAPI, config: Dictionary) -> void:
	api = value
	request = config.duplicate(true)

func _ready() -> void:
	if api == null:
		push_error("请从 GodotParty 大厅启动空白小游戏。")
		return
	finish_button.pressed.connect(finish_round)
	api.players_changed.connect(_refresh_players)
	_refresh_players()
	var error: Error = api.mark_ready()
	if error != OK:
		status.text = "就绪失败：" + error_string(error)
		push_error(status.text)

func party_start() -> void:
	phase = Phase.RUNNING
	status.text = "运行中 · " + ("房主" if api.is_host() else "客户端")
	finish_button.disabled = not api.is_host()

## OK accepts this candidate; the parent observes the eventual durable commit.
func finish_round() -> void:
	if phase != Phase.RUNNING or not api.is_host():
		return
	var rows: Array[Dictionary] = []
	for player: Dictionary in api.get_players():
		rows.append({"player_id": player.player_id, "rank": 0,
			"status": "unranked" if player.connected else "withdrawn"})
	var error: Error = api.finish({"request_id": request.request_id,
		"reason": "completed", "rankings": rows})
	if error != OK:
		status.text = "结果未被接受：" + error_string(error)
		push_error(status.text)
		return
	phase = Phase.SUBMITTED
	finish_button.disabled = true
	status.text = "结果已接受，等待框架提交"

func party_stop(_reason: StringName) -> void:
	phase = Phase.STOPPED
	set_process(false)
	if is_node_ready():
		finish_button.disabled = true

func _refresh_players() -> void:
	var lines: PackedStringArray = []
	for player: Dictionary in api.get_players():
		lines.append("%s · %s%s" % [player.name, "在线" if player.connected else "已退出",
			" · 本机" if player.is_local else ""])
	lines.append("观战人数：%d" % api.get_spectators().size())
	players.text = "\n".join(lines)
