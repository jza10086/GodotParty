## Default-protocol preparation and result pages for a single standard round.
## The minigame owns its start callback and the original result; only ranking data is public.
extends Control

const Briefing = preload("res://games/protocols/godot_party_default_protocol/briefing/briefing_gate.gd")
const Settlement = preload("res://games/protocols/godot_party_default_protocol/settlement/settlement_gate.gd")
const Contract = preload("res://games/protocols/godot_party_default_protocol/protocol.gd")
const RESULT_TOPIC: StringName = &"godot_party_default/round_result"

var api: PartyAPI
var briefing: Briefing
var settlement: Settlement
var _request: Dictionary
var _host_result: Dictionary
var _hud_layers: Array[CanvasLayer] = []
var _previous_mode: Node.ProcessMode

func prepare(game: Node, context: PartyAPI, request: Dictionary, start_play: Callable) -> Error:
	api = context
	_request = request.duplicate(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hide_hud_layers(game)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_previous_mode = game.process_mode
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.add_child(self)
	briefing = Briefing.new()
	var manifest_path: String = game.scene_file_path.get_base_dir().path_join("manifest.json")
	briefing.configure(api, Briefing.read_content(manifest_path, api))
	briefing.play_requested.connect(func() -> void:
		for hud: CanvasLayer in _hud_layers:
			hud.show()
		_hud_layers.clear()
		game.process_mode = _previous_mode
		start_play.call(), CONNECT_ONE_SHOT)
	add_child(briefing)
	api.net.message_received.connect(_message)
	api.on_close(stop)
	return api.mark_ready()

func transport_started() -> void:
	briefing.transport_started()

## Freeze the original result on the host. Never broadcast private game_data or rewards.
func present(result: Dictionary) -> Error:
	if not api.is_host() or settlement != null:
		return ERR_UNAVAILABLE
	_host_result = result.duplicate(true)
	var public_result: Dictionary = {"request_id": result.request_id, "rankings": result.rankings,
		"columns": result.get("columns", []), "reason": result.reason}
	var error: Error = api.net.broadcast(RESULT_TOPIC, public_result)
	if error == OK:
		_show_result(public_result)
	return error

func _message(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if topic != RESULT_TOPIC or sender.peer_id != 1 or api.is_host() or settlement != null:
		return
	if not payload is Dictionary or not Contract.new().validate_result(payload, _request, api.get_players()).ok:
		api.fail("invalid_result_page", "房主发送的结算数据无效。")
		return
	_show_result(payload)

func _show_result(result: Dictionary) -> void:
	_hide_hud_layers(get_parent())
	get_parent().move_child(self, -1)
	get_parent().process_mode = Node.PROCESS_MODE_DISABLED
	settlement = Settlement.new()
	settlement.configure(api, {"title": "本轮取消" if result.reason == "cancelled" else "本轮结算",
		"rows": result.rankings, "columns": result.columns}, result.request_id)
	if api.is_host():
		settlement.continued.connect(_submit, CONNECT_ONE_SHOT)
	add_child(settlement)

## A game's CanvasLayer HUD would otherwise draw above both this page and host dialogs.
func _hide_hud_layers(game: Node) -> void:
	for hud: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		if hud.visible:
			_hud_layers.append(hud)
			hud.hide()

func _submit() -> void:
	var error: Error = api.finish(_host_result)
	if error != OK:
		api.fail("result_rejected", error_string(error))

func stop() -> void:
	briefing.stop()
	if settlement != null:
		settlement.stop()
	if api.net.message_received.is_connected(_message):
		api.net.message_received.disconnect(_message)
