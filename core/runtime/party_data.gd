## Internal value validation and deterministic fingerprints. Never decodes objects.
extends RefCounted

const VERSION: String = preload("res://core/framework_version.gd").VERSION
const FRAMEWORK_NAME: String = "GodotParty"
## Published platforms interoperate; editor identity is restricted to source-only internal tests.
const SYSTEM: String = "editor"
const SYSTEMS: Array[String] = ["editor", "windows", "android", "ios"]

static func valid_system(system: Variant) -> bool:
	return system is String and system in SYSTEMS

## Wire messages may use integer entity IDs as map keys; persisted state keeps string keys.
static func valid(value: Variant, depth: int = 0, integer_keys: bool = false) -> bool:
	if depth > 32:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_COLOR, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_RECT2, TYPE_RECT2I, TYPE_TRANSFORM2D, TYPE_PLANE, TYPE_QUATERNION, TYPE_AABB, TYPE_BASIS, TYPE_TRANSFORM3D, TYPE_PROJECTION, TYPE_NODE_PATH, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_VECTOR4_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for item: Variant in value:
				if not valid(item, depth + 1, integer_keys):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if (typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME] and not (integer_keys and typeof(key) == TYPE_INT)) or not valid(value[key], depth + 1, integer_keys):
					return false
			return true
	return false

static func copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value

static func canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array = value.keys()
		keys.sort()
		for key: Variant in keys:
			result[String(key)] = canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(canonical(item))
		return result
	return value

static func digest(value: Variant) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(canonical(value)))
	return context.finish().hex_encode()

static func identifier(value: String) -> bool:
	if value.is_empty() or value.length() > 96 or value.begins_with(".") or value.ends_with(".") or ".." in value:
		return false
	for character: String in value:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789_.":
			return false
	return true

static func relative_path(value: String) -> bool:
	return not value.is_empty() and not value.is_absolute_path() and not "\\" in value and not ":" in value and not ".." in value.split("/")

static func token() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

static func failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}

static func read_json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return _json_numbers(value) if value is Dictionary else {}

static func _json_numbers(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floor(value) and absf(value) < 9007199254740992.0:
		return int(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: String in value:
			result[key] = _json_numbers(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_json_numbers(item))
		return result
	return value

static func player(players: Array, id: String) -> Dictionary:
	for item: Dictionary in players:
		if item.get("player_id") == id:
			return item.duplicate(true)
	return {}

static func presentation(value: Dictionary, players: Array) -> bool:
	if not valid(value) or not value.get("rows", []) is Array or not value.get("columns", []) is Array:
		return false
	if not value.get("title", "") is String:
		return false
	var seen: Dictionary = {}
	var teams: Dictionary = {}
	for row: Variant in value.get("rows", []):
		if not row is Dictionary or typeof(row.get("rank", 0)) != TYPE_INT or row.get("rank", 0) < 0:
			return false
		if not row.get("name", "") is String or not row.get("status", "") is String:
			return false
		if row.has("members"):
			if not row.get("team_id") is String or row["team_id"].is_empty() or teams.has(row["team_id"]):
				return false
			teams[row["team_id"]] = true
		var members: Variant = row.get("members", [row.get("player_id", "")])
		if not members is Array:
			return false
		for id: Variant in members:
			if not id is String or player(players, id).is_empty() or seen.has(id):
				return false
			seen[id] = true
		if not row.get("metrics", {}) is Dictionary:
			return false
	var columns: Dictionary = {}
	for column: Variant in value.get("columns", []):
		if not column is Dictionary or not column.get("key") is String or column.get("format", "text") not in ["integer", "decimal", "text", "time"]:
			return false
		if column["key"].is_empty() or columns.has(column["key"]) or not column.get("title", "") is String:
			return false
		columns[column["key"]] = true
	return true
