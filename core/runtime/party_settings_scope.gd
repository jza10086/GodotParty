## One activation's effect owner. Main controllers survive; their settings runtime does not.
extends RefCounted
signal failed(message: String)
var api: PartyAPI
var runtime: RefCounted
var game_root: Node
var ready: bool = false
var active: bool = false
var generation: int = 0
var last_error: String = ""

func enter(owner_api: PartyAPI, root: Node, catalog: RefCounted) -> Error:
	api = owner_api
	game_root = root
	active = true
	generation += 1
	api.config._active = true
	var error: Error = api.config.refresh(true)
	if error != OK:
		last_error = api.config.last_error
		return error
	api.input.bind_preferences(api.config, catalog.schema(api.protocol_id), catalog.schema(api.package_id), "party/" + api.scope_id)
	api.config.effective_changed.connect(_changed)
	api.config.failed.connect(_configuration_failed)
	var definition: Dictionary = catalog.get_package(api.protocol_id)
	if definition.has("settings_runtime"):
		var script: Script = catalog.resource(api.protocol_id, definition.settings_runtime)
		if script == null:
			return ERR_CANT_CREATE
		runtime = script.new()
		for hook: String in ["configure", "enter", "attach_view", "apply", "leave"]:
			if not runtime.has_method(hook):
				last_error = "设置 runtime 缺少 " + hook
				return ERR_INVALID_DATA
		runtime.configure(api)
		if not _report(runtime.enter()):
			return ERR_CANT_CREATE
	return OK

func attach(view: Node) -> bool:
	if not active:
		return false
	ready = runtime == null or _report(runtime.attach_view(view))
	return ready

func _changed(common: PackedStringArray, own: PackedStringArray) -> void:
	_apply.call_deferred(generation, common, own)

func _apply(expected: int, common: PackedStringArray, own: PackedStringArray) -> void:
	if not active or generation != expected:
		return
	if runtime != null and not _report(runtime.apply(common, own)):
		_configuration_failed(last_error)
		return
	if is_instance_valid(game_root) and game_root.has_method("party_settings_changed"):
		game_root.party_settings_changed(common, own)

func _configuration_failed(message: String) -> void:
	last_error = message
	ready = false
	api.input.input_blocked = true
	failed.emit(message)

func _report(value: Variant) -> bool:
	if not value is Dictionary or not value.get("ok") is bool:
		last_error = "设置 runtime 返回了无效报告"
		api.config.effects["runtime"] = {"status": "error", "message": last_error}
		push_error(last_error)
		return false
	for status: String in ["applied", "deferred", "unsupported"]:
		for key: String in value.get(status, []):
			api.config.effects[key] = {"status": status}
	if not value.ok:
		last_error = value.get("message", "设置应用失败")
		api.config.effects["runtime"] = {"status": "error", "message": last_error}
		push_error(last_error)
	return value.ok

func leave() -> void:
	if not active:
		return
	active = false
	ready = false
	generation += 1
	api.config._active = false
	api.input.input_blocked = true
	api.input.deactivate()
	if api.config.effective_changed.is_connected(_changed):
		api.config.effective_changed.disconnect(_changed)
	if api.config.failed.is_connected(_configuration_failed):
		api.config.failed.disconnect(_configuration_failed)
	if runtime != null:
		runtime.leave()
	runtime = null
