class_name PartyAudioHandle
extends RefCounted
## One playback identity, retained safely after its player is reused or its scope closes.
enum EndReason { COMPLETED, STOPPED, REPLACED, STOLEN, DROPPED, SCOPE_CLOSED, INVALID_CUE }
signal ended(reason: EndReason)
var id: int
var error: Error = OK
var is_done: bool = false
var reason: EndReason = EndReason.COMPLETED
var _stop: Callable

func stop(fade_seconds: float = 0.0) -> void:
	if not is_done:
		_stop.call(self, maxf(0.0, fade_seconds))

func wait_end() -> EndReason:
	if not is_done:
		await ended
	return reason

func complete(value: EndReason) -> void:
	if is_done:
		return
	is_done = true
	reason = value
	_stop = Callable()
	# Notify after the pool mutation finishes; an await continuation may start another cue.
	ended.emit.call_deferred(reason)
