## Shared sorting, formatting and palette helpers for leaderboard templates.
extends RefCounted

const COLOR_GOLD: Color = Color("#f4d06f")
const COLOR_SILVER: Color = Color("#d5dde8")
const COLOR_BRONZE: Color = Color("#dfa578")
const COLOR_TEXT: Color = Color("#eef3f8")
const COLOR_MUTED: Color = Color("#95a0ad")
const COLOR_POSITIVE: Color = Color("#79e5ad")
const COLOR_NEGATIVE: Color = Color("#ff787c")

## Parse an explicitly supplied Color or hex color string; returns null otherwise.
static func parse_color(value: Variant) -> Variant:
	if value is Color:
		return value
	if value is String and not value.is_empty() and Color.html_is_valid(value):
		return Color.from_string(value, COLOR_TEXT)
	return null

## Extract a non-negative integer rank; 0 means unranked.
static func parse_rank(row: Dictionary) -> int:
	var value: Variant = row.get("rank", 0)
	if value is int or (value is float and is_finite(value) and value == floor(value)):
		return maxi(0, int(value))
	return 0

## Stable ascending sort by rank; rank 0 entries stay at the end in original order.
static func sort_rows(source: Variant) -> Array[Dictionary]:
	var indexed: Array[Dictionary] = []
	if source is Array:
		for index: int in source.size():
			if source[index] is Dictionary:
				indexed.append({"row": source[index], "order": index})
	indexed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var first: int = parse_rank(a["row"])
		var second: int = parse_rank(b["row"])
		if first == second:
			return int(a["order"]) < int(b["order"])
		if first == 0 or second == 0:
			return second == 0
		return first < second)
	var ordered: Array[Dictionary] = []
	for item: Dictionary in indexed:
		ordered.append(item["row"])
	return ordered

static func rank_text(rank_value: int) -> String:
	return "—" if rank_value <= 0 else str(rank_value)

static func rank_color(rank_value: int) -> Color:
	match rank_value:
		1: return COLOR_GOLD
		2: return COLOR_SILVER
		3: return COLOR_BRONZE
	return COLOR_TEXT

## Format an integer with comma grouping separators.
static func format_integer(value: int) -> String:
	var raw: String = str(absi(value))
	var grouped: String = ""
	for index: int in raw.length():
		if index > 0 and (raw.length() - index) % 3 == 0:
			grouped += ","
		grouped += raw[index]
	return ("-" if value < 0 else "") + grouped

## Format a metric value by declared format ("integer", "decimal", "time", "text").
static func format_metric(value: Variant, format: String) -> String:
	if value == null:
		return "—"
	if not value is int and not value is float:
		return str(value)
	match format:
		"integer": return format_integer(int(value))
		"decimal": return "%.2f" % float(value)
		"time":
			var total_ms: int = maxi(0, int(value))
			return "%02d:%05.2f" % [total_ms / 60000, fmod(float(total_ms) / 1000.0, 60.0)]
	return str(value)

## Format a numeric delta with explicit sign; returns empty string for zero or non-numeric.
static func format_delta(value: Variant, format: String) -> String:
	if not value is int and not value is float:
		return ""
	var numeric: float = float(value)
	if is_zero_approx(numeric):
		return ""
	var sign_prefix: String = "+" if numeric > 0.0 else "-"
	match format:
		"integer": return sign_prefix + format_integer(absi(int(value)))
		"decimal": return sign_prefix + ("%.2f" % absf(numeric))
		"time": return sign_prefix + format_metric(absi(int(value)), "time")
	return sign_prefix + str(absf(numeric))

## Build a player_id -> player metadata dictionary from a room player snapshot array.
static func index_players(players: Array) -> Dictionary[String, Dictionary]:
	var lookup: Dictionary[String, Dictionary] = {}
	for player: Variant in players:
		if not player is Dictionary:
			continue
		var id: Variant = player.get("player_id")
		if id is String and not id.is_empty():
			lookup[id] = player
	return lookup

## Resolve row display name from explicit row.name, team members, or player lookup.
static func resolve_name(row: Dictionary, player_lookup: Dictionary[String, Dictionary]) -> String:
	var explicit: Variant = row.get("name")
	if explicit is String and not explicit.is_empty():
		return explicit
	var members: Variant = row.get("members")
	if members is Array and not members.is_empty():
		var parts: PackedStringArray = []
		for member_id: Variant in members:
			if member_id is String:
				var info: Dictionary = player_lookup.get(member_id, {})
				parts.append(str(info.get("name", member_id)))
		if not parts.is_empty():
			return " / ".join(parts)
	var id: String = str(row.get("player_id", ""))
	if player_lookup.has(id):
		return str(player_lookup[id].get("name", "—"))
	return "—"
