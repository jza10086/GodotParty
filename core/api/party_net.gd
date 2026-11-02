## Scope-bound messaging. Successful sends are accepted locally, not remote acknowledgements.
class_name PartyNet
extends RefCounted

signal message_received(sender: Dictionary, topic: StringName, payload: Variant)
signal parent_message_received(sender: Dictionary, topic: StringName, payload: Variant)
signal child_message_received(sender: Dictionary, topic: StringName, payload: Variant)

var _dispatch: Callable
var _open: Callable
var _host: Callable
var _native_api: MultiplayerAPI
var _root: Node
var _native_base: int = 0

## Reliable convenience message to the host; callable by every active instance member.
func send_to_host(topic: StringName, payload: Dictionary) -> Error:
	return _send("host", "", topic, payload, true)

## Host-only reliable convenience broadcast. Self delivery occurs at most once.
func broadcast(topic: StringName, payload: Dictionary, include_self: bool = true) -> Error:
	if not _host.call():
		return ERR_UNAUTHORIZED
	return _send("instance", "", topic, payload, include_self)

## Sends a declared stream to one connected room member identified by persistent player ID.
func send_to_player(player_id: String, stream_id: StringName, payload: Variant) -> Error:
	return _send("player:" + player_id, stream_id, stream_id, payload, true)

## Advanced peer addressing uses the current transport peer ID, not a persistent identity.
func send_to_peer(peer_id: int, stream_id: StringName, payload: Variant) -> Error:
	return _send("peer:" + str(peer_id), stream_id, stream_id, payload, true)

## Uses the declared transfer mode and participants/spectators/instance audience.
func broadcast_stream(stream_id: StringName, payload: Variant, audience: String = "", include_self: bool = true) -> Error:
	return _send(audience, stream_id, stream_id, payload, include_self)

## Child-to-parent protocol messages route to the host parent while its view is suspended.
func send_to_parent(topic: StringName, payload: Variant) -> Error:
	return _send("parent", "", topic, payload, true)

## Host parent messages go to its current child instance, including spectators.
func send_to_child(topic: StringName, payload: Variant) -> Error:
	if not _host.call():
		return ERR_UNAUTHORIZED
	return _send("child", "", topic, payload, true)

## Native networking is not filtered by PartyNet. Do not replace its MultiplayerPeer.
func get_multiplayer_api() -> MultiplayerAPI:
	return _native_api if _open.call() else null

func get_instance_root() -> Node:
	return _root if _open.call() and is_instance_valid(_root) else null

## First reserved native channel; use only the count declared by this package.
func get_native_channel_base() -> int:
	return _native_base

func _send(target: String, stream: String, topic: StringName, payload: Variant, include_self: bool) -> Error:
	if not _open.call():
		return ERR_UNAVAILABLE
	return _dispatch.call("message", {"target": target, "stream": stream, "topic": String(topic), "payload": payload, "include_self": include_self})
