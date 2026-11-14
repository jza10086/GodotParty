## Injected public interface. Each main game and minigame receives an independent scope.
class_name PartyAPI
extends RefCounted

signal players_changed()
## Transport departure, delivered once after the roster marks the player disconnected.
signal player_disconnected(player_id: String, peer_id: int)
signal state_committed(revision: int)
signal commit_failed(code: String, message: String)
signal round_committed(round_id: String, result: Dictionary)
signal round_cancelled(round_id: String, reason: String)

const Data = preload("res://core/runtime/party_data.gd")
const Net = preload("res://core/api/party_net.gd")
## Package-local text lookup; language preference never enters network state.
var i18n: RefCounted
var voice: RefCounted
var config: RefCounted
var net: PartyNet
var input: RefCounted
var _context: Dictionary
var _dispatch: Callable
var _query: Callable
var _closing: bool = false
var _callbacks: Array[Callable] = []

var session_id: String:
	get: return _context.get("session_id", "")
var scope_id: String:
	get: return _context.get("scope_id", "")
var round_id: String:
	get: return _context.get("round_id", "")
var package_id: String:
	get: return _context.get("package_id", "")
var protocol_id: String:
	get: return _context.get("protocol_id", "")

func _init(context: Dictionary = {}, dispatch: Callable = Callable(), query: Callable = Callable()) -> void:
	_context = context.duplicate(true)
	_dispatch = dispatch
	_query = query
	net = Net.new()
	net._dispatch = _invoke
	net._open = is_open
	net._host = is_host
	# A lambda captures this RefCounted strongly and creates an API -> net -> API cycle.
	net._query = _net_query

func _net_query(key: String, argument: Dictionary) -> Variant:
	return _query.call(scope_id, key, argument)

func is_host() -> bool:
	return _context.get("is_host", false)

func is_open() -> bool:
	return not _closing and _dispatch.is_valid()

## Returns participants, including disconnected players. Mutating this copy changes no framework state.
func get_players() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(_read("players", []))
	return result

func get_room_players() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(_read("room_players", []))
	return result

func get_spectators() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(_read("spectators", []))
	return result

## The protocol defines all fields. Unknown identities return an empty dictionary.
func get_appearance(player_id: String) -> Dictionary:
	return Data.copy(_read("appearances", {}).get(player_id, {}))

func get_settings() -> Dictionary:
	return _context.get("settings", {}).duplicate(true)

func get_pool(name: String) -> Array:
	return _context.get("pools", {}).get(name, []).duplicate()

func get_minigame_settings(id: String) -> Dictionary:
	return _read("child_settings", {}).get(id, {}).duplicate(true)

func get_seed() -> int:
	return _context.get("seed", 0)

## Load an asset in the room dependency closure, activating its package on first use.
func load_asset(ref: Dictionary) -> Resource:
	if not is_open():
		return null
	return _query.call(scope_id, "asset", ref)

## Metadata from the host's frozen dependency set, without loading resources.
func get_asset_libraries(special_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(_query.call(scope_id, "asset_libraries", {"type": special_type}) if is_open() else [])
	return result

## Await the selected asset; a closed activity never receives the late result.
func load_asset_async(ref: Dictionary) -> Resource:
	if not is_open():
		return null
	var value: Resource = await _query.call(scope_id, "asset_async", ref)
	return value if is_open() else null

## Absolute path under external/ in the artifact frozen for this process.
## Use FileAccess/DirAccess or runtime media loaders; this does not create or modify files.
func get_external_path(relative: String) -> String:
	if not is_open():
		push_error("Cannot resolve external data for a closed PartyAPI")
		return ""
	return _query.call(scope_id, "external_path", {"path": relative})

## Read-only technical preparation snapshot for this scope, never a user confirmation.
## Scope/session identify the generation; closed APIs return an empty dictionary.
func get_preparation_status() -> Dictionary:
	return _read("preparation_status", {})

## Explicit local readiness; repeated reports are OK only while preparing.
func mark_ready() -> Error:
	return _invoke("ready", {})

## Host minigame only. OK accepts a candidate; persistence completes asynchronously.
## Identical accepted results are idempotent; different candidates conflict.
func finish(result: Dictionary) -> Error:
	return _invoke("finish", {"result": result})

## Main host only. State is applied/broadcast only after a durable commit.
func commit_state(next_state: Dictionary) -> Error:
	return _invoke("commit", {"state": next_state})

## Main host only. Empty participants selects connected main-game players.
func request_minigame(id: String, request: Dictionary, participants: Array[String] = []) -> Error:
	return _invoke("request", {"id": id, "request": request, "participants": participants})

## Main host only. Persist the terminal session and optional author-owned presentation.
func finish_session(presentation: Dictionary = {}) -> Error:
	return _invoke("end", {"presentation": presentation})

## Main host only. Owns in-game Tab order/metrics and the F3 overview; core infers no business values.
func publish_standings(presentation: Dictionary) -> Error:
	return _invoke("standings", {"presentation": presentation})

## Last durable minigame result converted by the selected protocol; empty when unavailable.
func get_round_presentation() -> Dictionary:
	return _read("round_presentation", {})

## Opens the common results view locally. Does not publish ranks, pause peers or change state.
func show_results(presentation: Dictionary) -> Error:
	return _invoke("show_results", {"presentation": presentation})

## Shows a local framework notification for three seconds. New notices replace the current one.
## Available to protocol runtimes, main games and minigames; does not broadcast or alter focus.
func show_notice(message: String) -> Error:
	if message.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	return _invoke("notice", {"message": message})

## Report a recoverable failure; the host coordinates cancellation.
func fail(code: String, message: String) -> Error:
	return _invoke("fail", {"code": code, "message": message})

## Registers synchronous tree-external cleanup, executed LIFO while nodes still exist.
func on_close(callback: Callable) -> Error:
	if not is_open() or not callback.is_valid():
		return ERR_UNAVAILABLE
	_callbacks.append(callback)
	return OK

func _read(key: String, fallback: Variant) -> Variant:
	return Data.copy(_query.call(scope_id, key, {}) if is_open() else fallback)

func _invoke(operation: String, payload: Dictionary) -> Error:
	if not is_open():
		return ERR_UNAVAILABLE
	if not Data.valid(payload, 0, operation == "message"):
		return ERR_INVALID_PARAMETER
	return _dispatch.call(scope_id, operation, payload)

func _begin_close() -> void:
	_closing = true
	if config != null:
		config.close()
	if input != null:
		input.set("input_blocked", true)

func _cleanup() -> void:
	for index: int in range(_callbacks.size() - 1, -1, -1):
		if _callbacks[index].is_valid():
			_callbacks[index].call()
	_callbacks.clear()
	_dispatch = Callable()
	_query = Callable()

## Display name from the active content catalog, independent of game-specific ID tables.
func get_game_name(id: String) -> String:
	return _query.call(scope_id, "game_name", {"id": id})
