## Estimates host monotonic time from application ping/pong; never changes simulation delta.
extends RefCounted
const MAX_SAMPLE_AGE_MSEC: int = 5000
const SLEW_MSEC_PER_SECOND: float = 20.0
var _host: bool = false
var _ready: bool = false
var _offset: float = 0.0
var _target: float = 0.0
var _last_sample: int = 0
var _last_time: int = -1
var _samples: Array[Dictionary] = []

func reset(is_host: bool) -> void:
	_host = is_host
	_ready = is_host
	_offset = 0.0
	_target = 0.0
	_last_sample = 0
	_last_time = -1
	_samples.clear()

func advance(delta: float) -> void:
	if _ready and not _host:
		_offset = move_toward(_offset, _target, maxf(delta, 0.0) * SLEW_MSEC_PER_SECOND)

## Four timestamps remove reply processing time. Lower RTT samples reduce queue bias.
func observe(sent: int, remote_received: int, remote_sent: int, received: int) -> void:
	var rtt: int = received - sent - (remote_sent - remote_received)
	if rtt < 0 or rtt > 2000:
		return
	var offset: float = (float(remote_received - sent) + float(remote_sent - received)) * 0.5
	_samples.append({"rtt": rtt, "offset": offset, "received": received})
	while _samples.size() > 8 or (not _samples.is_empty() and received - int(_samples[0].received) > MAX_SAMPLE_AGE_MSEC):
		_samples.pop_front()
	var best: Dictionary = _samples[0]
	for sample: Dictionary in _samples:
		if sample.rtt < best.rtt:
			best = sample
	_target = best.offset
	if not _ready:
		_offset = _target
	_ready = true
	_last_sample = received

func is_ready() -> bool:
	return _host or (_ready and Time.get_ticks_msec() - _last_sample <= MAX_SAMPLE_AGE_MSEC)

## -1 means no initial estimate. Afterwards time remains monotonic while samples stall.
func now_msec() -> int:
	if not _ready:
		return -1
	_last_time = maxi(_last_time, Time.get_ticks_msec() + roundi(_offset))
	return _last_time
