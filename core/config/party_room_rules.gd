## Host-owned room draft edits and deterministic immutable launch snapshots.
extends RefCounted
const Schema = preload("res://core/config/party_schema.gd")
const Data = preload("res://core/runtime/party_data.gd")

static func initialize(room: Dictionary, catalog: RefCounted) -> void:
	var protocol: String = catalog.get_package(room.main).protocol.id
	if room.get("settings_protocol", "") != protocol:
		room["settings_protocol"] = protocol
		room["common"] = Schema.defaults(catalog.schema(protocol), "room")
		room["common_overrides"] = {}
	if not room.has("rules_revision"):
		room["rules_revision"] = 0

static func snapshot(room: Dictionary, game: String, catalog: RefCounted) -> Dictionary:
	var protocol: String = catalog.get_package(room.main).protocol.id
	var common: Dictionary = room.get("common", {}).duplicate(true)
	var overrides: Dictionary = room.get("common_overrides", {}).get(game, {}).duplicate(true)
	common.merge(overrides, true)
	var own: Dictionary = room.settings if game == room.main else room.children.get(game, catalog.defaults(game))
	var value: Dictionary = {"game": game, "protocol": protocol, "protocol_major": catalog.get_package(protocol).contract.api_major, "protocol_settings": catalog.schema(protocol).settings_version, "game_settings": catalog.schema(game).settings_version, "revision": room.get("rules_revision", 0), "common": common, "own": own.duplicate(true), "base": room.get("common", {}).duplicate(true), "overrides": overrides}
	value["id"] = JSON.stringify(Data.canonical(value)).sha256_text()
	return value

static func validate_snapshot(value: Dictionary, room: Dictionary, game: String, catalog: RefCounted) -> bool:
	return value == snapshot(room, game, catalog)

## A batch either validates in full or changes nothing. Live room mutation is deliberately unsupported.
static func patch(room: Dictionary, catalog: RefCounted, revision: int, edits: Array, running: bool) -> Dictionary:
	if revision != int(room.get("rules_revision", 0)):
		return {"ok": false, "code": ERR_BUSY, "message": "房间规则已更新"}
	var next: Dictionary = room.duplicate(true)
	var protocol: String = catalog.get_package(room.main).protocol.id
	for edit: Variant in edits:
		if not edit is Dictionary or edit.get("op") not in ["set", "unset"] or edit.get("target") not in ["protocol_base", "game_common", "game_own"]:
			return {"ok": false, "code": ERR_INVALID_PARAMETER, "message": "无效的规则编辑"}
		var game: String = edit.get("game_id", "")
		var common: bool = edit.target != "game_own"
		if edit.target != "protocol_base" and game != room.main and not room.children.has(game):
			return {"ok": false, "code": ERR_UNAUTHORIZED, "message": "游戏未在当前池中启用"}
		var schema_value: Dictionary = catalog.schema(protocol if common else game)
		var key: String = edit.get("key", "")
		var field: Dictionary = schema_value.fields.get(key, {})
		if field.is_empty() or field.audience != "room" or (edit.target == "game_common" and not field.get("overridable", false)):
			return {"ok": false, "code": ERR_UNAUTHORIZED, "message": key + ": 不允许修改"}
		if running and (field.apply != "next_round" or (edit.target != "protocol_base" and game == room.main)):
			return {"ok": false, "code": ERR_UNAVAILABLE, "message": key + ": CONFIG_PHASE_LOCKED"}
		var target: Dictionary
		if edit.target == "protocol_base":
			target = next.common
		elif edit.target == "game_common":
			if not next.common_overrides.has(game):
				next.common_overrides[game] = {}
			target = next.common_overrides[game]
		else:
			target = next.settings if game == room.main else next.children[game]
		if edit.op == "unset":
			if edit.target == "game_common":
				target.erase(key)
			else:
				target[key] = Schema.normalize(field, field.default).value
		else:
			var checked: Dictionary = Schema.normalize(field, edit.get("value"))
			if not checked.ok:
				return {"ok": false, "code": ERR_INVALID_PARAMETER, "message": key + ": " + checked.message}
			target[key] = checked.value
	for game: String in [String(next.main)] + next.children.keys():
		var checked: Dictionary = catalog.validate_settings(game, next.settings if game == next.main else next.children[game])
		if not checked.ok:
			return {"ok": false, "code": ERR_INVALID_PARAMETER, "message": checked.message}
	next.rules_revision = int(room.get("rules_revision", 0)) + 1
	return {"ok": true, "room": next}


static func valid_room(room: Dictionary, catalog: RefCounted) -> bool:
	var main: Dictionary = catalog.get_package(room.get("main", ""))
	if main.get("kind") != "maingame" or not room.get("common") is Dictionary or not room.get("common_overrides") is Dictionary or not room.get("rules_revision") is int:
		return false
	var protocol: String = main.protocol.id
	if room.get("settings_protocol") != protocol:
		return false
	if not Schema.values(catalog.schema(protocol), room.common, "room").ok:
		return false
	if not catalog.validate_settings(room.main, room.settings).ok:
		return false
	for game: Variant in room.children:
		if not game is String or not room.children[game] is Dictionary or not catalog.validate_settings(game, room.children[game]).ok:
			return false
	for game: Variant in room.common_overrides:
		if not game is String or not room.common_overrides[game] is Dictionary:
			return false
		if game != room.main and not room.children.has(game):
			return false
		if not Schema.values(catalog.schema(protocol), room.common_overrides[game], "room", false, true).ok:
			return false
	return true
