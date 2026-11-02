## Optional result presentation barrier owned by the calling game.
## Acknowledgements mean the result is mounted, never a human click.
## This helper neither submits results nor changes scores or the owner's lifecycle.
extends Control

signal continued()

const View: PackedScene = preload("settlement_view.tscn")
const TOPIC: StringName = &"godot_party_default/settlement"
@export_range(0.0, 10.0, 0.1) var countdown_seconds: float = 3.0
var api: PartyAPI
var view: Control
var token: String
var _presentation: Dictionary = {}
var _ready_peers: Dictionary = {}
var _stage: String = "waiting"
var _remaining: float = -1.0
var _revision: int = 0
var _received_revision: int = -1
var _mounted: bool = false
var _closed: bool = false
var _released: bool = false
var _retry_in: float = 0.0
var _last_count: int = -1

## The owner supplies its authoritative result and a stable per-result request ID before insertion.
## It chooses whether to present before finish() or after a durable parent commit.
func configure(context: PartyAPI, presentation: Dictionary, result_token: String) -> void:
	api = context
	token = result_token
	_presentation = presentation.duplicate(true)
	api.net.message_received.connect(_message)
	api.players_changed.connect(_players_changed)
	api.on_close(stop)

func _ready() -> void:
	if api == null or token.is_empty():
		push_error("Settlement requires an injected API and result token")
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	view = View.instantiate()
	add_child(view)
	view.configure(_presentation, api.get_room_players())
	view.set_countdown(-1.0)
	await get_tree().process_frame
	if _closed or not api.is_open():
		return
	_mounted = true
	_send_ready()

func _envelope(kind: String) -> Dictionary:
	return {"session": api.session_id, "scope": api.scope_id, "token": token, "kind": kind}

func _send_ready() -> void:
	_retry_in = 0.5
	var error: Error = api.net.send_to_host(TOPIC, _envelope("ready"))
	if error != OK:
		api.fail("settlement_send_failed", error_string(error))

func _process(delta: float) -> void:
	if _closed or _released or not _mounted or not api.is_open():
		return
	_retry_in -= delta
	if not _ready_peers.has(_local_peer()) and _retry_in <= 0.0:
		_send_ready()
	if _stage == "countdown":
		_remaining = maxf(0.0, _remaining - delta)
		if api.is_host() and _remaining == 0.0:
			if _all_ready():
				_stage = "continue"
				_publish()
			else:
				_stage = "waiting"
				_remaining = -1.0
				_publish()
		elif api.is_host() and ceili(_remaining) != _last_count:
			_publish()
	if is_instance_valid(view):
		view.set_countdown(_remaining)

func _message(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if _closed or _released or topic != TOPIC or not payload is Dictionary:
		return
	if payload.get("session") != api.session_id or payload.get("scope") != api.scope_id or payload.get("token") != token:
		return
	if payload.get("kind") == "state":
		if sender.get("peer_id") != 1 or not _valid_state(payload):
			return
		_received_revision = payload.revision
		_ready_peers.clear()
		for peer: int in payload.ready:
			_ready_peers[peer] = true
		_stage = payload.stage
		_remaining = float(payload.remaining)
		if is_instance_valid(view):
			view.set_countdown(_remaining)
		if _stage == "continue":
			_release()
	elif api.is_host() and payload.get("kind") == "ready":
		var peer: int = int(sender.get("peer_id", 0))
		for player: Dictionary in api.get_room_players():
			if player.connected and player.peer_id == peer and player.player_id in sender.get("player_ids", []):
				_ready_peers[peer] = true
				_maybe_countdown()
				_publish()
				return

func _valid_state(payload: Dictionary) -> bool:
	if not payload.get("revision") is int or payload.revision <= _received_revision:
		return false
	if payload.get("stage") not in ["waiting", "countdown", "continue"] or not payload.get("ready") is Array:
		return false
	if payload.ready.size() > 8 or not (payload.get("remaining") is int or payload.get("remaining") is float):
		return false
	if not is_finite(float(payload.remaining)) or float(payload.remaining) < -1.0 or float(payload.remaining) > 10.0:
		return false
	var known: Dictionary = {}
	for player: Dictionary in api.get_room_players():
		known[player.peer_id] = true
	for peer: Variant in payload.ready:
		if not peer is int or not known.has(peer):
			return false
	return true

func _all_ready() -> bool:
	var count: int = 0
	for player: Dictionary in api.get_room_players():
		if player.connected:
			count += 1
			if not _ready_peers.has(player.peer_id):
				return false
	return _mounted and count > 0

func _local_peer() -> int:
	for player: Dictionary in api.get_room_players():
		if player.is_local:
			return player.peer_id
	return 0

func _maybe_countdown() -> void:
	if _stage == "waiting" and _all_ready():
		_stage = "countdown"
		_remaining = countdown_seconds

func _publish() -> void:
	_revision += 1
	_last_count = ceili(_remaining)
	var payload: Dictionary = _envelope("state")
	payload.merge({"revision": _revision, "ready": _ready_peers.keys(), "stage": _stage, "remaining": _remaining})
	if api.net.broadcast(TOPIC, payload) != OK:
		api.fail("settlement_send_failed", "无法同步结算页面")

func _players_changed() -> void:
	if _closed or _released or not api.is_host():
		return
	var connected: Dictionary = {}
	for player: Dictionary in api.get_room_players():
		if player.connected:
			connected[player.peer_id] = true
	for peer: int in _ready_peers.keys():
		if not connected.has(peer):
			_ready_peers.erase(peer)
	if _stage == "countdown" and not _all_ready():
		_stage = "waiting"
		_remaining = -1.0
	_maybe_countdown()
	_publish()

func _release() -> void:
	if _released or _closed:
		return
	_released = true
	set_process(false)
	continued.emit()

func stop() -> void:
	if _closed:
		return
	_closed = true
	set_process(false)
	hide()
	if api != null:
		if api.net.message_received.is_connected(_message):
			api.net.message_received.disconnect(_message)
		if api.players_changed.is_connected(_players_changed):
			api.players_changed.disconnect(_players_changed)

func _exit_tree() -> void:
	stop()
