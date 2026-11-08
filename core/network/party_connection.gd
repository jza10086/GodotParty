## One ENet connection for the formal lobby and development entry. No gameplay state.
extends Node

const Data = preload("res://core/runtime/party_data.gd")
const Rules = preload("res://core/config/party_room_rules.gd")
const PlayerCounts = preload("res://core/config/party_player_counts.gd")
const Profiles = preload("res://core/runtime/party_profiles.gd")
const MAX_PACKET_BYTES: int = 1048576
signal changed()
signal control_received(sender: int, kind: String, payload: Dictionary)
signal control_sending(kind: String, payload: Dictionary)
signal media_received(sender: int, packet: Dictionary)
signal packet_received(sender: int, packet: Dictionary)
signal disconnected(peer_id: int)
signal profile_reply(request_id: String, accepted: bool, message: String)
var catalog: RefCounted
var settings: PartyInput
var profiles: RefCounted
var players: Array[Dictionary] = []
var room: Dictionary = {}
var session_id: String = ""
var status: String = ""
var host: bool = false
var online: bool = false
var recovery: Dictionary = {}
## Local transport details; never part of the authoritative room snapshot.
var connection_address: String = ""
var connection_port: int = 0

## Port zero is intentionally excluded: the lobby must advertise a known UDP port.
static func valid_port(value: int) -> bool:
	return value >= 1 and value <= 65535

static func parse_port(value: String) -> int:
	var text: String = value.strip_edges()
	if text.is_empty() or text.length() > 5:
		return 0
	for character: String in text:
		if character < "0" or character > "9":
			return 0
	var port: int = text.to_int()
	return port if valid_port(port) else 0

## Normalize an IP literal or DNS hostname without a port; DNS resolution belongs to ENet.
static func normalize_address(value: String) -> String:
	var address: String = value.strip_edges()
	if address.begins_with("[") and address.ends_with("]"):
		address = address.substr(1, address.length() - 2)
		return address if address.contains(":") and address.is_valid_ip_address() else ""
	if address.is_valid_ip_address():
		return address
	address = address.to_lower()
	var hostname: String = address.trim_suffix(".")
	if hostname.is_empty() or hostname.length() > 253:
		return ""
	var has_letter: bool = false
	for label: String in hostname.split("."):
		if label.is_empty() or label.length() > 63 or label.begins_with("-") or label.ends_with("-"):
			return ""
		for character: String in label:
			if character >= "a" and character <= "z":
				has_letter = true
			elif not (character >= "0" and character <= "9") and character != "-":
				return ""
	# Reject malformed numeric IPv4 addresses instead of treating them as hostnames.
	return address if has_letter else ""

## Parse one join field. Missing ports use 7777; IPv6 ports require [address]:port.
## An empty result means invalid user input. Bare IPv6 is never split at its last colon.
static func parse_endpoint(value: String) -> Dictionary:
	var text: String = value.strip_edges()
	var address: String = text
	var port: int = 7777
	if text.begins_with("["):
		var closing: int = text.find("]")
		if closing == -1:
			return {}
		address = normalize_address(text.substr(0, closing + 1))
		var suffix: String = text.substr(closing + 1)
		if not suffix.is_empty():
			if not suffix.begins_with(":"):
				return {}
			port = parse_port(suffix.substr(1))
	elif text.count(":") == 1:
		var separator: int = text.find(":")
		address = normalize_address(text.substr(0, separator))
		port = parse_port(text.substr(separator + 1))
	else:
		address = normalize_address(text)
	if address.is_empty() or not valid_port(port):
		return {}
	return {"address": address, "port": port}

static func format_endpoint(address: String, port: int) -> String:
	return "[%s]:%d" % [address, port] if address.contains(":") else "%s:%d" % [address, port]

func _connection_failed() -> void:
	leave("连接 %s 失败，请检查地址、UDP 端口和防火墙" % format_endpoint(connection_address, connection_port))

var _acks: Dictionary = {}
var _ack_deadline: int = 0
var _pending_profile: Dictionary = {}
var _profile_deadline: int = 0
var _connection_deadline: int = 0
var _profile_protocol: String = ""
var _scene: SceneMultiplayer
var _hello_peers: Dictionary = {}

func _ready() -> void:
	_scene = multiplayer as SceneMultiplayer
	_scene.peer_packet.connect(_packet)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(func() -> void: leave("房主已离开"))
	multiplayer.peer_connected.connect(func(id: int) -> void: _hello_peers[id] = Time.get_ticks_msec() + 10000)
	multiplayer.peer_disconnected.connect(_disconnected)

func initialize(local_catalog: RefCounted, local_settings: PartyInput) -> Error:
	catalog = local_catalog
	settings = local_settings
	profiles = Profiles.new(settings)
	return profiles.initialize()

func local_peer() -> int:
	return multiplayer.get_unique_id() if online else 1

## Optional display title has no access-control or discovery semantics.
func open_host(port: int = 7777, bind_address: String = "*", room_name: String = "GodotParty", main_id: String = "") -> Error:
	if online:
		return ERR_ALREADY_IN_USE
	if not main_id.is_empty() and main_id not in catalog.ids("maingame"):
		return ERR_INVALID_PARAMETER
	if not valid_room_name(room_name) or not valid_port(port):
		status = "房间名称无效或端口不在 1–65535 范围内"
		return ERR_INVALID_PARAMETER
	var bind_ip: String = "*" if bind_address == "*" else normalize_address(bind_address)
	if bind_ip != "*" and not bind_ip.is_valid_ip_address():
		status = "监听地址必须是 IPv4、IPv6 或 *"
		return ERR_INVALID_PARAMETER
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	# Wildcard keeps Godot's dual-stack socket: IPv4 and IPv6 share the selected port.
	peer.set_bind_ip(bind_ip)
	var error: Error = peer.create_server(port, 7, catalog.channel_count)
	if error != OK:
		status = "无法监听 UDP 端口 %d，请检查端口占用或监听地址" % port
		return error
	status = ""
	connection_address = bind_ip
	connection_port = port
	# Godot 4.7 5b4e0cb0f passes max_channels into ENet's bandwidth argument.
	# Set both explicitly before accepting peers; two physical channels belong to ENetMultiplayerPeer.
	peer.host.bandwidth_limit(0, 0)
	peer.host.channel_limit(catalog.channel_count + 2)
	_scene.multiplayer_peer = peer
	online = true
	host = true
	session_id = Data.token()
	var identity: Dictionary = profiles.identity()
	players = [_make_player(identity, 1)]
	room = {"title": room_name, "main": "", "settings": {}, "children": {}, "pools": {}, "revision": 0, "phase": "lobby", "channels": catalog.channels.duplicate(), "channel_count": catalog.channel_count}
	var mains: Array[String] = catalog.ids("maingame")
	if not mains.is_empty():
		var chosen: String = main_id if not main_id.is_empty() else mains[0]
		var configured: Error = configure(chosen, catalog.defaults(chosen), {}, {})
		if configured != OK:
			leave("创建失败：" + status)
			return configured
	changed.emit()
	return OK

static func valid_room_name(value: String) -> bool:
	if value.is_empty() or value.length() > 24 or value != value.strip_edges():
		return false
	for character: String in value:
		if character.unicode_at(0) < 32 or character.unicode_at(0) == 127:
			return false
	return true

func join(address: String, port: int = 7777) -> Error:
	if online:
		return ERR_ALREADY_IN_USE
	var target: String = normalize_address(address)
	if target.is_empty() or not valid_port(port):
		status = "请输入有效的 IPv4、IPv6 或域名，端口范围为 1–65535"
		return ERR_INVALID_PARAMETER
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(target, port, 80)
	if error != OK:
		status = "无法连接 " + format_endpoint(target, port) + "：" + error_string(error)
		return error
	status = ""
	connection_address = target
	connection_port = port
	_scene.multiplayer_peer = peer
	online = true
	host = false
	_connection_deadline = Time.get_ticks_msec() + 10000
	return OK

func leave(reason: String = "") -> void:
	var was_online: bool = online
	online = false
	host = false
	var previous: MultiplayerPeer = _scene.multiplayer_peer
	_scene.multiplayer_peer = OfflineMultiplayerPeer.new()
	if was_online:
		previous.close()
	online = false
	host = false
	session_id = ""
	connection_address = ""
	connection_port = 0
	players.clear()
	room.clear()
	recovery.clear()
	_acks.clear()
	_ack_deadline = 0
	_hello_peers.clear()
	_profile_protocol = ""
	status = reason
	_connection_deadline = 0
	if not _pending_profile.is_empty():
		profile_reply.emit(_pending_profile["id"], false, "连接已断开，草稿未应用")
		_pending_profile.clear()
	changed.emit()

func _connected() -> void:
	_send(1, {"kind": "hello", "payload": profiles.identity()})

func _make_player(identity: Dictionary, peer: int) -> Dictionary:
	return {"player_id": identity["player_id"], "name": identity["name"], "peer_id": peer, "connected": true, "ready": peer == 1, "profile": {}, "appearance": {}}

func _packet(sender: int, bytes: PackedByteArray) -> void:
	if bytes.size() > MAX_PACKET_BYTES:
		return
	var packet: Variant = bytes_to_var(bytes)
	if not packet is Dictionary or not Data.valid(packet):
		return
	if packet.get("wire") != Data.WIRE_VERSION:
		if host:
			_send(sender, {"kind": "rejected", "payload": {"message": "联机协议版本不同（当前版本：%s；房主所需版本：%d）" % [str(packet.get("wire")), Data.WIRE_VERSION]}})
		elif sender == 1:
			leave("联机协议版本不同（当前版本：%d；房主所需版本：%s）" % [Data.WIRE_VERSION, str(packet.get("wire"))])
		return
	if not packet.get("kind") is String or not packet.get("session") is String:
		return
	var kind: String = packet["kind"]
	if kind == "media":
		if bytes.size() <= 2048 and packet["session"] == session_id and not _player_peer(sender).is_empty():
			media_received.emit(sender, packet)
		return
	if kind == "net":
		if packet["session"] == session_id and not _player_peer(sender).is_empty():
			packet_received.emit(sender, packet)
		return
	var payload: Variant = packet.get("payload", {})
	if not payload is Dictionary:
		return
	if kind == "profile_offer" and sender == 1 and not host and room.is_empty():
		var issue: String = catalog.requirements_issue(payload.get("packages"))
		if not issue.is_empty():
			leave("加入房间失败：\n" + issue)
			return
		var protocol_id: String = str(payload.get("protocol", ""))
		var script: Resource = catalog.load_entry(protocol_id)
		if not script is Script:
			leave("房间协议入口无法加载：" + protocol_id)
			return
		var protocol: RefCounted = script.new()
		if not protocol.has_method("default_player_config") or not protocol.has_method("validate_player_config"):
			leave("房间协议资料接口不完整")
			return
		var local_profile: Dictionary = profiles.read(protocol_id, protocol)
		if not local_profile.ok:
			leave(local_profile.message)
			return
		var identity: Dictionary = profiles.identity()
		identity["protocol"] = protocol_id
		identity["name"] = local_profile.name
		identity["profile"] = local_profile.profile
		_profile_protocol = protocol_id
		_send(1, {"kind": "hello", "payload": identity})
		return
	if kind == "hello" and host:
		_accept_hello(sender, payload)
		return
	if sender == 1 and kind == "rejected":
		leave(payload.get("message", "加入失败"))
		return
	if sender == 1 and kind == "room" and not host:
		if not _valid_room_snapshot(payload):
			leave("加入或更新房间失败：房主发送的房间数据格式无效")
			return
		session_id = packet["session"]
		var issue: String = _room_content_issue(payload)
		_send(1, {"kind": "ack", "payload": {"revision": payload.room.revision, "matches": issue.is_empty(), "message": issue}})
		if not issue.is_empty():
			status = "房间内容与配置检查失败：\n" + issue
			# Wait for the host's rejection so its UI also receives the specific reason.
			_connection_deadline = Time.get_ticks_msec() + 10000
			return
		players.assign(payload["players"])
		room = payload["room"].duplicate(true)
		_connection_deadline = 0
		status = ""
		changed.emit()
		_auto_profile()
		return
	if packet.get("session") != session_id or _player_peer(sender).is_empty():
		return
	if kind == "control":
		if payload.get("operation") is String and payload.get("data") is Dictionary:
			control_received.emit(sender, payload["operation"], payload["data"])
	elif host and kind == "ack":
		if payload.get("revision") != room.get("revision"):
			return
		if not payload.get("matches") is bool or not payload.get("message") is String or payload.matches != payload.message.is_empty():
			status = _player_peer(sender).name + " 的内容确认回执格式无效"
			_send(sender, {"kind": "rejected", "payload": {"message": status}})
			changed.emit()
			return
		_acks[sender] = {"matches": payload.matches, "message": payload.message}
		if not payload.matches:
			status = _player_peer(sender).name + " 检查未通过：\n" + payload.message
			_send(sender, {"kind": "rejected", "payload": {"message": "加入或更新房间失败：\n" + payload.message}})
		changed.emit()
	elif host and kind == "ready" and room.get("phase") == "lobby":
		_player_peer(sender)["ready"] = payload.get("ready") == true
		_publish(false)
	elif host and kind == "profile":
		_profile_request(sender, payload)
	elif not host and sender == 1 and kind == "profile_reply":
		_profile_response(payload)

func _accept_hello(sender: int, identity: Dictionary) -> void:
	if not room.has("closure"):
		_send(sender, {"kind": "rejected", "payload": {"message": "房主内容不可用：\n" + status}})
		return
	# Learn the selected protocol before publishing the player, so their own preferred
	# color participates in allocation rather than an unrelated default placeholder.
	if recovery.is_empty() and room.get("phase") == "lobby" and _player_peer(sender).is_empty() and identity.get("protocol") != _protocol_id():
		_send(sender, {"kind": "profile_offer", "payload": {"protocol": _protocol_id(), "packages": room["closure"]}})
		return
	var reason: String = ""
	if room.get("phase") != "lobby":
		reason = "不支持运行中加入"
	elif players.size() >= 8 or not _player_peer(sender).is_empty():
		reason = "房间已满或连接重复"
	elif not identity.get("player_id") is String or identity["player_id"].is_empty() or not identity.get("name") is String or not Profiles.validate_name(identity["name"]):
		reason = "身份或昵称无效"
	else:
		for player: Dictionary in players:
			if player["player_id"] == identity["player_id"] or player["name"].to_lower() == identity["name"].to_lower():
				reason = "身份或昵称重复"
	if not recovery.is_empty() and Data.player(recovery["players"], identity.get("player_id", "")).is_empty():
		reason = "恢复房间只允许原玩家加入"
	if not reason.is_empty():
		_send(sender, {"kind": "rejected", "payload": {"message": reason}})
		return
	var value: Dictionary = _make_player(identity, sender)
	if not recovery.is_empty():
		var saved: Dictionary = Data.player(recovery["players"], identity["player_id"])
		for key: String in ["name", "profile", "appearance"]:
			value[key] = Data.copy(saved[key])
	else:
		var protocol: RefCounted = protocol_instance()
		if protocol != null:
			if not identity.get("profile") is Dictionary:
				_send(sender, {"kind": "rejected", "payload": {"message": "缺少协议玩家资料"}})
				return
			var resolved: Dictionary = _resolve_player_profile(protocol, identity.profile, str(value.player_id))
			if not resolved.get("ok", false):
				_send(sender, {"kind": "rejected", "payload": {"message": resolved.get("message", "协议资料分配失败")}})
				return
			value["profile"] = resolved.value
			value["appearance"] = protocol.get_appearance(value["profile"])
	players.append(value)
	_hello_peers.erase(sender)
	_publish()

func protocol_instance() -> RefCounted:
	var main: Dictionary = catalog.get_package(room.get("main", ""))
	var resource: Resource = catalog.load_entry(main.get("protocol", {}).get("id", ""))
	if not resource is Script:
		return null
	var instance: RefCounted = resource.new()
	for hook: String in ["validate_request", "validate_result", "default_player_config", "validate_player_config", "get_appearance"]:
		if not instance.has_method(hook):
			status = "协议缺少必要入口：" + hook
			return null
	return instance

func configure(main_id: String, configuration: Dictionary, child_settings: Dictionary, pools: Dictionary, common: Variant = null, common_overrides: Variant = null) -> Error:
	if not host or room.get("phase") != "lobby" or not recovery.is_empty():
		return ERR_UNAUTHORIZED
	if not str(room.get("main", "")).is_empty() and room.main != main_id:
		status = "本房间大游戏与协议已固定，请重新创建房间"
		return ERR_ALREADY_IN_USE
	var main: Dictionary = catalog.get_package(main_id)
	if main.get("kind") != "maingame":
		return ERR_INVALID_PARAMETER
	var checked: Dictionary = catalog.validate_settings(main_id, configuration)
	if not checked.get("ok"):
		status = checked.get("message", "")
		return ERR_INVALID_PARAMETER
	for pool: Variant in pools:
		if not pool is String or pool not in main.get("pools", []) or not pools[pool] is Array:
			status = "未知或无效的小游戏池"
			return ERR_INVALID_PARAMETER
	var children: Dictionary = {}
	var selected_pools: Dictionary = {}
	for pool: String in main.get("pools", []):
		selected_pools[pool] = pools.get(pool, []).duplicate()
	for selected: Array in selected_pools.values():
		for id: String in selected:
			var child: Dictionary = catalog.validate_settings(id, child_settings.get(id, {}))
			if not child.get("ok"):
				status = child.get("message", "")
				return ERR_INVALID_PARAMETER
			children[id] = child["value"]
	var previous_room: Dictionary = room.duplicate(true)
	var previous_players: Array[Dictionary] = players.duplicate(true)
	var previous_id: String = room.get("main", "")
	var previous_protocol: String = catalog.get_package(previous_id).get("protocol", {}).get("id", "")
	room.merge({"main": main_id, "settings": checked["value"], "children": children, "pools": selected_pools}, true)
	Rules.initialize(room, catalog)
	for game: String in room.common_overrides.keys():
		if game != main_id and not children.has(game):
			room.common_overrides.erase(game)
	if common != null or common_overrides != null:
		if not common is Dictionary or not common_overrides is Dictionary:
			room = previous_room
			return ERR_INVALID_PARAMETER
		room.common = catalog.Schema.defaults(catalog.schema(main.protocol.id), "room")
		room.common_overrides = {}
		var edits: Array = []
		for key: String in common:
			edits.append({"target": "protocol_base", "op": "set", "key": key, "value": common[key]})
		for game: String in common_overrides:
			for key: String in common_overrides[game]:
				edits.append({"target": "game_common", "game_id": game, "op": "set", "key": key, "value": common_overrides[game][key]})
		var rules_checked: Dictionary = Rules.patch(room, catalog, int(room.rules_revision), edits, false)
		if not rules_checked.ok:
			room = previous_room
			status = rules_checked.message
			return ERR_INVALID_DATA
		room = rules_checked.room
	var protocol: RefCounted = protocol_instance()
	if protocol == null:
		room = previous_room
		return ERR_UNCONFIGURED
	if previous_protocol != main["protocol"]["id"]:
		for player: Dictionary in players:
			var resolved: Dictionary = _resolve_player_profile(protocol, protocol.default_player_config(), str(player.player_id))
			if not resolved.get("ok", false):
				room = previous_room
				players = previous_players
				status = resolved.get("message", "协议资料分配失败")
				return ERR_INVALID_DATA
			player["profile"] = resolved.value
			player["appearance"] = protocol.get_appearance(player["profile"])
	var closure: Dictionary = catalog.resolve(main_id, selected_pools, _appearances())
	if not closure.get("ok"):
		status = closure.get("message", "")
		room = previous_room
		players = previous_players
		return ERR_INVALID_DATA
	room.rules_revision = int(previous_room.get("rules_revision", 0)) + 1
	_publish()
	_auto_profile()
	return OK if online else ERR_INVALID_DATA

func set_ready(value: bool) -> void:
	if not online or room.get("phase") != "lobby":
		return
	if host:
		_player_peer(1)["ready"] = value
		_publish(false)
	else:
		_send(1, {"kind": "ready", "payload": {"ready": value}})

## Recomputed from the host room snapshot so pool and configuration edits cannot leave stale limits.
func allowed_player_counts() -> Array[int]:
	return PlayerCounts.room_counts(room, catalog)

func player_count_reason() -> String:
	var counts: Array[int] = allowed_player_counts()
	if counts.is_empty():
		return "人数限制无交集，请调整配置或小游戏池"
	if players.size() not in counts:
		return "当前 %d 人；允许开始：%s" % [players.size(), PlayerCounts.describe(counts)]
	return ""

func start_reason() -> String:
	if not host or room.get("phase") != "lobby":
		return "仅房主可在大厅开始"
	var main: Dictionary = catalog.get_package(room.get("main", ""))
	if main.is_empty() or not room.has("closure"):
		return "请选择已安装且依赖完整的大游戏"
	for pool: String in main.get("pools", []):
		if room.pools.get(pool, []).is_empty():
			return "请至少选择一个小游戏"
	var count_reason: String = player_count_reason()
	if not count_reason.is_empty():
		return count_reason
	if not recovery.is_empty() and players.size() != recovery["players"].size():
		return "等待原玩家全部到齐"
	for player: Dictionary in players:
		if player.peer_id == 1:
			continue
		if not _acks.has(player.peer_id):
			return "正在检查 " + player.name + " 的内容与配置（等待客户端回执）"
		var report: Dictionary = _acks[player.peer_id]
		if not report.matches:
			return player.name + " 检查未通过：" + report.message
	for player: Dictionary in players:
		if not player.ready:
			return "等待 " + player.name + " 准备"
	return status if not room.has("closure") else ""

func prepare_restore(record: Dictionary) -> Error:
	if not host or room.get("phase") != "lobby":
		return ERR_UNAUTHORIZED
	if players.size() != 1:
		status = "请在其他玩家加入前选择恢复记录"
		return ERR_BUSY
	if record.get("status") != "active" or not record.get("room") is Dictionary or not record.get("appearances") is Dictionary or not _valid_room_snapshot({"players": record.get("players"), "room": record["room"]}):
		status = "存档结构无效或会话已结束"
		return ERR_INVALID_DATA
	var issue: String = _room_content_issue({"players": record.players, "room": record.room})
	if not issue.is_empty():
		status = "无法恢复房间：" + issue
		return ERR_INVALID_DATA
	var own: Dictionary = Data.player(record.get("players", []), profiles.identity()["player_id"])
	if own.is_empty() or own.get("peer_id") != 1:
		return ERR_UNAUTHORIZED
	var resolved: Dictionary = catalog.resolve(record["room"]["main"], record["room"]["pools"], record["appearances"].values())
	if not resolved.get("ok") or resolved["packages"] != record["room"]["closure"]:
		status = "恢复所需内容缺失或版本不符"
		return ERR_INVALID_DATA
	recovery = record.duplicate(true)
	room = record["room"].duplicate(true)
	room["phase"] = "lobby"
	room["recovery"] = true
	room["channels"] = catalog.channels.duplicate()
	players = [own]
	players[0]["connected"] = true
	players[0]["ready"] = true
	_publish()
	return OK

func submit_profile(name_value: String, value: Dictionary) -> Error:
	if not online or room.get("phase") != "lobby" or room.get("recovery", false):
		return ERR_UNAVAILABLE
	if not _pending_profile.is_empty():
		return ERR_BUSY
	if not Data.valid(value):
		return ERR_INVALID_PARAMETER
	_pending_profile = {"id": Data.token(), "name": name_value, "value": value.duplicate(true)}
	_profile_deadline = Time.get_ticks_msec() + 10000
	if host:
		_profile_request(1, _pending_profile)
	else:
		_send(1, {"kind": "profile", "payload": _pending_profile})
	return OK

## Protocol-owned room constraints run on the host using authoritative player snapshots.
func _resolve_player_profile(protocol: RefCounted, value: Dictionary, player_id: String) -> Dictionary:
	var report: Dictionary = protocol.validate_player_config(value)
	if not report.get("ok", false):
		return report
	if protocol.has_method("resolve_player_config"):
		report = protocol.resolve_player_config(value.duplicate(true), player_id, players.duplicate(true))
		if not report.get("ok", false):
			return report
		value = report.get("value", {})
	if not Data.valid(value) or not protocol.validate_player_config(value).get("ok", false):
		return {"ok": false, "message": "协议返回了无效资料"}
	return {"ok": true, "value": value.duplicate(true), "message": report.get("message", "")}

## Room-only assignment, callable by the local host in an unfrozen lobby.
## Protocol returns all affected profiles; validation completes before any player is changed.
func assign_player_profile(player_id: String, assignment: Dictionary) -> Dictionary:
	if not online or not host or room.get("phase") != "lobby" or not recovery.is_empty():
		return {"ok": false, "message": "只有大厅房主可以分配，活动或恢复期间不可修改"}
	var protocol: RefCounted = protocol_instance()
	if protocol == null or not protocol.has_method("assign_player_config"):
		return {"ok": false, "message": "协议不支持房主分配"}
	var report: Dictionary = protocol.assign_player_config(player_id, assignment.duplicate(true), players.duplicate(true))
	if not report.get("ok", false):
		return report
	var values: Variant = report.get("profiles")
	if not values is Dictionary or values.is_empty():
		return {"ok": false, "message": "协议分配结果无效"}
	var next: Array = players.duplicate(true)
	for id: Variant in values:
		var player: Dictionary = {}
		for candidate: Dictionary in next:
			if candidate.player_id == str(id):
				player = candidate
				break
		if player.is_empty() or not values[id] is Dictionary or not Data.valid(values[id]) or not protocol.validate_player_config(values[id]).get("ok", false):
			return {"ok": false, "message": "协议分配包含无效玩家或资料"}
		player.profile = values[id].duplicate(true)
		player.appearance = protocol.get_appearance(player.profile.duplicate(true))
		if not Data.valid(player.appearance):
			return {"ok": false, "message": "协议形象无效"}
	var appearances: Array = []
	for player: Dictionary in next:
		appearances.append(player.appearance)
	var closure: Dictionary = catalog.resolve(room.main, room.pools, appearances)
	if not closure.get("ok", false):
		return closure
	players.assign(next)
	_publish()
	return {"ok": true, "message": report.get("message", "已应用本房间分配")}

func _profile_request(sender: int, request: Dictionary) -> void:
	var accepted: bool = room.get("phase") == "lobby" and recovery.is_empty() and not _player_peer(sender).is_empty()
	var message: String = "活动已开始或正在恢复，资料未应用"
	var value: Variant = request.get("value")
	var name_value: String = str(request.get("name", ""))
	accepted = accepted and value is Dictionary and Profiles.validate_name(name_value)
	if not accepted and room.get("phase") == "lobby" and recovery.is_empty():
		message = "昵称需为 1–16 个字符，不能包含控制字符或首尾空格"
	for player: Dictionary in players:
		if player["peer_id"] != sender and player["name"].to_lower() == name_value.to_lower():
			accepted = false
			message = "昵称已被使用"
	if accepted:
		var protocol: RefCounted = protocol_instance()
		var validation: Dictionary = _resolve_player_profile(protocol, value, str(_player_peer(sender).player_id))
		accepted = validation.get("ok", false)
		message = validation.get("message", "")
		if accepted:
			value = validation.value
			var appearance: Dictionary = protocol.get_appearance(value.duplicate(true))
			var closure: Dictionary = catalog.resolve(room["main"], room["pools"], [appearance])
			accepted = closure.get("ok", false) and Data.valid(appearance)
			message = validation.get("message", "") if accepted else closure.get("message", "")
			if accepted:
				var player: Dictionary = _player_peer(sender)
				player["name"] = name_value
				player["profile"] = value.duplicate(true)
				player["appearance"] = appearance
				_publish()
	var reply: Dictionary = {"id": request.get("id", ""), "accepted": accepted, "message": message}
	if sender == 1:
		_profile_response(reply)
	else:
		_send(sender, {"kind": "profile_reply", "payload": reply})

func _profile_response(reply: Dictionary) -> void:
	if reply.get("id") != _pending_profile.get("id") or _pending_profile.is_empty():
		return
	var message: String = reply.get("message", "")
	if reply.get("accepted", false):
		var error: Error = profiles.save(_pending_profile["name"], _protocol_id(), _pending_profile["value"])
		if error != OK:
			message = "本次房间已生效，本机保存失败：" + error_string(error)
	var id: String = _pending_profile["id"]
	_pending_profile.clear()
	profile_reply.emit(id, reply.get("accepted", false), message)

func _auto_profile() -> void:
	var id: String = _protocol_id()
	if id.is_empty() or id == _profile_protocol or room.get("recovery", false) or room.get("phase") != "lobby":
		return
	var protocol: RefCounted = protocol_instance()
	if protocol == null:
		leave(status)
		return
	var local_profile: Dictionary = profiles.read(id, protocol)
	if not local_profile.ok:
		leave(local_profile.message)
		return
	_profile_protocol = id
	var error: Error = submit_profile(local_profile.name, local_profile.profile)
	if error != OK:
		leave("提交本机资料失败：" + error_string(error))

func _protocol_id() -> String:
	return catalog.get_package(room.get("main", "")).get("protocol", {}).get("id", "")

func _appearances() -> Array:
	var result: Array = []
	for player: Dictionary in players:
		result.append(player.get("appearance", {}))
	return result

## Player readiness changes do not invalidate already accepted content and settings.
func _publish(require_confirmation: bool = true) -> void:
	room["revision"] = room.get("revision", 0) + 1
	var closure: Dictionary = catalog.resolve(room.get("main", ""), room.get("pools", {}), _appearances())
	if closure.get("ok", false):
		room["closure"] = closure["packages"]
	else:
		room.erase("closure")
		status = closure.get("message", "")
	if require_confirmation:
		_acks.clear()
		_ack_deadline = Time.get_ticks_msec() + 10000
	for player: Dictionary in players:
		if player["peer_id"] != 1 and player["connected"]:
			_send(player["peer_id"], {"kind": "room", "payload": {"players": players, "room": room}})
	changed.emit()

func control(kind: String, payload: Dictionary, target: int = 0) -> void:
	if host and target == 0:
		control_sending.emit(kind, payload)
	if target == 0:
		if not host:
			return
		for player: Dictionary in players:
			if player["connected"] and player["peer_id"] != local_peer():
				_send(player["peer_id"], {"kind": "control", "payload": {"operation": kind, "data": payload}})
		control_received.emit(local_peer(), kind, payload.duplicate(true))
	elif target == local_peer():
		control_received.emit(local_peer(), kind, payload.duplicate(true))
	else:
		_send(target, {"kind": "control", "payload": {"operation": kind, "data": payload}})

func send_media(target: int, packet: Dictionary) -> Error:
	if not online or target not in multiplayer.get_peers():
		return ERR_UNAVAILABLE
	var envelope: Dictionary = packet.duplicate(true)
	envelope.merge({"wire": Data.WIRE_VERSION, "session": session_id, "kind": "media"}, true)
	var bytes: PackedByteArray = var_to_bytes(envelope)
	if bytes.size() > 2048:
		return ERR_INVALID_DATA
	return _scene.send_bytes(bytes, target, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, 2)

func send_packet(target: int, packet: Dictionary, mode: int, channel: int) -> Error:
	packet["wire"] = Data.WIRE_VERSION
	packet["session"] = session_id
	packet["kind"] = "net"
	if not packet_fits(packet):
		return ERR_INVALID_DATA
	if target == local_peer():
		packet_received.emit(target, packet.duplicate(true))
		return OK
	return _scene.send_bytes(var_to_bytes(packet), target, mode, channel)

func _send(target: int, packet: Dictionary) -> void:
	if not online or target not in multiplayer.get_peers():
		return
	if host and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		var remote: ENetPacketPeer = multiplayer.multiplayer_peer.get_peer(target)
		if remote == null or remote.get_state() != ENetPacketPeer.STATE_CONNECTED:
			return
	packet["wire"] = Data.WIRE_VERSION
	packet["session"] = session_id
	if packet_fits(packet):
		_scene.send_bytes(var_to_bytes(packet), target, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func _player_peer(peer: int) -> Dictionary:
	for player: Dictionary in players:
		if player.get("peer_id") == peer:
			return player
	return {}

func _disconnected(peer: int) -> void:
	_hello_peers.erase(peer)
	if not host:
		return
	var player: Dictionary = _player_peer(peer)
	if player.is_empty():
		return
	if room.get("phase") == "lobby":
		players.erase(player)
	else:
		player["connected"] = false
	disconnected.emit(peer)
	_publish()

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if _connection_deadline > 0 and now > _connection_deadline:
		leave(status if not status.is_empty() else "连接 %s 或握手超时，请检查 UDP 端口和防火墙" % format_endpoint(connection_address, connection_port))
	if not _pending_profile.is_empty() and now > _profile_deadline:
		var id: String = _pending_profile["id"]
		_pending_profile.clear()
		profile_reply.emit(id, false, "提交超时，草稿未应用")
	if host:
		if _ack_deadline > 0 and now > _ack_deadline:
			_ack_deadline = 0
			var timed_out: bool = false
			for player: Dictionary in players:
				if player.peer_id != 1 and not _acks.has(player.peer_id):
					_acks[player.peer_id] = {"matches": false, "message": "10 秒内未收到内容确认回执，请检查该实例是否暂停或断线"}
					timed_out = true
			if timed_out:
				changed.emit()
		for peer: int in _hello_peers.keys():
			if now > _hello_peers[peer]:
				_hello_peers.erase(peer)
				if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
					multiplayer.multiplayer_peer.disconnect_peer(peer)

## Control envelopes are measured before durable writes so local state cannot outgrow transport.
func control_fits(kind: String, payload: Dictionary) -> bool:
	return packet_fits({"wire": Data.WIRE_VERSION, "session": session_id, "kind": "control", "payload": {"operation": kind, "data": payload}})

func packet_fits(packet: Dictionary) -> bool:
	return Data.valid(packet) and var_to_bytes(packet).size() <= MAX_PACKET_BYTES

## Validate installed content before reading its configuration or constructing its room UI.
func _room_content_issue(payload: Dictionary) -> String:
	var snapshot: Dictionary = payload.room
	var issue: String = catalog.requirements_issue(snapshot.get("closure"))
	if not issue.is_empty():
		return issue
	var appearances: Array = []
	for player: Dictionary in payload.players:
		appearances.append(player.appearance)
	var resolved: Dictionary = catalog.resolve(snapshot.main, snapshot.pools, appearances)
	if not resolved.ok:
		return resolved.message
	for id: String in resolved.packages:
		if not snapshot.closure.has(id):
			return "依赖声明不同：本机额外需要 %s（版本 %s），房主清单未包含该包" % [id, resolved.packages[id].version]
	for id: String in snapshot.closure:
		if not resolved.packages.has(id):
			return "依赖声明不同：房主要求 %s（版本 %s），本机游戏未声明该依赖" % [id, snapshot.closure[id].version]
	return Rules.room_issue(snapshot, catalog)

## Reject malformed room snapshots before assigning typed collections or acknowledging a revision.
func _valid_room_snapshot(payload: Dictionary) -> bool:
	if not payload.get("players") is Array or not payload.get("room") is Dictionary:
		return false
	var snapshot: Dictionary = payload["room"]
	if snapshot.has("title") and (not snapshot.title is String or not valid_room_name(snapshot.title)):
		return false
	if not snapshot.get("main") is String or not snapshot.get("revision") is int or not snapshot.get("phase") is String:
		return false
	for key: String in ["settings", "children", "pools", "channels"]:
		if not snapshot.get(key) is Dictionary:
			return false
	if not snapshot.get("channel_count") is int or snapshot["channel_count"] < 2 or snapshot["channel_count"] > 80:
		return false
	for key: Variant in snapshot["channels"]:
		if not key is String or not snapshot["channels"][key] is int or snapshot["channels"][key] < 0 or snapshot["channels"][key] > snapshot["channel_count"]:
			return false
		if snapshot["channels"][key] == snapshot["channel_count"] and not key.ends_with(":native"):
			return false
	var identities: Dictionary = {}
	var peers: Dictionary = {}
	if payload["players"].is_empty() or payload["players"].size() > 8:
		return false
	for player: Variant in payload["players"]:
		if not player is Dictionary:
			return false
		if not player.get("player_id") is String or player["player_id"].is_empty() or not player.get("name") is String:
			return false
		if not player.get("peer_id") is int or player["peer_id"] < 1 or not player.get("connected") is bool or not player.get("ready") is bool:
			return false
		if not player.get("profile") is Dictionary or not player.get("appearance") is Dictionary:
			return false
		if identities.has(player["player_id"]) or peers.has(player["peer_id"]):
			return false
		identities[player["player_id"]] = true
		peers[player["peer_id"]] = true
	return peers.has(1)
