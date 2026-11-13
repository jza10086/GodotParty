## Exact participant counts and declarative room-setting restrictions shared by lobby and rounds.
## Counts are sets, never a min/max envelope: holes such as 1, 3, 6 remain meaningful.
extends RefCounted

const Schema = preload("res://core/config/party_schema.gd")
const ALL: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]

static func valid_counts(value: Variant) -> bool:
	if not value is Array or value.is_empty():
		return false
	var seen: Array[int] = []
	for count: Variant in value:
		if not (count is int or count is float) or not is_finite(float(count)):
			return false
		if float(count) != floor(float(count)) or count < 1 or count > 8 or int(count) in seen:
			return false
		seen.append(int(count))
	return true

## Manifest declarations are mandatory for executable packages; obsolete bounds are rejected.
static func validate(manifest: Dictionary) -> String:
	if manifest.has("min_players") or manifest.has("max_players"):
		return "Use player_counts instead of min_players/max_players"
	if manifest.get("kind") not in ["avatars", "assets"] and not valid_counts(manifest.get("player_counts")):
		return "player_counts must be a nonempty set of integers between 1 and 8"
	var rules: Variant = manifest.get("player_count_rules", [])
	if not rules is Array:
		return "player_count_rules must be an array"
	for rule: Variant in rules:
		if not rule is Dictionary or not rule.get("when") is Dictionary or rule.when.is_empty() or not valid_counts(rule.get("counts")):
			return "Each player count rule requires nonempty when and counts"
	return ""

## Conditions use this package's own room fields, never local preferences or another game's rules.
static func validate_fields(manifest: Dictionary, schema: Dictionary) -> String:
	for rule: Dictionary in manifest.get("player_count_rules", []):
		for key: Variant in rule.when:
			if not key is String:
				return "Player count condition key must be a string"
			var field: Dictionary = schema.get("fields", {}).get(key, {})
			if field.get("audience") != "room" or not Schema.normalize(field, rule.when[key]).ok:
				return "Invalid player count room condition: " + key
	return ""

static func intersect(left: Array[int], right: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for count: int in ALL:
		if count in left and count in right:
			result.append(count)
	return result

## Every matching rule narrows the static set; rules can never add unsupported counts.
static func package_counts(manifest: Dictionary, settings: Dictionary) -> Array[int]:
	var result: Array[int] = []
	if not validate(manifest).is_empty():
		return result
	for count: Variant in manifest.get("player_counts", []):
		result.append(int(count))
	result.sort()
	for rule: Dictionary in manifest.get("player_count_rules", []):
		var matches: bool = true
		for key: String in rule.when:
			if not settings.has(key) or settings[key] != rule.when[key]:
				matches = false
				break
		if matches:
			var restriction: Array[int] = []
			for count: Variant in rule.counts:
				restriction.append(int(count))
			result = intersect(result, restriction)
	return result

## Resolve protocol defaults/base/overrides and game defaults/own rules without local preferences.
static func game_counts(room: Dictionary, game: String, catalog: RefCounted) -> Array[int]:
	var main: Dictionary = catalog.get_package(room.get("main", ""))
	var protocol_id: String = main.get("protocol", {}).get("id", "")
	var protocol: Dictionary = catalog.get_package(protocol_id)
	var definition: Dictionary = catalog.get_package(game)
	if main.is_empty() or protocol.is_empty() or definition.is_empty():
		return []
	var common: Dictionary = catalog.defaults(protocol_id)
	common.merge(room.get("common", {}), true)
	common.merge(room.get("common_overrides", {}).get(game, {}), true)
	var own: Dictionary = catalog.defaults(game)
	own.merge(room.get("settings", {}) if game == room.main else room.get("children", {}).get(game, {}), true)
	return intersect(package_counts(protocol, common), package_counts(definition, own))

## All selected pool entries constrain the lobby; unselected drafts and installed games do not.
static func room_counts(room: Dictionary, catalog: RefCounted) -> Array[int]:
	var result: Array[int] = game_counts(room, room.get("main", ""), catalog)
	var seen: Array[String] = []
	for pool: Array in room.get("pools", {}).values():
		for game: String in pool:
			if game not in seen:
				seen.append(game)
				result = intersect(result, game_counts(room, game, catalog))
	return result

static func describe(counts: Array[int]) -> String:
	if counts.is_empty():
		return "无可用人数"
	var parts: PackedStringArray = []
	var index: int = 0
	while index < counts.size():
		var first: int = counts[index]
		var last: int = first
		while index + 1 < counts.size() and counts[index + 1] == last + 1:
			index += 1
			last = counts[index]
		parts.append(str(first) if first == last else "%d–%d" % [first, last])
		index += 1
	return "、".join(parts) + " 人"
