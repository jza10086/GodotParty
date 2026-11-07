extends Control
## Editable test controls; only updates existing nodes and delegates playback to GameAudio.
@export var music_a: PartyAudioCue
@export var music_b: PartyAudioCue
@export var click: PartyAudioCue
@export var impact: PartyAudioCue
@export var ambience: PartyAudioCue
@export var voice_a: PartyAudioCue
@export var voice_b: PartyAudioCue
var audio: PartyGameAudio
var api: PartyAPI
var input_allowed: Callable
var _ambience_handle: PartyAudioHandle
var _counter: float = 0.0
const CHANNELS: Array[String] = ["master", "music", "sfx", "dialogue", "ambience", "ui"]

func _ready() -> void:
	for cue: PartyAudioCue in [music_a, music_b, click, impact, ambience, voice_a, voice_b]:
		assert(cue != null and cue.validate() == OK, "Audio demo requires valid cue resources.")
	%Toggle.pressed.connect(func() -> void: %Popup.visible = not %Popup.visible)
	%Close.pressed.connect(func() -> void: %Popup.hide())
	for button: Button in [%MusicA, %MusicB, %MusicPause, %MusicResume, %MusicStop,
		%Click, %Impact, %Burst, %AmbienceStart, %AmbienceStop,
		%VoiceReplace, %VoiceQueue, %VoiceIgnore, %VoiceSkip, %VoiceClear,
		%PauseAll, %ResumeAll, %StopAll, %UIClick]:
		button.pressed.connect(_action.bind(button.name))
	%Apply.pressed.connect(_apply_volumes)
	%Reset.pressed.connect(_reset_volumes)
	for channel: String in CHANNELS:
		var slider: HSlider = get_node("%" + channel.capitalize() + "Volume")
		slider.value_changed.connect(_volume_changed.bind(channel))

func configure(target: PartyGameAudio, context: PartyAPI, allowed: Callable) -> void:
	audio = target
	api = context
	input_allowed = allowed
	audio.playback_ended.connect(_ended)
	audio.subtitle_changed.connect(_subtitle)
	if api != null:
		for node: Node in find_children("*", "", true, false):
			if node is Button or node is Label:
				node.text = api.i18n.text(StringName(node.text))
		api.config.effective_changed.connect(_settings_changed)
	_reload_volumes()
	%Hint.text = _text(&"audio.hint_formal" if api != null else &"audio.hint_preview")

func is_expanded() -> bool:
	return %Popup.visible

func _text(key: StringName, params: Dictionary = {}) -> String:
	if api != null:
		return api.i18n.text(key, params)
	var templates: Dictionary = {
		&"audio.hint_preview": "F6 预览音量立即生效，仅本次有效。配音是预录示例，不是玩家语音。",
		&"audio.hint_formal": "音量先调整，点应用保存为本游戏偏好；恢复继承使用协议设置。配音不是玩家语音。",
		&"audio.status": "音乐 {music} · 音效 {sfx} · 配音 {dialogue} · 排队 {queued} · 环境 {ambience} · UI {ui} · 压低 {duck} dB",
		&"audio.ended": "播放 #{id} 结束：{reason}",
		&"audio.voice_a": "欢迎来到音频测试。播放配音时，背景音乐会自动降低音量。",
		&"audio.voice_b": "注意，这是插播提示。你可以中断、排队或跳过这段配音。"
	}
	return str(templates[key]).format(params)

func _action(action: StringName) -> void:
	if not input_allowed.call():
		return
	match action:
		&"MusicA": audio.play_music(music_a)
		&"MusicB": audio.play_music(music_b)
		&"MusicPause": audio.pause_music()
		&"MusicResume": audio.resume_music()
		&"MusicStop": audio.stop_music(0.5)
		&"Click": audio.play_sfx(click)
		&"Impact": audio.play_sfx(impact)
		&"Burst":
			for index: int in range(20):
				audio.play_sfx(impact)
		&"AmbienceStart":
			if _ambience_handle == null or _ambience_handle.is_done:
				_ambience_handle = audio.play_ambience(ambience)
		&"AmbienceStop":
			if _ambience_handle != null:
				_ambience_handle.stop(0.4)
		&"VoiceReplace": audio.play_dialogue(voice_a)
		&"VoiceQueue": audio.play_dialogue(voice_b, PartyGameAudio.DialogueMode.QUEUE)
		&"VoiceIgnore": audio.play_dialogue(voice_b, PartyGameAudio.DialogueMode.IGNORE_IF_BUSY)
		&"VoiceSkip": audio.skip_dialogue()
		&"VoiceClear": audio.stop_dialogue()
		&"PauseAll": audio.set_gameplay_paused(true)
		&"ResumeAll": audio.set_gameplay_paused(false)
		&"StopAll": audio.stop_all()
		&"UIClick": audio.play_ui(click)

func _volume_changed(value: float, channel: String) -> void:
	get_node("%" + channel.capitalize() + "Value").text = "%d%%" % roundi(value * 100.0)
	if audio != null and api == null:
		audio.set_preview_volume(channel, value)

func _reload_volumes() -> void:
	for channel: String in CHANNELS:
		var slider: HSlider = get_node("%" + channel.capitalize() + "Volume")
		slider.value = float(api.config.get_common(StringName("audio." + channel))) if api != null else 1.0

func _settings_changed(_common: PackedStringArray, _own: PackedStringArray) -> void:
	_reload_volumes()

func _apply_volumes() -> void:
	if not input_allowed.call() or api == null:
		return
	# Snapshot the entire draft first: committing one field can emit effective_changed.
	var draft: Dictionary[String, float] = {}
	for channel: String in CHANNELS:
		draft[channel] = get_node("%" + channel.capitalize() + "Volume").value
	for channel: String in CHANNELS:
		var error: Error = api.config.set_common_override(StringName("audio." + channel), draft[channel])
		if error != OK:
			api.fail("audio_settings_failed", error_string(error))
			return

func _reset_volumes() -> void:
	if not input_allowed.call():
		return
	if api == null:
		_reload_volumes()
		return
	for channel: String in CHANNELS:
		var error: Error = api.config.clear_common_override(StringName("audio." + channel))
		if error != OK:
			api.fail("audio_settings_failed", error_string(error))
			return
	_reload_volumes()

func _subtitle(key: StringName) -> void:
	%Subtitle.text = _text(key) if not key.is_empty() else ""

func _ended(handle: PartyAudioHandle, _cue: PartyAudioCue, _category: PartyGameAudio.Category, reason: PartyAudioHandle.EndReason) -> void:
	%LastEvent.text = _text(&"audio.ended", {"id": handle.id, "reason": PartyAudioHandle.EndReason.keys()[reason]})

func _process(delta: float) -> void:
	if audio == null:
		return
	%Toggle.disabled = not input_allowed.call()
	_counter += delta
	if _counter < 0.1:
		return
	_counter = 0.0
	var state: Dictionary = audio.status()
	var values: Dictionary = state.playing.duplicate()
	values["queued"] = state.queued
	values["duck"] = "%.1f" % linear_to_db(float(state.duck))
	%Status.text = _text(&"audio.status", values)
