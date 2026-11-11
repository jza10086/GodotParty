## Public room-view context. Framework services stay in core; the main-game scene owns presentation.
extends RefCounted

var i18n: RefCounted
var activity: PartyAPI
var _query: Callable
var _dispatch: Callable

func _init(api: PartyAPI, query: Callable, dispatch: Callable) -> void:
	activity = api
	i18n = api.i18n
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

## Panels: pool, main, preferences (main-game local settings), protocol, rules, system. Panels remain reusable framework UI.
func open_settings(panel: String) -> void:
	_dispatch.call("settings", {"panel": panel})

## Apply a partial main-game rule update through the host lobby configuration flow.
## Other room rules and selected pools are preserved; failures are shown by the framework.
func update_main_settings(values: Dictionary) -> void:
	_dispatch.call("main_settings", {"values": values})

func show_player(peer: int) -> void:
	_dispatch.call("player", {"peer": peer})

func show_notice(message: String) -> void:
	_dispatch.call("notice", {"message": message})

## Normalize IPv4, IPv6 (optionally bracketed) or an ASCII / Punycode DNS hostname.
## This accepts an address without a port; invalid input returns an empty string.
func normalize_address(value: String) -> String:
	return _query.call("normalize_address", {"value": value})

func format_endpoint(address: String, port: int) -> String:
	return _query.call("format_endpoint", {"address": address, "port": port})
