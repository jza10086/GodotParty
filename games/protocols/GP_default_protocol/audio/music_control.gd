## Local music policy of one foreground game using the default protocol.
class_name PartyDefaultMusicControl
extends Node

const Mixer = preload("res://games/protocols/GP_default_protocol/audio/audio_mixer.gd")
enum State { SILENT, BACKGROUND, GAMEPLAY }
signal state_changed(state: State)

var state: State = State.SILENT
var _mixer: Mixer
var _audio: PartyGameAudio

## Available on the child root when PartyAPI.foreground_child_attached is delivered.
static func for_game(root: Node) -> PartyDefaultMusicControl:
	return root.get_node(^"PartyDefaultMusicControl")

func attach(root: Node, mixer: Mixer, audio: PartyGameAudio) -> void:
	name = &"PartyDefaultMusicControl"
	_mixer = mixer
	_audio = audio
	if root.is_in_group(&"party_gameplay_music"):
		state = State.GAMEPLAY
	elif _audio != null:
		_audio.playback_started.connect(_started)
		_audio.playback_ended.connect(_ended)
		_refresh_background()
	root.add_child(self)

## Suppress only replaceable music. Keep playback, completion and the user's gain intact.
func set_background_muted(muted: bool) -> void:
	if state != State.GAMEPLAY:
		_mixer.set_music_suppressed(muted)

func _started(_handle: PartyAudioHandle, _cue: PartyAudioCue, category: PartyGameAudio.Category) -> void:
	if category == PartyGameAudio.Category.MUSIC:
		_set_state(State.BACKGROUND)

func _ended(_handle: PartyAudioHandle, _cue: PartyAudioCue, category: PartyGameAudio.Category, _reason: PartyAudioHandle.EndReason) -> void:
	if category == PartyGameAudio.Category.MUSIC:
		_refresh_background()

func _refresh_background() -> void:
	_set_state(State.BACKGROUND if _audio.status().playing.music > 0 else State.SILENT)

func _set_state(value: State) -> void:
	if state != value:
		state = value
		state_changed.emit(state)

func _exit_tree() -> void:
	_mixer.set_music_suppressed(false)
