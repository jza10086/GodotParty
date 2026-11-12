## Optional default-protocol pregame presentation, not a framework lifecycle.
## Games explicitly mount this helper and keep their simulation stopped until play_requested.
## mark_ready remains technical readiness. A separate authenticated, scope-bound message
## records each participating human's confirmation; spectators only pass the technical barrier.
extends Control

signal play_requested()

const TOPIC: StringName = &"godot_party_default/briefing"
@export_range(0.0, 10.0, 0.1) var countdown_seconds: float = 3.0
var api: PartyAPI
@export var view: Control
var _content: Dictionary = {}
var _ready_ids: Dictionary = {}
var _transport_started: bool = false
var _closed: bool = false
var _released: bool = false
var _hello_sent: bool = false
var _request_pending: bool = false
var _requested_ready: bool = false
var _stage: String = "waiting"
var _remaining: float = -1.0
var _revision: int = 0
var _received_revision: int = -1
var _refresh_in: float = 0.0
var _end_msec: int = -1
var _notice: String = ""
var _choice_options: Array[String] = []
var _choices: Dictionary[String, String] = {}
var _local_choice: String = ""

## The game supplies its content; the protocol owns no game-ID table or catalog access.
static func read_content(manifest_path: String, context: PartyAPI) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not value is Dictionary:
		push_error("Invalid briefing metadata: " + manifest_path)
		return {}
	var metadata: Dictionary = value
	var result: Dictionary = {"title": metadata.get("name", ""),
		"introduction": metadata.get("introduction", ""), "controls": [],
		"actions": metadata.get("controls", {}).duplicate(true)}
	var relative: String = str(metadata.get("cover", ""))
	if not relative.is_empty():
		result["cover"] = load(manifest_path.get_base_dir().path_join(relative)) as Texture2D
	for action: String in result.actions:
		result.controls.append({"binding": context.input.binding_text(StringName(action)),
			"description": result.actions[action]})
	return result

## Activate this scene once per round. The owner still calls mark_ready explicitly.
func configure(context: PartyAPI, content: Dictionary) -> void:
	api = context
	_content = content.duplicate(true)
	_choice_options.assign(content.get("choice_options", []))
	if not _choice_options.is_empty():
		_local_choice = content.choice_default
		assert(_local_choice in _choice_options, "Briefing default choice must be in its options")
		for player: Dictionary in api.get_players():
			_choices[player.player_id] = _local_choice
	api.net.message_received.connect(_message)
	api.players_changed.connect(_players_changed)
	api.on_close(stop)
	if is_node_ready():
		_activate()

func _ready() -> void:
	assert(view != null, "Assign the page's presentation view in its scene")
	if api != null:
		_activate()

func _activate() -> void:
	show()
	view.configure(_content)
	view.ready_requested.connect(func() -> void: set_ready(not _ready_ids.has(_local_id())))
	view.choice_selected.connect(select_choice)
	_refresh()

func update_content(content: Dictionary) -> void:
	_content = content.duplicate(true)
	if is_instance_valid(view):
		view.configure(_content)

## party_start proves the existing technical barrier passed, not that humans confirmed.
func transport_started() -> void:
	if _closed:
		return
	_transport_started = true
	if _stage == "play":
		_release()
	elif api.is_host():
		_maybe_countdown()
		_publish()
	_refresh()

## Set manual readiness before play. Canceling also stops the shared countdown.
func set_ready(ready: bool) -> Error:
	if _closed or _released or _request_pending or not _can_ready() or ready == _ready_ids.has(_local_id()):
		return ERR_UNAVAILABLE
	_request_pending = true
	_requested_ready = ready
	_notice = ""
	var payload: Dictionary = _envelope("ready")
	payload.ready = ready
	if not _choice_options.is_empty():
		payload.choice = _local_choice
	var error: Error = api.net.send_to_host(TOPIC, payload)
	if error != OK:
		_request_pending = false
		_notice = "准备消息发送失败，请重试：" + error_string(error)
	_refresh()
	return error

## Optional single player choice, frozen by the same authoritative confirmation as readiness.
func select_choice(value: String) -> Error:
	if _closed or _released or _request_pending or not _can_ready() or _ready_ids.has(_local_id()) or value not in _choice_options:
		return ERR_UNAVAILABLE
	_local_choice = value
	var payload: Dictionary = _envelope("choice")
	payload.choice = value
	var error: Error = api.net.send_to_host(TOPIC, payload)
	if error != OK:
		_local_choice = _choices[_local_id()]
		_notice = "选项发送失败：" + error_string(error)
	_refresh()
	return error

## Only participants have choices; spectators return empty text.
func get_choice(player_id: String) -> String:
	return _choices.get(player_id, "")

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

func _process(delta: float) -> void:
	if _closed or _released or api == null or not api.is_open():
		return
	if _stage == "countdown":
		_remaining = maxf(0.0, float(_end_msec - api.net.host_time_msec()) / 1000.0)
		if api.is_host() and _remaining == 0.0:
			if _all_confirmed():
				_stage = "play"
				_publish()
			else:
				_stage = "waiting"
				_remaining = -1.0
				_publish()
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = 0.1
		_refresh()

func _envelope(kind: String) -> Dictionary:
	return {"session": api.session_id, "scope": api.scope_id, "phase": "briefing", "kind": kind}

func _message(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if _closed or _released or topic != TOPIC or not payload is Dictionary:
		return
	if payload.get("session") != api.session_id or payload.get("scope") != api.scope_id or payload.get("phase") != "briefing":
		return
	if payload.get("kind") == "state":
		if int(sender.get("peer_id", 0)) != 1 or not _valid_state(payload):
			return
		_received_revision = payload.revision
		if not _choice_options.is_empty():
			_choices.assign(payload.choices)
		_ready_ids.clear()
		for id: String in payload.ready:
			_ready_ids[id] = true
		_stage = payload.stage
		_end_msec = payload.end_msec
		_remaining = maxf(0.0, float(_end_msec - api.net.host_time_msec()) / 1000.0) if _stage == "countdown" else -1.0
		if _request_pending and _ready_ids.has(_local_id()) == _requested_ready:
			_request_pending = false
		if _stage == "play" and _transport_started:
			_release()
		_refresh()
		return
	if not api.is_host():
		return
	if payload.get("kind") == "hello":
		_publish()
	elif payload.get("kind") in ["ready", "choice"] and _stage in ["waiting", "countdown"]:
		var readiness: bool = payload.kind == "ready"
		if readiness and not payload.get("ready") is bool:
			return
		var cancel: bool = readiness and not payload.ready
		if _stage == "countdown" and not cancel:
			return
		if not cancel and not _choice_options.is_empty() and (not payload.get("choice") is String or payload.choice not in _choice_options):
			return
		if not readiness and _choice_options.is_empty():
			return
		var preparation: Dictionary = api.get_preparation_status()
		if int(sender.get("peer_id", 0)) not in preparation.get("ready_peers", []):
			return
		for player: Dictionary in api.get_players():
			if player.connected and player.peer_id == sender.get("peer_id") and player.player_id in sender.get("player_ids", []):
				if cancel:
					_ready_ids.erase(player.player_id)
				elif not _ready_ids.has(player.player_id):
					if not _choice_options.is_empty():
						_choices[player.player_id] = payload.choice
					if readiness:
						_ready_ids[player.player_id] = true
		if _stage == "countdown" and not _all_confirmed():
			_stage = "waiting"
			_remaining = -1.0
			_end_msec = -1
		_maybe_countdown()
		_publish()

func _valid_state(payload: Dictionary) -> bool:
	if not payload.get("revision") is int or payload.revision <= _received_revision:
		return false
	if payload.get("stage") not in ["waiting", "countdown", "play"] or not payload.get("ready") is Array:
		return false
	if payload.ready.size() > 8 or not payload.get("end_msec") is int or payload.end_msec < -1:
		return false
	var participants: Dictionary = {}
	for player: Dictionary in api.get_players():
		participants[player.player_id] = true
	if not _choice_options.is_empty():
		if not payload.get("choices") is Dictionary or payload.choices.size() != participants.size():
			return false
		for id: String in participants:
			if not payload.choices.get(id) is String or payload.choices[id] not in _choice_options:
				return false
	for id: Variant in payload.ready:
		if not id is String or not participants.has(id):
			return false
	return true

func _publish() -> void:
	if not api.is_host() or _closed:
		return
	_revision += 1
	var payload: Dictionary = _envelope("state")
	payload.merge({"revision": _revision, "ready": _ready_ids.keys(), "stage": _stage, "end_msec": _end_msec})
	if not _choice_options.is_empty():
		payload.choices = _choices.duplicate()
	var error: Error = api.net.broadcast(TOPIC, payload)
	if error != OK:
		stop()
		api.fail("briefing_send_failed", error_string(error))

func _all_confirmed() -> bool:
	if not _transport_started:
		return false
	var count: int = 0
	for player: Dictionary in api.get_players():
		if player.connected:
			count += 1
			if not _ready_ids.has(player.player_id):
				return false
	return count > 0

func _maybe_countdown() -> void:
	if _stage != "waiting" or not _all_confirmed():
		return
	_stage = "countdown"
	_remaining = countdown_seconds
	_end_msec = api.net.host_time_msec() + roundi(countdown_seconds * 1000.0)

func _players_changed() -> void:
	if _closed or _released:
		return
	if api.is_host():
		for player: Dictionary in api.get_players():
			if not player.connected:
				_ready_ids.erase(player.player_id)
		_maybe_countdown()
		_publish()
	_refresh()

func _local_id() -> String:
	for player: Dictionary in api.get_room_players():
		if player.is_local:
			return player.player_id
	return ""

func _can_ready() -> bool:
	if _stage != "waiting" and not (_stage == "countdown" and _ready_ids.has(_local_id())):
		return false
	var preparation: Dictionary = api.get_preparation_status()
	for player: Dictionary in api.get_players():
		if player.is_local and player.connected:
			return player.peer_id in preparation.get("ready_peers", [])
	return false

func _refresh() -> void:
	if _closed or _released or not is_instance_valid(view):
		return
	var preparation: Dictionary = api.get_preparation_status()
	var participant_ids: Dictionary = {}
	for player: Dictionary in api.get_players():
		participant_ids[player.player_id] = true
	var rows: Array[Dictionary] = []
	var local_loaded: bool = false
	for player: Dictionary in api.get_room_players():
		var row: Dictionary = player.duplicate(true)
		row["participant"] = participant_ids.has(player.player_id)
		row["loaded"] = player.peer_id in preparation.get("ready_peers", [])
		row["ready"] = _ready_ids.has(player.player_id)
		row["choice"] = get_choice(player.player_id)
		row["color"] = Color(api.get_appearance(player.player_id).get("color", "#b8b6ac"))
		rows.append(row)
		if player.is_local:
			local_loaded = row.loaded
	if local_loaded and not _hello_sent:
		_hello_sent = true
		if api.net.send_to_host(TOPIC, _envelope("hello")) != OK:
			_hello_sent = false
	var status: String = _notice
	if status.is_empty():
		if _stage == "countdown" or _stage == "play":
			status = "所有参赛玩家已准备，即将开始" if _remaining > 0.0 else "等待房主开始指令…"
		elif _request_pending:
			status = "正在确认准备状态…"
		elif _ready_ids.has(_local_id()):
			status = "你已准备 · 等待其他玩家"
		elif not participant_ids.has(_local_id()):
			status = "你正在观战 · 无需准备，加载完成后随本局开始"
		elif not local_loaded:
			status = "正在加载资源、应用设置并校验规则…"
		else:
			status = "阅读规则后，按提示键准备就绪"
	var actions: Dictionary = _content.get("actions", {})
	if not actions.is_empty():
		var controls: Array[Dictionary] = []
		for action: String in actions:
			controls.append({"binding": api.input.binding_text(StringName(action)), "description": actions[action]})
		if controls != _content.get("controls", []):
			_content["controls"] = controls
			view.configure(_content)
	view.set_choice(_local_choice)
	view.set_state(rows, _can_ready() and not _request_pending, _ready_ids.has(_local_id()),
		ceili(_remaining) if _stage in ["countdown", "play"] else -1, status)

func _release() -> void:
	if _released or _closed:
		return
	_released = true
	hide()
	set_process(false)
	play_requested.emit()
