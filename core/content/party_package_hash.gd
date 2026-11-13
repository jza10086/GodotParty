## One package identity over the descriptor, actual PCK and formal external payload.
## Length-prefixed UTF-8 paths and bytes prevent ambiguous concatenation.
extends RefCounted

const Data = preload("res://core/runtime/party_data.gd")
const CHUNK: int = 1048576

static func valid(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true

static func metadata(description: Dictionary) -> PackedByteArray:
	var value: Dictionary = description.duplicate(true)
	value.erase("package_hash")
	for key: String in ["files", "external_files", "external_directories"]:
		if value.has(key):
			value[key].sort()
	if value.has("script_classes"):
		value.script_classes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["class"] < b["class"])
	return JSON.stringify(Data.canonical(Data._json_numbers(value)), "", true, true).to_utf8_buffer()

static func _length(context: HashingContext, length: int) -> Error:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_u64(0, length)
	return context.update(bytes)

static func _blob(context: HashingContext, bytes: PackedByteArray) -> Error:
	var error: Error = _length(context, bytes.size())
	return context.update(bytes) if error == OK else error

## A missing/unreadable/truncated payload is a failure, never an empty-file digest.
static func compute(directory: String, description: Dictionary) -> Dictionary:
	var context: HashingContext = HashingContext.new()
	var error: Error = context.start(HashingContext.HASH_SHA256)
	if error == OK:
		error = _blob(context, metadata(description))
	var paths: Array[String] = ["content.pck"]
	paths.append_array(description.get("external_files", []))
	paths.sort()
	for relative: String in paths:
		if error != OK:
			break
		error = _blob(context, relative.to_utf8_buffer())
		var file: FileAccess = FileAccess.open(directory.path_join(relative), FileAccess.READ)
		if file == null:
			return {"ok": false, "error": "Cannot read package payload: " + directory.path_join(relative)}
		var length: int = file.get_length()
		if error == OK:
			error = _length(context, length)
		var remaining: int = length
		while error == OK and remaining > 0:
			var bytes: PackedByteArray = file.get_buffer(mini(CHUNK, remaining))
			if bytes.is_empty():
				error = ERR_FILE_CANT_READ
				break
			remaining -= bytes.size()
			error = context.update(bytes)
		if file.get_length() != length:
			error = ERR_FILE_CANT_READ
		file.close()
	if error != OK:
		return {"ok": false, "error": "Cannot calculate package hash: " + error_string(error)}
	return {"ok": true, "hash": context.finish().hex_encode()}
