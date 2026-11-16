class_name PartyAudioCue
extends Resource
## Immutable authoring data. Each playback obtains its own stream when overriding loops.
enum LoopMode { STREAM, ENABLED, DISABLED }
@export var stream: AudioStream
@export_range(-60.0, 6.0, 0.1) var volume_db: float = -6.0
@export_range(0.25, 4.0, 0.01) var pitch_scale: float = 1.0
@export var loop_mode: LoopMode = LoopMode.STREAM
@export_range(0, 100, 1) var priority: int = 10
@export_range(1, 32, 1) var max_instances: int = 4
@export_range(0.0, 2.0, 0.01) var cooldown: float = 0.0
@export var subtitle_key: StringName

func validate() -> Error:
	if loop_mode not in LoopMode.values():
		push_error("Unknown AudioCue loop mode.")
		return ERR_INVALID_PARAMETER
	if stream == null or pitch_scale <= 0.0 or max_instances < 1:
		push_error("AudioCue requires a stream, positive pitch and at least one instance.")
		return ERR_INVALID_PARAMETER
	if loop_mode != LoopMode.STREAM and not (stream is AudioStreamWAV or stream is AudioStreamOggVorbis or stream is AudioStreamMP3):
		push_error("Loop overrides require WAV, Ogg Vorbis or MP3. Configure composite streams in their resource.")
		return ERR_INVALID_PARAMETER
	return OK

func playback_stream() -> AudioStream:
	if loop_mode == LoopMode.STREAM:
		return stream
	var copy: AudioStream = stream.duplicate()
	var enabled: bool = loop_mode == LoopMode.ENABLED
	if copy is AudioStreamWAV:
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD if enabled else AudioStreamWAV.LOOP_DISABLED
		if enabled and copy.loop_end <= copy.loop_begin:
			copy.loop_begin = 0
			copy.loop_end = roundi(copy.get_length() * copy.mix_rate)
	else:
		copy.loop = enabled
	return copy
