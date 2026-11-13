## Exact three-component versions and the supported exact, tilde and caret dependency ranges.
extends RefCounted

static func parse(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if not value is String:
		return result
	var parts: PackedStringArray = value.split(".")
	if parts.size() != 3:
		return result
	for part: String in parts:
		if part.is_empty() or (part.length() > 1 and part.begins_with("0")):
			return []
		for character: String in part:
			if character not in "0123456789":
				return []
		if part.length() > 19 or (part.length() == 19 and part > "9223372036854775807"):
			return []
		result.append(part.to_int())
	return result

static func valid_range(value: Variant) -> bool:
	if not value is String or value.is_empty():
		return false
	return not parse(value.substr(1) if value[0] in ["~", "^"] else value).is_empty()

static func compare(left: Array[int], right: Array[int]) -> int:
	for index: int in 3:
		if left[index] < right[index]:
			return -1
		if left[index] > right[index]:
			return 1
	return 0

static func matches(version: String, requirement: String) -> bool:
	var actual: Array[int] = parse(version)
	if actual.is_empty() or not valid_range(requirement):
		return false
	var operator: String = requirement[0]
	var minimum: Array[int] = parse(requirement.substr(1) if operator in ["~", "^"] else requirement)
	if operator not in ["~", "^"]:
		return compare(actual, minimum) == 0
	if compare(actual, minimum) < 0:
		return false
	if operator == "~":
		return actual[0] == minimum[0] and actual[1] == minimum[1]
	if minimum[0] > 0:
		return actual[0] == minimum[0]
	if minimum[1] > 0:
		return actual[0] == 0 and actual[1] == minimum[1]
	return compare(actual, minimum) == 0
