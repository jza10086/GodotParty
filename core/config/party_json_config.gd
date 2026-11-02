## Sectioned JSON user data. Declarations live in business code, never in this document.
## Parsing is transactional: malformed files do not replace the previous in-memory values.
extends RefCounted
const Data = preload("res://core/runtime/party_data.gd")
var sections: Dictionary = {}
var last_error: String = ""

func load(path: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	return parse(file.get_as_text())

func parse(text: String) -> Error:
	var json: JSON = JSON.new()
	var error: Error = json.parse(text)
	if error != OK:
		last_error = "JSON line %d: %s" % [json.get_error_line(), json.get_error_message()]
		return error
	if not json.data is Dictionary:
		last_error = "JSON root must be an object"
		return ERR_INVALID_DATA
	for section: String in json.data:
		if not json.data[section] is Dictionary:
			last_error = "JSON section must be an object: " + section
			return ERR_INVALID_DATA
	sections = Data._json_numbers(json.data)
	last_error = ""
	return OK

func save(path: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(encode_to_text())
	file.flush()
	return file.get_error()

func encode_to_text() -> String:
	return JSON.stringify(sections, "\t", true, true) + "\n"

func clear() -> void:
	sections.clear()

func get_value(section: String, key: String, default: Variant = null) -> Variant:
	return sections.get(section, {}).get(key, default)

func set_value(section: String, key: String, value: Variant) -> void:
	if not sections.has(section):
		sections[section] = {}
	sections[section][key] = value

func has_section(section: String) -> bool:
	return sections.has(section)

func has_section_key(section: String, key: String) -> bool:
	return sections.has(section) and sections[section].has(key)

func get_sections() -> PackedStringArray:
	return PackedStringArray(sections.keys())

func get_section_keys(section: String) -> PackedStringArray:
	return PackedStringArray(sections[section].keys())

func erase_section_key(section: String, key: String) -> void:
	sections[section].erase(key)
