## Host-only double-slot commits. Corrupt slots are errors, never silent recovery.
extends RefCounted

const Data = preload("res://core/runtime/party_data.gd")
const MAGIC: String = "GPTYSAV3"
var directory: String
var last_error: String = ""

func _init(root: String) -> void:
	directory = root

## Returns {ok, record}. An empty record means neither slot exists; errors carry a message.
func read_record(id: String) -> Dictionary:
	last_error = ""
	if not Data.identifier(id):
		return _failure("Invalid save ID: " + id)
	var latest: Dictionary = {}
	for slot: int in [0, 1]:
		var path: String = directory.path_join(id + "." + str(slot) + ".save")
		if not FileAccess.file_exists(path):
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			return _failure("Cannot read save: " + path + " · " + error_string(FileAccess.get_open_error()))
		if file.get_length() < 12 or file.get_buffer(8).get_string_from_ascii() != MAGIC:
			return _failure("Unsupported or corrupt save header: " + path)
		var length: int = file.get_32()
		if length < 4 or file.get_length() != 12 + length:
			return _failure("Incomplete save: " + path)
		var decoded: Variant = bytes_to_var(file.get_buffer(length))
		if not decoded is Dictionary or not Data.valid(decoded):
			return _failure("Invalid save payload: " + path)
		if typeof(decoded.get("revision")) != TYPE_INT or decoded.revision <= 0:
			return _failure("Invalid save revision: " + path)
		if decoded.revision > latest.get("revision", 0):
			latest = decoded
	return {"ok": true, "record": latest}

func _failure(message: String) -> Dictionary:
	last_error = message
	push_error(message)
	return {"ok": false, "message": message}

func commit(id: String, record: Dictionary) -> Error:
	last_error = ""
	if not Data.identifier(id) or not Data.valid(record):
		return ERR_INVALID_PARAMETER
	var previous: Dictionary = read_record(id)
	if not previous.ok:
		return ERR_FILE_CORRUPT
	if record.get("revision", 0) != previous.record.get("revision", 0) + 1:
		return ERR_ALREADY_IN_USE
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK:
		last_error = error_string(error)
		return error
	var path: String = directory.path_join(id + "." + str(record.revision % 2) + ".save")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = path + " · " + error_string(FileAccess.get_open_error())
		return FileAccess.get_open_error()
	var bytes: PackedByteArray = var_to_bytes(record)
	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_32(bytes.size())
	file.store_buffer(bytes)
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		last_error = "Cannot write save: " + path + " · " + error_string(error)
		return error
	var written: Dictionary = read_record(id)
	if not written.ok:
		return ERR_FILE_CORRUPT
	if written.record != record:
		_failure("Save readback differs from committed record: " + path)
		return ERR_FILE_CANT_WRITE
	return OK

## Returns {ok, records}; listing fails visibly if any saved session is unreadable.
func list_records() -> Dictionary:
	var result: Array[Dictionary] = []
	var ids: Dictionary = {}
	if not DirAccess.dir_exists_absolute(directory):
		return {"ok": true, "records": result}
	for file: String in DirAccess.get_files_at(directory):
		if file.ends_with(".save"):
			ids[file.get_slice(".", 0)] = true
	for id: String in ids:
		var loaded: Dictionary = read_record(id)
		if not loaded.ok:
			return loaded
		if not loaded.record.is_empty():
			var record: Dictionary = loaded.record
			record["save_id"] = id
			result.append(record)
	return {"ok": true, "records": result}
