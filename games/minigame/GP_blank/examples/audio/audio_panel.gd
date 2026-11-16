extends Control
## Local audio demonstration. Only explicit Apply persists modified category overrides.
signal failed(error: Error)
const DEFAULT_TEXT: Translation = preload("../../i18n/zh_Hans.po")
@export var music_a: PartyAudioCue
@export var music_b: PartyAudioCue
@export var click: PartyAudioCue
@export var impact: PartyAudioCue
@export var ambience: PartyAudioCue
@export var voice_a: PartyAudioCue
@export var voice_b: PartyAudioCue
var audio: PartyGameAudio
var _i18n: RefCounted
var _preferences: PartyConfig
var _input_allowed: Callable
var _ambience_handle: PartyAudioHandle
var _counter: float = 0.0
var _dirty: Dictionary[String, float] = {}
@onready var _sliders: Dictionary[String, HSlider] = {
	"master": %MasterVolume, "music": %MusicVolume, "sfx": %SfxVolume,
	"dialogue": %DialogueVolume, "ambience": %AmbienceVolume, "ui": %UiVolume}
@onready var _values: Dictionary[String, Label] = {
	"master": %MasterValue, "music": %MusicValue, "sfx": %SfxValue,
	"dialogue": %DialogueValue, "ambience": %AmbienceValue, "ui": %UiValue}

func _ready() -> void:
	for cue: PartyAudioCue in [music_a, music_b, click, impact, ambience, voice_a, voice_b]:
		assert(cue != null and cue.validate() == OK, "Audio demo requires valid cue resources.")
	%Toggle.pressed.connect(_toggle)
	%Close.pressed.connect(close)
	%Apply.pressed.connect(_apply_volumes)
	%Reset.pressed.connect(_reset_volumes)
	for channel: String in _sliders:
		_sliders[channel].value_changed.connect(_volume_changed.bind(channel))

## Inject only the presentation dependencies; the panel does not own PartyAPI.
func configure(target: PartyGameAudio, i18n: RefCounted, preferences: PartyConfig, allowed: Callable) -> void:
	audio = target
	_i18n = i18n
	_preferences = preferences
	_input_allowed = allowed
	audio.playback_ended.connect(_ended)
	audio.subtitle_changed.connect(_subtitle)
	var actions: Dictionary[Button, Callable] = {
		%MusicA: audio.play_music.bind(music_a), %MusicB: audio.play_music.bind(music_b),
		%MusicPause: audio.pause_music, %MusicResume: audio.resume_music,
		%MusicStop: audio.stop_music.bind(0.5), %Click: audio.play_sfx.bind(click),
		%Impact: audio.play_sfx.bind(impact), %Burst: _burst,
		%AmbienceStart: _start_ambience, %AmbienceStop: _stop_ambience,
		%VoiceReplace: audio.play_dialogue.bind(voice_a),
		%VoiceQueue: audio.play_dialogue.bind(voice_b, PartyGameAudio.DialogueMode.QUEUE),
		%VoiceIgnore: audio.play_dialogue.bind(voice_b, PartyGameAudio.DialogueMode.IGNORE_IF_BUSY),
		%VoiceSkip: audio.skip_dialogue, %VoiceClear: audio.stop_dialogue,
		%PauseAll: audio.set_gameplay_paused.bind(true),
		%ResumeAll: audio.set_gameplay_paused.bind(false),
		%StopAll: audio.stop_all, %UIClick: audio.play_ui.bind(click)}
	for button: Button in actions:
		button.pressed.connect(_perform.bind(actions[button]))
	var captions: Dictionary[Control, StringName] = {
		%Title: &"audio.title", %Close: &"audio.close", %Toggle: &"audio.toggle",
		%MusicA: &"audio.music_a", %MusicB: &"audio.music_b",
		%MusicPause: &"audio.music_pause", %MusicResume: &"audio.music_resume",
		%MusicStop: &"audio.music_stop", %Click: &"audio.click", %Impact: &"audio.impact",
		%Burst: &"audio.burst", %AmbienceStart: &"audio.ambience_start",
		%AmbienceStop: &"audio.ambience_stop", %VoiceReplace: &"audio.voice_replace",
		%VoiceQueue: &"audio.voice_queue", %VoiceIgnore: &"audio.voice_ignore",
		%VoiceSkip: &"audio.voice_skip", %VoiceClear: &"audio.voice_clear",
		%PauseAll: &"audio.pause_all", %ResumeAll: &"audio.resume_all",
		%StopAll: &"audio.stop_all", %UIClick: &"audio.ui_click",
		%VolumeHeading: &"audio.volume_heading", %MasterName: &"audio.master",
		%MusicName: &"audio.music", %SfxName: &"audio.sfx", %DialogueName: &"audio.dialogue",
		%AmbienceName: &"audio.ambience", %UiName: &"audio.ui",
		%Apply: &"audio.apply", %Reset: &"audio.reset", %LastEvent: &"audio.event_hint"}
	for control: Control in captions:
		control.set("text", _text(captions[control]))
	%Subtitle.text = ""
	if _preferences != null:
		_preferences.effective_changed.connect(_settings_changed)
	for channel: String in _sliders:
		_reload_channel(channel)
	%Hint.text = _text(&"audio.hint_formal" if _preferences != null else &"audio.hint_preview")
	%Apply.disabled = true

func _exit_tree() -> void:
	if _preferences != null:
		_preferences.effective_changed.disconnect(_settings_changed)

func _toggle() -> void:
	if _input_allowed.call():
		%Popup.visible = not %Popup.visible

func close() -> void:
	%Popup.hide()

func is_expanded() -> bool:
	return %Popup.visible

func _text(key: StringName, params: Dictionary = {}) -> String:
	return String(DEFAULT_TEXT.get_message(key)).format(params) if _i18n == null else _i18n.text(key, params)

func _perform(action: Callable) -> void:
	if _input_allowed.call():
		action.call()

func _burst() -> void:
	for index: int in range(20):
		audio.play_sfx(impact)

func _start_ambience() -> void:
	if _ambience_handle == null or _ambience_handle.is_done:
		_ambience_handle = audio.play_ambience(ambience)

func _stop_ambience() -> void:
	if _ambience_handle != null:
		_ambience_handle.stop(0.4)

func _volume_changed(value: float, channel: String) -> void:
	_values[channel].text = "%d%%" % roundi(value * 100.0)
	if _preferences == null:
		audio.set_preview_volume(channel, value)
		return
	if is_equal_approx(value, float(_preferences.get_common(StringName("audio." + channel)))):
		_dirty.erase(channel)
	else:
		_dirty[channel] = value
	%Apply.disabled = _dirty.is_empty()

func _reload_channel(channel: String) -> void:
	var value: float = float(_preferences.get_common(StringName("audio." + channel))) if _preferences != null else 1.0
	_sliders[channel].set_value_no_signal(value)
	_values[channel].text = "%d%%" % roundi(value * 100.0)

func _settings_changed(common: PackedStringArray, _own: PackedStringArray) -> void:
	for channel: String in _sliders:
		if "audio." + channel in common and not _dirty.has(channel):
			_reload_channel(channel)

func _apply_volumes() -> void:
	if not _input_allowed.call() or _preferences == null:
		return
	# effective_changed fires synchronously; retain other drafts until their own write succeeds.
	for channel: String in _dirty.keys():
		var error: Error = _preferences.set_common_override(StringName("audio." + channel), _dirty[channel])
		if error != OK:
			failed.emit(error)
			return
		_dirty.erase(channel)
		_reload_channel(channel)
	%Apply.disabled = true

func _reset_volumes() -> void:
	if not _input_allowed.call():
		return
	for channel: String in _sliders:
		if _preferences != null:
			var error: Error = _preferences.clear_common_override(StringName("audio." + channel))
			if error != OK:
				failed.emit(error)
				return
		else:
			audio.set_preview_volume(channel, 1.0)
		_dirty.erase(channel)
		_reload_channel(channel)
	%Apply.disabled = true

func _subtitle(key: StringName) -> void:
	%Subtitle.text = _text(key) if not key.is_empty() else ""

func _ended(handle: PartyAudioHandle, _cue: PartyAudioCue, _category: PartyGameAudio.Category, reason: PartyAudioHandle.EndReason) -> void:
	%LastEvent.text = _text(&"audio.ended", {"id": handle.id, "reason": PartyAudioHandle.EndReason.keys()[reason]})

func _process(delta: float) -> void:
	if audio == null:
		return
	%Toggle.disabled = not _input_allowed.call()
	if not is_expanded():
		return
	_counter += delta
	if _counter < 0.1:
		return
	_counter = 0.0
	var state: Dictionary = audio.status()
	var values: Dictionary = state.playing.duplicate()
	values["queued"] = state.queued
	values["duck"] = "%.1f" % linear_to_db(float(state.duck))
	%Status.text = _text(&"audio.status", values)
