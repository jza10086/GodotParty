## Scope-bound voice control. Local preferences remain in the selected protocol's configuration.
extends RefCounted
var _backend: Node
var _scope: String
var _generation: int
var _delegated: bool = false

func initialize(backend: Node, scope: String, generation: int) -> void:
	_backend = backend
	_scope = scope
	_generation = generation

func _active() -> bool:
	return is_instance_valid(_backend) and _backend.scope == _scope and _backend.generation == _generation

## Runtime-only descriptor; never changes devices, stores preferences or grants microphone consent.
func configure_local_endpoint(options: Dictionary) -> Error:
	return _backend.configure_endpoint(options) if _active() else ERR_UNAVAILABLE

## Only the host of the active scope can change routing.
func set_policy(policy: Dictionary) -> Error:
	return _backend.set_policy(policy) if _active() else ERR_UNAVAILABLE

func update_entities(entities: Dictionary) -> Error:
	return _backend.update_entities(entities) if _active() else ERR_UNAVAILABLE

func set_route_evaluator(evaluator: Callable) -> Error:
	if not _active():
		return ERR_UNAVAILABLE
	if not _backend.connection.host:
		return ERR_UNAUTHORIZED
	_backend.route_evaluator = evaluator
	return OK

## The anchor changes local spatial presentation, never the host's audible recipient set.
func bind_anchor(player_id: String, anchor: Node) -> Error:
	return _backend.bind_anchor(player_id, anchor) if _active() else ERR_UNAVAILABLE

## Local driver lists and selections. A closed scope returns the same unavailable marker as get_status().
func get_local_devices() -> Dictionary:
	if not _active():
		return {"available": false, "reason": "inactive_scope"}
	var devices: Dictionary = _backend.settings.voice_devices()
	devices["available"] = true
	return devices

func get_status() -> Dictionary:
	return _backend.status().duplicate(true) if _active() else {"available": false, "reason": "inactive_scope"}

## Register an existing protocol-owned bus before selecting it as an endpoint.
func register_playback_bus(bus_name: String) -> Error:
	return _backend.register_bus(bus_name) if _active() else ERR_UNAVAILABLE
