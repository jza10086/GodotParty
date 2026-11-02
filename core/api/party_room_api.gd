## Public room-view context. Framework services stay in core; the main-game scene owns presentation.
extends RefCounted

var activity: PartyAPI
var _query: Callable
var _dispatch: Callable

func _init(api: PartyAPI, query: Callable, dispatch: Callable) -> void:
	activity = api
	_query = query
	_dispatch = dispatch

func get_state() -> Dictionary:
	return _query.call("state", {})

func get_game_name(id: String) -> String:
	return _query.call("game_name", {"id": id})

func ready_or_start() -> void:
	_dispatch.call("ready", {})

func leave() -> void:
	_dispatch.call("leave", {})

## Panels: pool, main, protocol, rules, system. Panels remain reusable framework UI.
func open_settings(panel: String) -> void:
	_dispatch.call("settings", {"panel": panel})

func show_player(peer: int) -> void:
	_dispatch.call("player", {"peer": peer})

func show_notice(message: String) -> void:
	_dispatch.call("notice", {"message": message})

func normalize_address(value: String) -> String:
	return _query.call("normalize_address", {"value": value})

func format_endpoint(address: String, port: int) -> String:
	return _query.call("format_endpoint", {"address": address, "port": port})
