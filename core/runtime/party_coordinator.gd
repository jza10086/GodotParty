## The only game lifecycle runner. Owns scope barriers and durable host publication.
extends Node

const Data = preload("res://core/runtime/party_data.gd")
const Rules = preload("res://core/config/party_room_rules.gd")
const ConfigStore = preload("res://core/config/party_config_store.gd")
const Config = preload("res://core/api/party_config.gd")
const Effects = preload("res://core/runtime/party_settings_scope.gd")
const Voice = preload("res://core/network/party_voice_backend.gd")
const VoiceAPI = preload("res://core/api/party_voice.gd")
const API = preload("res://core/api/party_api.gd")
const Store = preload("res://core/runtime/party_store.gd")
signal changed()
signal failed(message: String)
signal finished(presentation: Dictionary)
signal presentation_requested(presentation: Dictionary)
var connection: Node
var catalog: RefCounted
var voice_backend: Node
var _lobby_effects: RefCounted
var _lobby_api: PartyAPI
var config_store: RefCounted
var settings: PartyInput
var store: RefCounted
var record: Dictionary = {}
var standings: Dictionary = {}
var phase: String = "idle"
var loading: Dictionary = {}
var _scopes: Dictionary = {}
var _main_id: String = ""
var _child_id: String = ""
var _pending: Dictionary = {}
var _deferred_finish: Dictionary = {}
var _ready_peers: Dictionary = {}
var _expected: Array[int] = []
var _deadline: int = 0
var _received: Dictionary = {}
var _sent: Dictionary = {}
var _mouse_mode: int
var _saved_focus: WeakRef
var _restoring: bool = false
var _applied_revision: int = 0

func configure(link: Node, content_catalog: RefCounted, local_settings: PartyInput) -> void:
	connection = link
	catalog = content_catalog
	settings = local_settings
	config_store = ConfigStore.new(settings.storage_directory(), catalog)
	store = Store.new(settings.storage_directory().path_join("core/saves"))
	connection.control_received.connect(_control)
	connection.control_sending.connect(_before_control)
	connection.packet_received.connect(_packet)
	connection.disconnected.connect(_withdraw)
	connection.changed.connect(_connection_changed)
	connection.stats_changed.connect(_network_stats_changed)
	voice_backend = Voice.new()
	add_child(voice_backend)
	voice_backend.initialize(connection, settings)

func begin() -> Error:
	if phase != "idle" or not connection.host or not connection.start_reason().is_empty():
		return ERR_UNAVAILABLE
	_close_lobby_settings()
	_mouse_mode = Input.mouse_mode
	_saved_focus = weakref(get_viewport().gui_get_focus_owner())
	_restoring = not connection.recovery.is_empty()
	if _restoring:
		record = connection.recovery.duplicate(true)
		record["main_scope"] = Data.token()
		_main_id = record["main_scope"]
		connection.room["phase"] = "loading"
		connection._publish()
		return connection.control("install", {"record": record, "restoring": true})
	_main_id = Data.token()
	record = {"revision": 0, "save_id": Data.token(), "main_scope": _main_id, "state": {}, "rounds": [], "room": connection.room.duplicate(true), "players": connection.players.duplicate(true), "appearances": {}, "status": "active", "seed": randi()}
	record["main_rules"] = Rules.snapshot(record.room, record.room.main, catalog)
	for player: Dictionary in connection.players:
		record["appearances"][player["player_id"]] = player["appearance"].duplicate(true)
	var scope: Dictionary = _create_scope(_main_id, record["room"]["main"], "", _ids(connection.players), {}, record["room"]["settings"])
	if scope.is_empty():
		return ERR_CANT_CREATE
	_scopes[_main_id] = scope
	var state: Variant = scope["root"].create_new_state(record["room"]["settings"].duplicate(true))
	if not state is Dictionary or not Data.valid(state):
		cleanup("invalid_initial_state")
		return ERR_INVALID_DATA
	var error: Error = _queue_commit({"kind": "initial", "record": _next_record(state)})
	if error != OK:
		cleanup("initial_state_too_large")
		return error
	connection.room["phase"] = "loading"
	connection._publish()
	return OK

func _create_scope(id: String, package_id: String, round: String, participants: Array, request: Dictionary, config: Dictionary, seed_value: int = 0) -> Dictionary:
	var packed: Resource = catalog.load_entry(package_id)
	if not packed is PackedScene:
		failed.emit("入口不是场景：" + package_id)
		return {}
	var root: Node = packed.instantiate()
	var hooks: Array[String] = ["party_setup", "party_start", "party_stop"]
	if round.is_empty():
		hooks.append_array(["create_new_state", "get_state", "restore_state", "create_view", "reduce_round_result", "party_suspend", "party_resume"])
	for hook: String in hooks:
		if not root.has_method(hook):
			root.free()
			failed.emit("缺少入口函数：" + package_id + "." + hook)
			return {}
	root.name = "Scope_" + id
	var protocol_id: String = catalog.get_package(record["room"]["main"])["protocol"]["id"]
	var context: Dictionary = {"session_id": connection.session_id, "scope_id": id, "round_id": round, "package_id": package_id, "protocol_id": protocol_id, "is_host": connection.host, "settings": config, "pools": record["room"]["pools"], "child_settings": record["room"]["children"], "seed": record.get("seed", 0) if round.is_empty() else seed_value}
	var api: PartyAPI = API.new(context, _dispatch, _query)
	api.i18n = catalog.i18n.scope(package_id)
	var input_context: PartyInput = settings.create_context()
	input_context.input_blocked = true
	var local: Dictionary = _peer(connection.local_peer())
	input_context.spectator = local.get("player_id", "") not in participants
	api.config = Config.new()
	if api.config.initialize(config_store, package_id, protocol_id, record["main_rules"] if round.is_empty() else Rules.snapshot(record["room"], package_id, catalog)) != OK:
		failed.emit(api.config.last_error)
		api._begin_close()
		api._cleanup()
		root.free()
		return {}
	api.input = input_context

	api.net._native_api = multiplayer
	api.net._root = root
	var scope: Dictionary = {"id": id, "package": package_id, "round": round, "participants": participants.duplicate(), "request": request.duplicate(true), "api": api, "root": root, "phase": "preparing", "accepted": "", "view": null, "stopped": false, "ready_requested": false, "mouse_mode": Input.mouse_mode}
	# Register before setup, including its callbacks; setup is intentionally off-tree.
	_scopes[id] = scope
	if not _activate_effects(scope):
		_close_scope(id, "settings_failed")
		return {}
	root.party_setup(api, config.duplicate(true) if round.is_empty() else request.duplicate(true))
	if not api.is_open():
		root.free()
		_scopes.erase(id)
		return {}
	add_child(root)
	if not round.is_empty() and not scope.effects.attach(root):
		_close_scope(id, "settings_attach_failed")
		return {}
	return scope

func _query(scope_id: String, key: String, argument: Dictionary) -> Variant:
	if key == "peer_stats":
		return connection.get_peer_stats(argument.peer_id)
	if key == "host_time":
		return connection.network_clock.now_msec()
	if key == "clock_ready":
		return connection.network_clock.is_ready()
	if key == "game_name":
		return catalog.get_package(argument.id)["name"]
	if key == "child_settings":
		return record.get("room", {}).get("children", {})
	var scope: Dictionary = _scopes.get(scope_id, {})
	if scope.is_empty():
		return null
	if key == "preparation_status":
		return {"session_id": connection.session_id, "scope_id": scope_id,
			"phase": scope["phase"], "required_peers": scope.get("preparation_peers", []).duplicate(),
			"ready_peers": scope.get("prepared_peers", []).duplicate()}
	if key == "round_presentation":
		return record.get("round_presentation", {}).duplicate(true)
	if key == "asset":
		return catalog.asset(argument, record["room"]["closure"])
	if key == "external_path":
		return catalog.external_path(scope.package, argument.path)
	if key == "appearances":
		return record.get("appearances", {}).duplicate(true)
	var result: Array[Dictionary] = []
	for source: Dictionary in connection.players:
		var participant: bool = source["player_id"] in scope["participants"]
		if key == "players" and not participant or key == "spectators" and participant:
			continue
		var player: Dictionary = source.duplicate(true)
		player["is_local"] = source["peer_id"] == connection.local_peer()
		result.append(player)
	return result

func _dispatch(id: String, operation: String, payload: Dictionary) -> Error:
	var scope: Dictionary = _scopes.get(id, {})
	if scope.is_empty() or scope["phase"] == "closed":
		return ERR_UNAVAILABLE
	if operation == "show_results":
		if not Data.presentation(payload["presentation"], connection.players):
			return ERR_INVALID_PARAMETER
		presentation_requested.emit(payload["presentation"].duplicate(true))
		return OK
	if operation == "message":
		return _send_message(scope, payload)
	if operation == "fail":
		return connection.control("failure", {"scope": id, "reason": payload["code"] + ": " + payload["message"]}, 1)
	if operation == "ready":
		if scope["phase"] != "preparing":
			return ERR_UNAVAILABLE
		scope["ready_requested"] = true
		_report_ready.call_deferred(id)
		return OK
	if not connection.host:
		return ERR_UNAUTHORIZED
	if operation == "finish":
		return _finish(scope, payload["result"])
	if id != _main_id or phase != "main" or not _pending.is_empty():
		return ERR_BUSY
	match operation:
		"request":
			return _request(payload)
		"commit":
			return _queue_commit({"kind": "state", "record": _next_record(payload["state"])})
		"end":
			if not Data.presentation(payload["presentation"], connection.players):
				return ERR_INVALID_PARAMETER
			var next: Dictionary = _next_record(record["state"])
			next["status"] = "finished"
			next["presentation"] = payload["presentation"].duplicate(true)
			return _queue_commit({"kind": "end", "record": next})
		"standings":
			if not Data.presentation(payload["presentation"], connection.players):
				return ERR_INVALID_PARAMETER
			if not connection.control_fits("standings", payload):
				return ERR_INVALID_DATA
			return connection.control("standings", payload)
	return ERR_INVALID_PARAMETER

func _next_record(state: Dictionary) -> Dictionary:
	var next: Dictionary = record.duplicate(true)
	next["revision"] = record.get("revision", 0) + 1
	next["state"] = state.duplicate(true)
	return next

func _request(payload: Dictionary) -> Error:
	var id: String = payload["id"]
	var selected: bool = false
	for pool: Array in record["room"]["pools"].values():
		if id in pool:
			selected = true
	if not selected:
		return ERR_UNAUTHORIZED
	var main: Dictionary = catalog.get_package(record["room"]["main"])
	var adapter: Dictionary = catalog.adapter(id, main["protocol"]["id"])
	if adapter.is_empty():
		return ERR_UNCONFIGURED
	var participants: Array = payload["participants"].duplicate()
	if participants.is_empty():
		for player: Dictionary in connection.players:
			if player["connected"]:
				participants.append(player["player_id"])
	var unique: Dictionary = {}
	for member: Variant in participants:
		var player: Dictionary = Data.player(connection.players, str(member))
		if player.is_empty() or not player["connected"] or unique.has(member):
			return ERR_INVALID_PARAMETER
		unique[member] = true
	# The main game's limit applies to the room, not a foreground participant subset.
	var counts: Array[int] = connection.PlayerCounts.game_counts(record["room"], id, catalog)
	if participants.size() not in counts:
		failed.emit("小游戏参赛人数不符：允许 " + connection.PlayerCounts.describe(counts))
		return ERR_INVALID_PARAMETER
	var protocol: RefCounted = connection.protocol_instance()
	var players: Array[Dictionary] = _participants(participants)
	var report: Dictionary = protocol.validate_request(payload["request"].duplicate(true), players)
	if not report.get("ok", false):
		failed.emit(report.get("message", "Invalid request"))
		return ERR_INVALID_PARAMETER
	var implementation: RefCounted = _adapter_instance(id, adapter)
	if implementation != null and implementation.has_method("check_request"):
		report = implementation.check_request(payload["request"].duplicate(true))
		if not report.get("ok", false):
			failed.emit(report.get("message", "Unsupported request"))
			return ERR_INVALID_PARAMETER
	var config: Variant = implementation.make_config(payload["request"].duplicate(true)) if implementation != null else payload["request"].duplicate(true)
	if not config is Dictionary or not Data.valid(config):
		return ERR_INVALID_PARAMETER
	var round: String = Data.token()
	var message: Dictionary = {"id": id, "scope": round, "participants": participants, "request": payload["request"], "config": config, "seed": randi(), "rules": Rules.snapshot(record["room"], id, catalog)}
	if not connection.control_fits("child", message):
		return ERR_INVALID_DATA
	phase = "requesting"
	return connection.control("child", message)

func _adapter_instance(id: String, adapter: Dictionary) -> RefCounted:
	if not adapter.has("entry"):
		return null
	var script: Script = load(catalog.path(id, adapter["entry"]))
	return script.new()

func _finish(scope: Dictionary, raw: Dictionary) -> Error:
	if scope["id"] != _child_id:
		return ERR_UNAVAILABLE
	var digest: String = Data.digest(raw)
	if _pending.get("kind") == "rules" and scope.phase == "playing":
		if not _deferred_finish.is_empty():
			return OK if _deferred_finish.digest == digest else ERR_ALREADY_IN_USE
		_deferred_finish = {"scope": scope.id, "raw": raw.duplicate(true), "digest": digest}
		return OK
	if not scope["accepted"].is_empty():
		return OK if scope["accepted"] == digest else ERR_ALREADY_IN_USE
	if scope["phase"] != "playing" or phase != "child":
		return ERR_UNAVAILABLE
	var protocol: RefCounted = connection.protocol_instance()
	var adapter: RefCounted = scope.get("adapter")
	var result: Variant = adapter.map_result(raw.duplicate(true), scope["original_request"].duplicate(true)) if adapter != null else raw.duplicate(true)
	if not result is Dictionary or not Data.valid(result):
		return ERR_INVALID_PARAMETER
	var report: Dictionary = protocol.validate_result(result.duplicate(true), scope["original_request"].duplicate(true), _participants(scope["participants"]))
	if not report.get("ok", false):
		failed.emit(report.get("message", "Invalid round result"))
		return ERR_INVALID_PARAMETER
	var main: Dictionary = _scopes[_main_id]
	var next_state: Variant = main["root"].reduce_round_result(record["state"].duplicate(true), result.duplicate(true))
	if not next_state is Dictionary or not Data.valid(next_state):
		return ERR_INVALID_DATA
	var next: Dictionary = _next_record(next_state)
	if scope["round"] in next["rounds"]:
		return ERR_ALREADY_EXISTS
	next["rounds"].append(scope["round"])
	next["round_presentation"] = {}
	if protocol.has_method("present_result"):
		var presentation: Variant = protocol.present_result(result.duplicate(true), scope["original_request"].duplicate(true))
		if not presentation is Dictionary or not Data.valid(presentation) or not Data.presentation(presentation, _participants(scope["participants"])):
			failed.emit("协议成绩展示结构无效，结果尚未提交")
			return ERR_INVALID_DATA
		next["round_presentation"] = presentation.duplicate(true)
	var error: Error = _queue_commit({"kind": "round", "record": next, "round": scope["round"], "result": result})
	if error == OK:
		scope["accepted"] = digest
	return error

## Both publication and future restore must fit before the candidate can become durable.
func _queue_commit(candidate: Dictionary) -> Error:
	var install: Dictionary = {"record": candidate["record"], "restoring": false}
	if not connection.control_fits("install", install) or not connection.control_fits("committed", candidate):
		failed.emit("状态和结果超出单次提交上限（含信封 1 MiB），尚未保存")
		return ERR_INVALID_DATA
	_pending = candidate
	phase = "committing"
	_persist.call_deferred()
	return OK

func retry_commit() -> Error:
	if not connection.host or _pending.is_empty():
		return ERR_UNAVAILABLE
	_persist.call_deferred()
	return OK

func _persist() -> void:
	if _pending.is_empty() or not connection.host:
		return
	var candidate: Dictionary = _pending
	var error: Error = store.commit(candidate["record"]["save_id"], candidate["record"])
	if error != OK:
		var message: String = "保存失败，结果尚未提交：" + error_string(error) + " · " + store.last_error
		push_error(message)
		if _scopes.has(_main_id):
			_scopes[_main_id]["api"].commit_failed.emit("SAVE_FAILED", message)
		failed.emit(message)
		changed.emit()
		return
	record = candidate["record"].duplicate(true)
	_pending = {}
	if candidate["kind"] == "initial":
		connection.control("install", {"record": record, "restoring": false})
	else:
		connection.control("committed", candidate)

func _control(sender: int, kind: String, payload: Dictionary) -> void:
	if not _valid_control(kind, payload):
		if connection.host and sender != 1:
			connection.multiplayer.disconnect_peer(sender)
		else:
			connection.leave("框架控制消息格式无效：" + kind)
		return
	if kind == "ready" and connection.host:
		if not loading.is_empty() and payload.scope == loading.scope and sender in _expected and payload.rules == _scopes[loading.scope].api.config._rules.get("id"):
			_ready_peers[sender] = true
			if connection.control("readiness", {"scope": loading["scope"], "peers": _ready_peers.keys()}) != OK:
				return
			if _ready_peers.size() == _expected.size():
				connection.control("start", {"scope": loading["scope"]})
		return
	if kind == "failure" and connection.host:
		if not payload.scope.is_empty() and payload.scope in [_main_id, _child_id] and not _peer(sender).is_empty():
			if not _child_id.is_empty():
				cancel_round(payload.get("reason", "Load failed"))
			else:
				connection.control("abort", {"reason": payload.get("reason", "")})
		return
	if sender != 1:
		return
	match kind:
		"install":
			_install(payload)
		"child":
			_enter_child(payload)
		"readiness":
			if not loading.is_empty() and payload.scope == loading.scope:
				loading["ready"] = payload.get("peers", []).duplicate()
				_scopes[loading.scope]["prepared_peers"] = loading["ready"].duplicate()
				changed.emit()
		"start":
			_start_scope(payload.get("scope", ""))
		"committed":
			_apply_commit(payload)
		"cancel":
			_restore_parent(payload.get("reason", "Cancelled"))
		"standings":
			if Data.presentation(payload.get("presentation", {}), connection.players):
				standings = payload["presentation"].duplicate(true)
				changed.emit()
		"abort":
			cleanup(payload.get("reason", "Session stopped"))
			failed.emit(payload.get("reason", ""))
			if connection.host:
				connection.return_to_lobby()

func _install(payload: Dictionary) -> void:
	record = payload["record"].duplicate(true)
	_applied_revision = record["revision"]
	_main_id = record["main_scope"]
	_restoring = payload.get("restoring", false)
	if not _scopes.has(_main_id):
		_mouse_mode = Input.mouse_mode
		_saved_focus = weakref(get_viewport().gui_get_focus_owner())
		_create_scope(_main_id, record["room"]["main"], "", _ids(connection.players), {}, record["room"]["settings"])
	if not _scopes.has(_main_id):
		connection.control("failure", {"scope": _main_id, "reason": "Main game load failed"}, 1)
		return
	var scope: Dictionary = _scopes[_main_id]
	scope["root"].restore_state(record["state"].duplicate(true))
	_begin_barrier(scope)
	if not _create_view(scope):
		connection.control("failure", {"scope": _main_id, "reason": "Main view creation failed"}, 1)
		return

func _create_view(scope: Dictionary) -> bool:
	var view: Variant = scope["root"].create_view()
	if not view is Node or view.get_parent() != null:
		return false
	view.name = "View"
	scope["view"] = view
	scope["root"].add_child(view)
	if view is Control:
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.offset_left = 40
		view.offset_top = 220
		view.offset_right = -40
		view.offset_bottom = -40
	return scope.effects.attach(view)

func _enter_child(payload: Dictionary) -> void:
	if not payload.get("rules") is Dictionary or not Rules.validate_snapshot(payload.rules, record["room"], payload.get("id", ""), catalog):
		connection.control("failure", {"scope": payload.get("scope", ""), "reason": "规则快照不匹配"}, 1)
		return
	if not _scopes.has(_main_id) or not _child_id.is_empty():
		return
	var main: Dictionary = _scopes[_main_id]
	main["phase"] = "suspended"
	main["api"].input.input_blocked = true
	main["api"].config._active = false
	voice_backend.deactivate()
	main["root"].party_suspend()
	main.effects.leave()
	_release_view(main)
	_child_id = payload["scope"]
	var settings_value: Dictionary = record["room"]["children"].get(payload["id"], {})
	var scope: Dictionary = _create_scope(_child_id, payload["id"], _child_id, payload["participants"], payload["config"], settings_value, payload["seed"])
	if scope.is_empty():
		connection.control("failure", {"scope": _child_id, "reason": "Minigame load failed"}, 1)
		return
	scope["rules"] = payload.rules.duplicate(true)
	scope["original_request"] = payload["request"].duplicate(true)
	scope["api"]._context["seed"] = payload["seed"]
	scope["adapter"] = _adapter_instance(payload["id"], catalog.adapter(payload["id"], scope["api"].protocol_id))
	_begin_barrier(scope)

func _begin_barrier(scope: Dictionary) -> void:
	phase = "loading"
	_ready_peers.clear()
	_expected.clear()
	for player: Dictionary in connection.players:
		if player["connected"]:
			_expected.append(player["peer_id"])
	scope["preparation_peers"] = _expected.duplicate()
	scope["prepared_peers"] = []
	loading = {"scope": scope["id"], "package": scope["package"], "ready": []}
	_deadline = Time.get_ticks_msec() + 30000
	if scope["ready_requested"]:
		_report_ready.call_deferred(scope["id"])
	changed.emit()

func _report_ready(id: String) -> void:
	if id == loading.get("scope") and _scopes.has(id) and _scopes[id]["phase"] == "preparing" and _scopes[id].effects.ready and connection.network_clock.is_ready():
		connection.control("ready", {"scope": id, "rules": _scopes[id].api.config._rules.get("id")}, 1)

func _start_scope(id: String) -> void:
	if id != loading.get("scope") or not _scopes.has(id):
		return
	var scope: Dictionary = _scopes[id]
	if scope["phase"] != "preparing":
		return
	scope["phase"] = "playing"
	# The start packet confirms all required endpoints passed the technical barrier.
	scope["prepared_peers"] = scope.get("preparation_peers", []).duplicate()
	voice_backend.started = true
	voice_backend.sync_epoch()
	scope["api"].input.input_blocked = false
	loading.clear()
	_deadline = 0
	phase = "main" if id == _main_id else "child"
	if connection.host:
		connection.room["phase"] = "playing"
	if id == _main_id and _restoring:
		scope["root"].party_resume()
	else:
		scope["root"].party_start()
	changed.emit()

func _apply_commit(candidate: Dictionary) -> void:
	if not _scopes.has(_main_id):
		return
	var next: Dictionary = candidate["record"]
	if next["revision"] <= _applied_revision:
		return
	_applied_revision = next["revision"]
	record = next.duplicate(true)
	var main: Dictionary = _scopes[_main_id]
	if candidate["kind"] == "rules":
		phase = candidate["previous_phase"]
		connection.room = record.room.duplicate(true)
		if connection.host:
			connection._publish()
		changed.emit()
		if not _deferred_finish.is_empty():
			var deferred: Dictionary = _deferred_finish
			_deferred_finish = {}
			if _scopes.has(deferred.scope):
				_finish(_scopes[deferred.scope], deferred.raw)
		return
	main["root"].restore_state(record["state"].duplicate(true))
	if candidate["kind"] == "round":
		var id: String = candidate["round"]
		_restore_parent("")
		main["api"].round_committed.emit(id, candidate["result"].duplicate(true))
	elif candidate["kind"] == "end":
		var presentation: Dictionary = record.get("presentation", {})
		cleanup("finished")
		phase = "finished"
		standings = presentation.duplicate(true)
		finished.emit(presentation)
	else:
		phase = "main"
		_release_view(main)
		_create_view(main)
	main["api"].state_committed.emit(record["revision"])
	changed.emit()

func cancel_round(reason: String) -> void:
	if not connection.host or _child_id.is_empty():
		return
	_pending.clear()
	connection.control("cancel", {"reason": reason})

func _restore_parent(reason: String) -> void:
	if _child_id.is_empty() or not _scopes.has(_main_id):
		return
	var round: String = _child_id
	_close_scope(_child_id, "finished" if reason.is_empty() else reason)
	_child_id = ""
	loading.clear()
	_deadline = 0
	var main: Dictionary = _scopes[_main_id]
	main["root"].restore_state(record["state"].duplicate(true))
	if not _activate_effects(main):
		cleanup("main_settings_failed")
		return
	main["phase"] = "playing"
	main["api"].input.input_blocked = false
	voice_backend.started = true
	voice_backend.sync_epoch()
	phase = "main"
	_create_view(main)
	main["root"].party_resume()
	if not reason.is_empty():
		main["api"].round_cancelled.emit(round, reason)
	changed.emit()

func _release_view(scope: Dictionary) -> void:
	var view: Node = scope.get("view")
	if is_instance_valid(view):
		view.get_parent().remove_child(view)
		view.queue_free()
	scope["view"] = null

## Reliable native despawns must precede the framework close on channel zero.
## Otherwise clients free their replication registry before Godot receives the despawn.
func _before_control(kind: String, payload: Dictionary) -> void:
	if kind == "cancel" or (kind == "committed" and payload.get("kind") == "round"):
		_detach_scope(_child_id, "finished" if kind == "committed" else payload.get("reason", "cancelled"))
	elif kind == "abort" or (kind == "committed" and payload.get("kind") == "end"):
		var ids: Array = _scopes.keys()
		ids.reverse()
		for id: String in ids:
			_detach_scope(id, "finished" if kind == "committed" else payload.get("reason", "closed"))

func _detach_scope(id: String, reason: String) -> void:
	if not _scopes.has(id):
		return
	var scope: Dictionary = _scopes[id]
	if scope["stopped"]:
		return
	scope["phase"] = "closed"
	scope["stopped"] = true
	scope["api"]._begin_close()
	if voice_backend.scope == id:
		voice_backend.deactivate()
	scope["root"].party_stop(StringName(reason))
	if scope.has("effects"):
		scope.effects.leave()
	scope["api"]._cleanup()
	Input.mouse_mode = scope["mouse_mode"]
	var root: Node = scope["root"]
	if is_instance_valid(root) and root.get_parent() != null:
		root.get_parent().remove_child(root)

func _close_scope(id: String, reason: String) -> void:
	if not _scopes.has(id):
		return
	_detach_scope(id, reason)
	var root: Node = _scopes[id]["root"]
	if is_instance_valid(root):
		root.queue_free()
	_scopes.erase(id)

func cleanup(reason: String = "closed") -> void:
	var ids: Array = _scopes.keys()
	ids.reverse()
	for id: String in ids:
		_close_scope(id, reason)
	_main_id = ""
	_child_id = ""
	_pending.clear()
	_deferred_finish.clear()
	loading.clear()
	_received.clear()
	_sent.clear()
	_deadline = 0
	phase = "idle"
	Input.mouse_mode = _mouse_mode
	if _saved_focus != null:
		var focus: Control = _saved_focus.get_ref()
		if is_instance_valid(focus) and focus.is_inside_tree() and focus.is_visible_in_tree():
			focus.grab_focus()
	changed.emit()

func _send_message(scope: Dictionary, payload: Dictionary) -> Error:
	var mode: int = payload["mode"]
	var lane: int = payload["channel"]
	var channel: int = PartyNet.MESSAGE_CHANNEL_BASE + lane * 3 + mode
	var target: String = payload["target"]
	var destination: String = scope["id"]
	if target == "parent":
		if scope["id"] != _child_id:
			return ERR_UNAVAILABLE
		destination = _main_id
	elif target == "child":
		if scope["id"] != _main_id or _child_id.is_empty() or not connection.host:
			return ERR_UNAVAILABLE
		destination = _child_id
	var targets: Array[int] = []
	for player: Dictionary in connection.players:
		if not player["connected"]:
			continue
		var participant: bool = player["player_id"] in scope["participants"]
		var include: bool = target in ["instance", "child"] or (target in ["host", "parent"] and player["peer_id"] == 1) or (target == "participants" and participant) or (target == "spectators" and not participant) or target == "player:" + player["player_id"] or target == "peer:" + str(player["peer_id"])
		if include and (payload["include_self"] or player["peer_id"] != connection.local_peer()):
			targets.append(player["peer_id"])
	if targets.is_empty():
		return OK if target in ["instance", "participants", "spectators", "child"] else ERR_DOES_NOT_EXIST
	# Enqueue remote sends before self delivery: local callbacks may finish and close this scope.
	var include_own: bool = connection.local_peer() in targets
	targets.erase(connection.local_peer())
	if include_own:
		targets.append(connection.local_peer())
	for peer: int in targets:
		var key: String = "%s:%s:%s:%s:%s:%s" % [scope.id, destination, payload.topic, mode, lane, peer]
		_sent[key] = _sent.get(key, 0) + 1
		var packet: Dictionary = {"scope": scope.id, "destination": destination, "round": scope.round, "package": scope.package,
			"target": peer, "topic": payload.topic, "payload": payload.payload, "sequence": _sent[key], "mode": mode, "channel": lane}
		var error: Error = connection.send_packet(peer, packet, mode, channel)
		if error != OK:
			return error
	return OK

func _packet(sender: int, packet: Dictionary) -> void:
	for field: String in ["scope", "destination", "round", "package", "topic"]:
		if not packet.get(field) is String:
			return
	for field: String in ["target", "sequence", "mode", "channel"]:
		if not packet.get(field) is int:
			return
	if packet.sequence < 1 or packet.mode not in [MultiplayerPeer.TRANSFER_MODE_RELIABLE, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED] or packet.channel < 0 or packet.channel >= PartyNet.MESSAGE_LANES:
		return
	var scope: Dictionary = _scopes.get(packet.scope, {})
	var target: Dictionary = _scopes.get(packet.destination, {})
	var player: Dictionary = _peer(sender)
	if scope.is_empty() or target.is_empty() or scope.phase == "closed" or target.phase == "closed" or player.is_empty() or not player.connected:
		return
	if packet.get("session") != connection.session_id or packet.package != scope.package or packet.round != scope.round or packet.target != connection.local_peer():
		return
	if scope.id != target.id and not (scope.id == _child_id and target.id == _main_id and connection.host) and not (scope.id == _main_id and target.id == _child_id and sender == 1):
		return
	if packet.mode != MultiplayerPeer.TRANSFER_MODE_UNRELIABLE:
		var key: String = "%s:%s:%s:%s:%s:%s:%s" % [sender, scope.id, target.id, packet.topic, packet.mode, packet.channel, packet.target]
		if packet.sequence <= _received.get(key, 0):
			return
		_received[key] = packet.sequence
	var identity: Dictionary = {"peer_id": sender, "player_ids": [player.player_id]}
	var net: PartyNet = target.api.net
	if scope.id == target.id:
		net.message_received.emit(identity, StringName(packet.topic), Data.copy(packet.get("payload")))
	elif scope.id == _child_id:
		net.child_message_received.emit(identity, StringName(packet.topic), Data.copy(packet.get("payload")))
	else:
		net.parent_message_received.emit(identity, StringName(packet.topic), Data.copy(packet.get("payload")))

func _ids(players: Array) -> Array[String]:
	var result: Array[String] = []
	for player: Dictionary in players:
		result.append(player["player_id"])
	return result

func _participants(ids: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player: Dictionary in connection.players:
		if player["player_id"] in ids:
			result.append(player.duplicate(true))
	return result

func _peer(id: int) -> Dictionary:
	for player: Dictionary in connection.players:
		if player["peer_id"] == id:
			return player
	return {}

func _withdraw(peer: int) -> void:
	var departed: Dictionary = _peer(peer)
	# Active rosters preserve disconnected entries until the session returns to its lobby.
	if not departed.is_empty():
		for scope: Dictionary in _scopes.values():
			scope.api.player_disconnected.emit(departed.player_id, peer)
	if connection.host and phase == "loading":
		if not _child_id.is_empty():
			cancel_round("玩家加载期间断线")
		else:
			connection.control("abort", {"reason": "玩家加载期间断线"})
	elif connection.host and not _child_id.is_empty() and _scopes.has(_child_id):
		var any_connected: bool = false
		for player: Dictionary in _participants(_scopes[_child_id]["participants"]):
			any_connected = any_connected or player["connected"]
		if not any_connected:
			cancel_round("全部参赛者已退出")
	for scope: Dictionary in _scopes.values():
		scope["api"].players_changed.emit()

func _connection_changed() -> void:
	if _lobby_api != null:
		_lobby_api.players_changed.emit()
	if not connection.online and not _scopes.is_empty():
		cleanup("disconnected")
	for scope: Dictionary in _scopes.values():
		scope["api"].players_changed.emit()

func _process(_delta: float) -> void:
	_update_lobby_settings()
	if connection != null and connection.host and _deadline > 0 and Time.get_ticks_msec() > _deadline:
		_deadline = 0
		if not _child_id.is_empty():
			cancel_round("加载超时")
		else:
			connection.control("abort", {"reason": "大游戏加载超时"})



func _activate_effects(scope: Dictionary) -> bool:
	voice_backend.activate(scope.id, scope.id)
	var api: PartyAPI = scope.api
	api.voice = VoiceAPI.new()
	api.voice.initialize(voice_backend, scope.id, voice_backend.generation)
	var effects: RefCounted = Effects.new()
	effects.failed.connect(_settings_failed)
	scope["effects"] = effects
	var error: Error = effects.enter(api, scope.root, catalog)
	if error != OK:
		failed.emit(effects.last_error)
		effects.leave()
		voice_backend.deactivate()
	return error == OK

## Stop this connection after a settings callback unwinds; never keep playing with failed effects.
func _settings_failed(message: String) -> void:
	failed.emit(message)
	connection.leave.call_deferred("设置应用失败：" + message)

func _close_lobby_settings() -> void:
	if _lobby_effects != null:
		voice_backend.deactivate()
		_lobby_effects.leave()
		_lobby_api._begin_close()
		_lobby_api._cleanup()
		_lobby_effects = null
		_lobby_api = null

## Ensure the main-game room view receives the current lobby activation before entering the tree.
func prepare_room() -> PartyAPI:
	_update_lobby_settings()
	return _lobby_api

## Lobby settings use the same public identity/appearance snapshots as activity scopes.
func _lobby_query(_scope: String, key: String, argument: Dictionary) -> Variant:
	if key == "peer_stats":
		return connection.get_peer_stats(argument.peer_id)
	if key == "host_time":
		return connection.network_clock.now_msec()
	if key == "clock_ready":
		return connection.network_clock.is_ready()
	if key == "appearances":
		var appearances: Dictionary = {}
		for player: Dictionary in connection.players:
			appearances[player.player_id] = player.appearance.duplicate(true)
		return appearances
	if key in ["players", "room_players"]:
		var players: Array[Dictionary] = []
		for source: Dictionary in connection.players:
			var player: Dictionary = source.duplicate(true)
			player["is_local"] = source.peer_id == connection.local_peer()
			players.append(player)
		return players
	return {}

func _update_lobby_settings() -> void:
	var protocol: String = catalog.get_package(connection.room.get("main", "")).get("protocol", {}).get("id", "")
	var lobby: bool = connection.online and phase == "idle" and connection.room.get("phase") == "lobby" and not protocol.is_empty()
	if not lobby or (_lobby_api != null and (_lobby_api.protocol_id != protocol or _lobby_api._context.get("rules_revision") != connection.room.get("rules_revision"))):
		_close_lobby_settings()
	if not lobby or _lobby_api != null:
		return
	var id: String = "lobby_" + protocol
	_lobby_api = API.new({"session_id": connection.session_id, "scope_id": id, "protocol_id": protocol, "package_id": "", "rules_revision": connection.room.get("rules_revision"), "is_host": connection.host}, func(_scope: String, _op: String, _data: Dictionary) -> Error: return ERR_UNAVAILABLE, _lobby_query)
	_lobby_api.i18n = catalog.i18n.scope(connection.room.main)
	_lobby_api.config = Config.new()
	if _lobby_api.config.initialize(config_store, "", protocol, {"common": connection.room.get("common", {}), "own": {}}) != OK:
		failed.emit(_lobby_api.config.last_error)
		_lobby_api._begin_close()
		_lobby_api._cleanup()
		_lobby_api = null
		return
	_lobby_api.input = settings.create_context()
	voice_backend.activate(id, id)
	_lobby_api.voice = VoiceAPI.new()
	_lobby_api.voice.initialize(voice_backend, id, voice_backend.generation)
	_lobby_effects = Effects.new()
	_lobby_effects.failed.connect(_settings_failed)
	if _lobby_effects.enter(_lobby_api, self, catalog) != OK or not _lobby_effects.attach(self):
		failed.emit(_lobby_effects.last_error)
		_close_lobby_settings()
		return
	_lobby_api.input.input_blocked = false
	voice_backend.started = true
	voice_backend.sync_epoch()


## Host UI only. Running edits share the durable serial commit queue and never invoke the reducer.
func edit_room_rules(revision: int, edits: Array) -> Error:
	if not connection.host:
		return ERR_UNAUTHORIZED
	if not _pending.is_empty() or phase not in ["idle", "main", "child"]:
		return ERR_BUSY
	var current: Dictionary = connection.room if phase == "idle" else record.room
	var checked: Dictionary = Rules.patch(current, catalog, revision, edits, phase != "idle")
	if not checked.ok:
		failed.emit(checked.message)
		return checked.code
	if phase == "idle":
		connection.room = checked.room
		connection._publish()
		_close_lobby_settings()
		return OK
	var next: Dictionary = _next_record(record.state)
	next.room = checked.room
	next.room.phase = connection.room.phase
	return _queue_commit({"kind": "rules", "record": next, "previous_phase": phase})

func _network_stats_changed() -> void:
	if _lobby_api != null:
		_lobby_api.net.stats_changed.emit()
	for scope: Dictionary in _scopes.values():
		scope.api.net.stats_changed.emit()
	if not loading.is_empty() and _scopes[loading.scope].ready_requested:
		_report_ready(loading.scope)

## Only the network boundary validates control shapes; internal handlers use the checked contract.
func _valid_control(kind: String, payload: Dictionary) -> bool:
	match kind:
		"ready", "start", "failure", "readiness", "child":
			if not payload.get("scope") is String or payload.scope.is_empty():
				return false
	match kind:
		"ready":
			return payload.get("rules") is String
		"failure", "cancel", "abort":
			return payload.get("reason") is String
		"readiness":
			if not payload.get("peers") is Array:
				return false
			for peer: Variant in payload.peers:
				if not peer is int or peer < 1:
					return false
		"install", "committed":
			if not payload.get("record") is Dictionary:
				return false
			var next: Dictionary = payload.record
			for key: String in ["state", "room", "main_rules"]:
				if not next.get(key) is Dictionary:
					return false
			if not next.get("main_scope") is String or next.main_scope.is_empty() or not next.get("revision") is int or not next.get("rounds") is Array:
				return false
			if kind == "committed":
				if payload.get("kind") not in ["initial", "state", "round", "end", "rules"]:
					return false
				if payload.kind == "round" and (not payload.get("round") is String or not payload.get("result") is Dictionary):
					return false
				if payload.kind == "rules" and not payload.get("previous_phase") is String:
					return false
		"child":
			for key: String in ["rules", "request", "config"]:
				if not payload.get(key) is Dictionary:
					return false
			if not payload.get("id") is String or not payload.get("seed") is int or not payload.get("participants") is Array:
				return false
			for id: Variant in payload.participants:
				if not id is String:
					return false
	return true
