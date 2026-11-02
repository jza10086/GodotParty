## Business-owned declarations and pure JSON value validation. No UI or file side effects.
extends RefCounted
const TYPES: Array[String] = ["bool", "int", "float", "string", "array", "object"]
const CONTROLS: Array[String] = ["toggle", "select", "text", "number", "numbers", "switches", "color", "path", "binding"]
static func empty() -> Dictionary:
	return {"schema_format": 3, "settings_version": 1, "fields": {}, "layout": []}

static func control_for(field: Dictionary) -> String:
	return field.get("control", {"bool": "toggle", "int": "number", "float": "number", "string": "text", "array": "numbers", "object": "text"}[field.type])

static func validate(schema: Dictionary, kind: String) -> String:
	if schema.get("schema_format") != 3 or not schema.get("settings_version") is int or schema.settings_version < 1 or not schema.get("fields") is Dictionary or not schema.get("layout") is Array:
		return "Expected code declaration schema 3 with fields and layout"
	for key: Variant in schema.fields:
		var field: Variant = schema.fields[key]
		if not key is String or key.is_empty() or not field is Dictionary:
			return "Invalid field"
		if field.get("audience") not in ["local", "room"]:
			return key + ": invalid audience"
		var stages: Array = ["immediate", "next_activation", "restart"] if field.audience == "local" else ["lobby", "next_round"]
		if field.get("apply") not in stages or (kind == "maingame" and field.audience == "room" and field.apply != "lobby"):
			return key + ": invalid application phase"
		if kind == "protocols" and not field.get("overridable") is bool:
			return key + ": overridable must be explicit"
		var issue: String = validate_field(field)
		if not issue.is_empty():
			return key + ": " + issue
		var rendered: Dictionary = field.duplicate(true)
		rendered.control = control_for(field)
		issue = validate_field(rendered)
		if not issue.is_empty():
			return key + ": " + issue
		if not normalize(field, field.get("default")).ok:
			return key + ": invalid default"
		if control_for(field) == "binding" and not field.get("readonly", false):
			if field.audience != "local" or not field.get("action") is String or field.action.is_empty() or field.action.begins_with("ui_"):
				return key + ": invalid logical action"
	var seen: Array[String] = []
	var groups: Array[String] = []
	var issue: String = _validate_layout(schema.layout, schema.fields, seen, groups)
	if not issue.is_empty():
		return issue
	return "" if seen.size() == schema.fields.size() else "Every field must appear once in layout"

static func validate_field(field: Dictionary) -> String:
	if field.get("type") not in TYPES:
		return "Unknown primitive type"
	for key: String in ["title", "description", "suffix", "placeholder"]:
		if field.has(key) and not field[key] is String:
			return key + " must be a string"
	if field.has("control"):
		if field.control not in CONTROLS:
			return "Unknown control"
		var allowed: Dictionary = {"toggle": ["bool"], "select": ["string", "int", "float", "array"], "text": ["string"], "number": ["int", "float"], "numbers": ["array"], "switches": ["array"], "color": ["array"], "path": ["string"], "binding": ["array"]}
		if field.type not in allowed[field.control]:
			return "Control and value type disagree"
	if field.type in ["int", "float"]:
		for key: String in ["min", "max", "step"]:
			if field.has(key) and (not _number(field[key]) or (field.type == "int" and float(field[key]) != floor(float(field[key])))):
				return "Invalid numeric " + key
		if field.get("min", -INF) > field.get("max", INF) or field.get("step", 1) <= 0:
			return "Invalid numeric range"
	if field.has("values"):
		if not field.values is Array or field.values.is_empty():
			return "Nonempty candidate values required"
		var seen: Array = []
		for candidate: Variant in field.values:
			if candidate in seen:
				return "Duplicate candidate"
			seen.append(candidate)
	if field.type == "array":
		if not field.get("items") is Dictionary:
			return "Array item declaration required"
		var issue: String = validate_field(field.items)
		if not issue.is_empty():
			return issue
		if field.get("min_items", 0) < 0 or field.get("max_items", 1024) < field.get("min_items", 0):
			return "Invalid array length"
	if field.type == "object" and field.get("format") != "binding":
		if not field.get("properties") is Dictionary:
			return "Object properties required"
		for property: Dictionary in field.properties.values():
			var issue: String = validate_field(property)
			if not issue.is_empty():
				return issue
	for key: String in ["readonly", "overridable", "multiline", "alpha", "unique", "ordered", "combinations"]:
		if field.has(key) and not field[key] is bool:
			return key + " must be boolean"
	for key: String in ["min_items", "max_items", "max_length"]:
		if field.has(key) and (not field[key] is int or field[key] < 0):
			return key + " must be a nonnegative integer"
	if field.has("display_scale") and (not _number(field.display_scale) or field.display_scale <= 0):
		return "display_scale must be positive"
	if field.has("labels") and (not field.labels is Array or not field.labels.all(func(label: Variant) -> bool: return label is String)):
		return "labels must be strings"
	if field.has("values"):
		var base: Dictionary = field.duplicate(true)
		base.erase("values")
		for candidate: Variant in field.values:
			if not normalize(base, candidate).ok:
				return "Candidate has wrong type"
		if field.has("labels") and field.labels.size() != field.values.size():
			return "Candidate labels do not match values"
	match field.get("control", ""):
		"select":
			if not field.has("values"):
				return "Dropdown requires values"
		"numbers":
			if field.items.type not in ["int", "float"] or field.get("min_items", 0) < 1 or field.get("min_items") != field.get("max_items"):
				return "Numeric components require fixed length and numeric items"
		"switches":
			if field.items.type not in ["string", "int"] or not field.items.has("values"):
				return "Switch group requires enumerated items"
		"color":
			if field.items.type != "float" or field.items.get("min") != 0 or field.items.get("max") != 1 or field.get("min_items") != 4 or field.get("max_items") != 4:
				return "Color requires four float channels in [0,1]"
		"binding":
			if field.items.get("format") != "binding" or field.get("max_items") != 2:
				return "Binding requires primary and alternate slots"
		"path":
			if field.get("path_mode", "file") not in ["file", "directory"] or not field.get("filters", []) is Array:
				return "Invalid path chooser"
			for filter: Variant in field.get("filters", []):
				if not filter is String:
					return "File filters must be strings"
	return ""

static func _validate_layout(nodes: Array, fields_value: Dictionary, seen: Array[String], groups: Array[String], depth: int = 0) -> String:
	if depth > 3:
		return "Layout supports categories followed by at most three row levels"
	for node: Variant in nodes:
		if not node is Dictionary:
			return "Layout node must be an object"
		if node.has("field"):
			if not node.field is String or not fields_value.has(node.field) or node.field in seen:
				return "Unknown or repeated layout field"
			seen.append(node.field)
		else:
			if not node.get("id") is String or node.id.is_empty() or node.id in groups or not node.get("children") is Array or not node.get("title") is String:
				return "Invalid group"
			groups.append(node.id)
		if node.has("children"):
			if not node.children is Array:
				return "Layout children must be an array"
			var issue: String = _validate_layout(node.children, fields_value, seen, groups, depth + 1)
			if not issue.is_empty():
				return issue
		if node.has("enabled_when"):
			var condition: Variant = node.enabled_when
			if not condition is Dictionary or not condition.get("field") is String or not fields_value.has(condition.field) or not condition.has("equals") or not normalize(fields_value[condition.field], condition.equals).ok:
				return "Invalid enabled_when condition"
			if node.get("field") == condition.field:
				return "A field cannot disable itself"
	return ""

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func normalize(field: Dictionary, value: Variant) -> Dictionary:
	var valid: bool = false
	match field.get("type"):
		"bool": valid = value is bool
		"int", "float":
			valid = _number(value) and value >= field.get("min", -INF) and value <= field.get("max", INF)
			if valid and field.type == "int":
				valid = float(value) == floor(float(value)) and absf(float(value)) < 9007199254740992.0
			if valid:
				value = int(value) if field.type == "int" else float(value)
		"string":
			valid = value is String and value.length() <= field.get("max_length", 4096)
		"array":
			valid = value is Array and value.size() >= field.get("min_items", 0) and value.size() <= field.get("max_items", 1024)
			if valid:
				var output: Array = []
				for item: Variant in value:
					var checked: Dictionary = normalize(field.items, item)
					if not checked.ok or ((field.get("unique", false) or field.get("control") == "switches") and checked.value in output):
						valid = false
						break
					output.append(checked.value)
				value = output
				if valid and field.get("ordered", false):
					for index: int in range(1, value.size()):
						if value[index - 1] > value[index]:
							valid = false
				if valid and field.get("control") == "color":
					valid = value.size() == 4 and (field.get("alpha", true) or value[3] == 1.0)
		"object":
			if field.get("format") == "binding":
				return _binding(value)
			valid = value is Dictionary and value.size() == field.properties.size()
			if valid:
				var output: Dictionary = {}
				for key: String in field.properties:
					var checked: Dictionary = normalize(field.properties[key], value.get(key))
					if not checked.ok:
						valid = false
						break
					output[key] = checked.value
				value = output
	if valid and field.has("values"):
		valid = value in field.values
	if valid and field.get("control") == "binding":
		valid = value.size() <= 2 and not (value.size() == 2 and not value[0].is_empty() and value[0] == value[1])
		if valid and not field.get("readonly", false):
			valid = value.all(func(binding: Dictionary) -> bool: return binding.is_empty() or binding.kind != "key" or binding.code != KEY_ESCAPE)
	return {"ok": valid, "value": value, "message": "" if valid else "Invalid type, range or value"}

static func _binding(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false, "value": value, "message": "Binding must be an object"}
	if value.is_empty():
		return {"ok": true, "value": {}, "message": ""}
	var valid: bool = value.get("kind") in ["key", "mouse"] and _number(value.get("code"))
	if valid:
		valid = value.code > 0 and float(value.code) == floor(float(value.code)) and value.code < 9007199254740992.0
	if valid:
		valid = (value.kind == "mouse" and value.code <= 9) or (value.kind == "key" and value.get("physical") is bool)
	for modifier: String in ["ctrl", "alt", "shift", "meta"]:
		if value.has(modifier) and not value[modifier] is bool:
			valid = false
	if valid:
		value = value.duplicate(true)
		value.code = int(value.code)
		for modifier: String in ["ctrl", "alt", "shift", "meta"]:
			if value.get(modifier) == false:
				value.erase(modifier)
	return {"ok": valid, "value": value, "message": "" if valid else "Invalid key or modifiers"}

static func defaults(schema: Dictionary, audience: String) -> Dictionary:
	var result: Dictionary = {}
	for key: String in schema.get("fields", {}):
		var field: Dictionary = schema.fields[key]
		if field.audience == audience:
			result[key] = normalize(field, field.default).value
	return result

static func values(schema: Dictionary, supplied: Dictionary, audience: String, fill: bool = true, overrides: bool = false) -> Dictionary:
	var result: Dictionary = defaults(schema, audience) if fill else {}
	for key: String in supplied:
		var field: Dictionary = schema.get("fields", {}).get(key, {})
		if field.is_empty() or field.audience != audience or (overrides and not field.get("overridable", false)) or field.get("readonly", false):
			return {"ok": false, "message": key + ": unknown, wrong audience or not overridable"}
		var item: Dictionary = normalize(field, supplied[key])
		if not item.ok:
			return {"ok": false, "message": key + ": " + item.message}
		result[key] = item.value
	return {"ok": true, "value": result}

static func fields(schema: Dictionary, audience: String) -> Array:
	var result: Array = []
	for key: String in schema.get("fields", {}):
		var field: Dictionary = schema.fields[key].duplicate(true)
		if field.audience == audience:
			field["key"] = key
			field["options"] = field.get("values", [])
			result.append(field)
	return result

## Resolve only the selected protocol branch. Existence, never truthiness, controls inheritance.
static func resolve(protocol: Dictionary, game: Dictionary, protocol_values: Dictionary, own_values: Dictionary, overrides: Dictionary, rules: Dictionary) -> Dictionary:
	var common: Dictionary = defaults(protocol, "local")
	var own: Dictionary = defaults(game, "local")
	var sources: Dictionary = {}
	for key: String in common:
		var base: Variant = protocol_values.get(key, common[key])
		common[key] = overrides.get(key, base)
		sources[key] = {"value": common[key], "protocol_base": base, "source": "game_override" if overrides.has(key) else ("protocol_user" if protocol_values.has(key) else "protocol_default"), "overridden": overrides.has(key), "audience": "local", "apply": protocol.fields[key].apply}
	own.merge(own_values, true)
	common.merge(rules.get("common", {}), true)
	own.merge(rules.get("own", {}), true)
	for key: String in rules.get("common", {}):
		sources[key] = {"value": common[key], "protocol_base": rules.get("base", {}).get(key, common[key]), "source": "room_game_override" if key in rules.get("overrides", {}) else "room_base", "overridden": key in rules.get("overrides", {}), "audience": "room", "apply": protocol.fields[key].apply}
	return {"common": common, "own": own, "sources": sources}
