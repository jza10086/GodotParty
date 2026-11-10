## Optional scope-bound messages beside native RPC. OK means locally submitted, not acknowledged.
class_name PartyNet
extends RefCounted

const NATIVE_CHANNEL_MAX: int = 7
const CONTROL_CHANNEL: int = 0
const CLOCK_CHANNEL: int = 9
const MEDIA_CHANNEL: int = 10
const MESSAGE_CHANNEL_BASE: int = 11
const MESSAGE_LANES: int = 4
const CHANNEL_COUNT: int = MESSAGE_CHANNEL_BASE + MESSAGE_LANES * 3

signal message_received(sender: Dictionary, topic: StringName, payload: Variant)
signal parent_message_received(sender: Dictionary, topic: StringName, payload: Variant)
signal child_message_received(sender: Dictionary, topic: StringName, payload: Variant)
signal stats_changed()

var _dispatch: Callable
var _open: Callable
var _host: Callable
var _query: Callable
var _native_api: MultiplayerAPI
var _root: Node

## Any instance member may address the host. Mode and lane are chosen at the call site.
func send_to_host(topic: StringName, payload: Variant, mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE, channel: int = 0) -> Error:
	return _send("host", topic, payload, mode, true, channel)

## Host broadcast. Audience is instance, participants or spectators; self delivery is explicit.
func broadcast(topic: StringName, payload: Variant, mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE, include_self: bool = true, audience: String = "instance", channel: int = 0) -> Error:
	if not _host.call():
		return ERR_UNAUTHORIZED
	return send_to_group(topic, payload, mode, audience, include_self, channel)

## A participant or spectator may send to the selected group, subject to game-owned authority.
func send_to_group(topic: StringName, payload: Variant, mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE, audience: String = "instance", include_self: bool = true, channel: int = 0) -> Error:
	if audience not in ["instance", "participants", "spectators"]:
		return ERR_INVALID_PARAMETER
	return _send(audience, topic, payload, mode, include_self, channel)

func send_to_player(player_id: String, topic: StringName, payload: Variant, mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE, channel: int = 0) -> Error:
	return _send("player:" + player_id, topic, payload, mode, true, channel)

func send_to_peer(peer_id: int, topic: StringName, payload: Variant, mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE, channel: int = 0) -> Error:
	return _send("peer:" + str(peer_id), topic, payload, mode, true, channel)

func send_to_parent(topic: StringName, payload: Variant) -> Error:
	return _send("parent", topic, payload, MultiplayerPeer.TRANSFER_MODE_RELIABLE, true, 0)

func send_to_child(topic: StringName, payload: Variant) -> Error:
	if not _host.call():
		return ERR_UNAUTHORIZED
	return _send("child", topic, payload, MultiplayerPeer.TRANSFER_MODE_RELIABLE, true, 0)

## Native RPC/spawners/synchronizers use channels 0..7; no manifest declaration is needed.
func get_multiplayer_api() -> MultiplayerAPI:
	return _native_api if _open.call() else null

func get_instance_root() -> Node:
	return _root if _open.call() and is_instance_valid(_root) else null

## Native ENet mean RTT/variation for the host link; reading cached stats never sends a probe.
## age_msec tracks application traffic freshness, not the age of an individual ENet RTT sample.
func get_peer_stats(peer_id: int = 1) -> Dictionary:
	return _query.call("peer_stats", {"peer_id": peer_id}) if _open.call() else {}

## -1 before initial synchronization or after scope closure. Check freshness with is_clock_ready.
func host_time_msec() -> int:
	return _query.call("host_time", {}) if _open.call() else -1

func is_clock_ready() -> bool:
	return _open.call() and _query.call("clock_ready", {})

func _send(target: String, topic: StringName, payload: Variant, mode: MultiplayerPeer.TransferMode, include_self: bool, channel: int) -> Error:
	if not _open.call():
		return ERR_UNAVAILABLE
	if String(topic).is_empty() or mode not in [MultiplayerPeer.TRANSFER_MODE_RELIABLE, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED] or channel < 0 or channel >= MESSAGE_LANES:
		return ERR_INVALID_PARAMETER
	return _dispatch.call("message", {"target": target, "topic": String(topic), "payload": payload, "mode": mode, "channel": channel, "include_self": include_self})
