## Effective local preferences plus immutable room rules, injected into one game scope.
class_name PartyConfig
extends RefCounted
signal effective_changed(common_keys: PackedStringArray, own_keys: PackedStringArray)
signal failed(message: String)
const Schema = preload("res://core/config/party_schema.gd")
var _store: RefCounted
var _game: String
var _protocol: String
var _rules: Dictionary
var _value: Dictionary = {"common": {}, "own": {}, "sources": {}}
var _active: bool = false
var _open: bool = true
var effects: Dictionary = {}
var last_error: String = ""

func initialize(store: RefCounted, game: String, protocol: String, rules: Dictionary) -> Error:
	_store = store
	_game = game
	_protocol = protocol
	_rules = rules.duplicate(true)
	_store.changed.connect(_changed)
	return refresh(true)

func get_common(key: StringName, fallback: Variant = null) -> Variant:
	return _copy(_value.common.get(String(key), fallback))

func get_own(key: StringName, fallback: Variant = null) -> Variant:
	return _copy(_value.own.get(String(key), fallback))

func inspect_common(key: StringName) -> Dictionary:
	return _value.sources.get(String(key), {}).duplicate(true)

## Contains client-local values: never send this whole snapshot as room rules.
func snapshot_effective() -> Dictionary:
	return {"common": _value.common.duplicate(true), "own": _value.own.duplicate(true)}

func set_common_override(key: StringName, value: Variant) -> Error:
	return _edit("common", key, "set", value)

func clear_common_override(key: StringName) -> Error:
	return _edit("common", key, "unset")

func set_own_local(key: StringName, value: Variant) -> Error:
	return _edit("own", key, "set", value)

func clear_own_local(key: StringName) -> Error:
	return _edit("own", key, "unset")

func _edit(target: String, key: StringName, operation: String, value: Variant = null) -> Error:
	if not _open or not _active or _game.is_empty():
		return ERR_UNAVAILABLE
	var current: Dictionary = _store.read(_game)
	if current.is_empty():
		return ERR_INVALID_DATA
	return _store.commit(_game, _protocol, int(current.revision), [{"target": target, "key": String(key), "op": operation, "value": value}])

func refresh(activation: bool = false) -> Error:
	last_error = ""
	if not _open:
		return ERR_UNAVAILABLE
	var layers: Dictionary = _store.local_layers(_game, _protocol)
	if layers.is_empty():
		last_error = _store.last_error
		push_error(last_error)
		return ERR_INVALID_DATA
	var game_schema: Dictionary = _store.catalog.schema(_game) if not _game.is_empty() else Schema.empty()
	var next: Dictionary = Schema.resolve(_store.catalog.schema(_protocol), game_schema, layers.protocol, layers.own, layers.overrides, _rules)
	var changes: Array[PackedStringArray] = [PackedStringArray(), PackedStringArray()]
	var index: int = 0
	for domain: String in ["common", "own"]:
		var schema_value: Dictionary = _store.catalog.schema(_protocol) if domain == "common" else game_schema
		for key: String in next[domain]:
			var field: Dictionary = schema_value.fields[key]
			if not activation and field.audience == "local" and field.apply != "immediate":
				if _value[domain].has(key):
					next[domain][key] = _value[domain][key]
					if domain == "common":
						next.sources[key] = _value.sources[key].duplicate(true)
				effects[domain + ":" + key] = {"status": "deferred", "phase": field.apply}
			if not _value[domain].has(key) or _value[domain][key] != next[domain][key]:
				changes[index].append(key)
		index += 1
	_value = next
	if not changes[0].is_empty() or not changes[1].is_empty():
		effective_changed.emit(changes[0], changes[1])
	return OK

func close() -> void:
	_active = false
	_open = false
	if _store.changed.is_connected(_changed):
		_store.changed.disconnect(_changed)

func _changed(owner: String) -> void:
	if _active and (owner == _store.owner(_protocol) or (not _game.is_empty() and owner == _store.owner(_game))):
		if refresh() != OK:
			_active = false
			effects["configuration"] = {"status": "error", "message": last_error}
			failed.emit(last_error)

static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
