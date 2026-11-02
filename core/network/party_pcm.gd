## Fixed 16 kHz mono PCM16 frames. Streaming low-pass/resampling preserves phase across buffers.
extends RefCounted
const RATE: int = 16000
const SAMPLES: int = 320
const BYTES: int = 640
var _phase: float = 0.0
var _filtered: float = 0.0
var _second: float = 0.0
var _samples: PackedFloat32Array = []

func clear() -> void:
	_phase = 0
	_filtered = 0
	_second = 0
	_samples.clear()

func capture(frames: PackedVector2Array, source_rate: float) -> Array[PackedByteArray]:
	var output: Array[PackedByteArray] = []
	if source_rate <= 0:
		return output
	var alpha: float = 1.0 - exp(-TAU * 6000.0 / source_rate)
	for frame: Vector2 in frames:
		_filtered += alpha * ((frame.x + frame.y) * 0.5 - _filtered)
		_second += alpha * (_filtered - _second)
		_phase += RATE
		while _phase >= source_rate:
			_phase -= source_rate
			_samples.append(clampf(_second, -1.0, 1.0))
			if _samples.size() == SAMPLES:
				output.append(encode(_samples))
				_samples.clear()
	return output

static func encode(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes: PackedByteArray = []
	bytes.resize(samples.size() * 2)
	for index: int in samples.size():
		bytes.encode_s16(index * 2, int(clampf(samples[index], -1.0, 1.0) * 32767.0))
	return bytes

static func decode(bytes: PackedByteArray) -> PackedVector2Array:
	var frames: PackedVector2Array = []
	if bytes.size() != BYTES:
		return frames
	frames.resize(SAMPLES)
	for index: int in SAMPLES:
		frames[index] = Vector2.ONE * (float(bytes.decode_s16(index * 2)) / 32767.0)
	return frames
