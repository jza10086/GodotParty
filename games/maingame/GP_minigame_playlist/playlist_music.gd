## Session-owned music. Only the current track is loaded; the bag holds package-relative paths.
extends AudioStreamPlayer

const PACK: String = "GP_lofi_music"
var _api: PartyAPI
var _tracks: Array[String] = []
var _bag: Array[String] = []
var _last: String = ""
var _started: bool = false
var _yield_music: bool = false
var _child_audio: PartyGameAudio
var _child_config: PartyConfig
var _music_bus: StringName
var _original_send: StringName
var _silent_bus: StringName

func configure(api: PartyAPI) -> void:
	_api = api
	api.foreground_child_attached.connect(_attach_child)
	api.config.effective_changed.connect(_playlist_settings_changed)
	finished.connect(_next)

func start_session() -> void:
	_apply_gain()
	if _started:
		return
	_started = true
	var library: Script = _api.load_asset({"package_id": PACK, "resource_path": "tracks.gd"}) as Script
	if library == null:
		_api.fail("playlist_music", "无法读取 LoFi 曲目表")
		return
	_tracks.assign(library.TRACKS)
	_next()

func _draw_track() -> String:
	if _bag.is_empty():
		_bag.assign(_tracks)
		_bag.shuffle()
		if _bag.size() > 1 and _bag.back() == _last:
			var index: int = randi_range(0, _bag.size() - 2)
			_bag[-1] = _bag[index]
			_bag[index] = _last
	_last = _bag.pop_back()
	return _last

func _next() -> void:
	var path: String = _draw_track()
	var track: AudioStream = await _api.load_asset_async({"package_id": PACK, "resource_path": path}) as AudioStream
	if not _started:
		return
	if track == null:
		_api.fail("playlist_music", "无法加载 LoFi 曲目：" + path)
		return
	stream = track
	play()
	stream_paused = _yield_music

func _attach_child(root: Node, scope_id: String, config: PartyConfig) -> void:
	_child_config = config
	_child_config.effective_changed.connect(_child_settings_changed)
	root.tree_exiting.connect(_detach_child, CONNECT_ONE_SHOT)
	_apply_gain()
	if root.is_in_group(&"party_gameplay_music"):
		_set_yield(true)
		return
	if not root.has_method("godot_party_audio_target"):
		return
	_child_audio = root.godot_party_audio_target()
	if _child_audio == null:
		return
	_music_bus = StringName("party." + scope_id + ".GameRoot.music")
	_child_audio.playback_started.connect(_music_started)
	_child_audio.playback_ended.connect(_music_ended)
	_apply_override()

func _playlist_settings_changed(_common: PackedStringArray, own: PackedStringArray) -> void:
	_apply_gain()
	if "override_minigame_bgm" in own and is_instance_valid(_child_audio):
		_apply_override()

func _apply_override() -> void:
	var replace_bgm: bool = _api.config.get_own(&"override_minigame_bgm")
	if replace_bgm and _silent_bus == &"":
		# Route only music away. The game's timeline, crossfades and end callbacks keep running.
		_original_send = AudioServer.get_bus_send(AudioServer.get_bus_index(_music_bus))
		_silent_bus = StringName("playlist.silent." + _api.scope_id)
		# A send must point to a bus on its left.
		AudioServer.add_bus(1)
		AudioServer.set_bus_name(1, _silent_bus)
		AudioServer.set_bus_mute(1, true)
		AudioServer.set_bus_send(AudioServer.get_bus_index(_music_bus), _silent_bus)
	elif not replace_bgm:
		_restore_routing()
	_update_priority()

func _music_started(_handle: PartyAudioHandle, _cue: PartyAudioCue, category: PartyGameAudio.Category) -> void:
	if category == PartyGameAudio.Category.MUSIC:
		_set_yield(_silent_bus == &"")

func _music_ended(_handle: PartyAudioHandle, _cue: PartyAudioCue, category: PartyGameAudio.Category, _reason: PartyAudioHandle.EndReason) -> void:
	if category == PartyGameAudio.Category.MUSIC:
		_update_priority()

func _update_priority() -> void:
	_set_yield(_silent_bus == &"" and _child_audio.status().playing.music > 0)

func _set_yield(value: bool) -> void:
	_yield_music = value
	stream_paused = value

func _child_settings_changed(_common: PackedStringArray, _own: PackedStringArray) -> void:
	_apply_gain()

func _apply_gain() -> void:
	var config: PartyConfig = _child_config if _child_config != null else _api.config
	volume_linear = float(config.get_common(&"audio.master")) * float(config.get_common(&"audio.music"))

func _detach_child() -> void:
	if _child_config != null:
		_child_config.effective_changed.disconnect(_child_settings_changed)
		_child_config = null
	if is_instance_valid(_child_audio):
		_child_audio.playback_started.disconnect(_music_started)
		_child_audio.playback_ended.disconnect(_music_ended)
	_child_audio = null
	_restore_routing()
	_set_yield(false)

func _restore_routing() -> void:
	if _silent_bus != &"":
		var index: int = AudioServer.get_bus_index(_music_bus)
		if index >= 0:
			AudioServer.set_bus_send(index, _original_send)
		AudioServer.remove_bus(AudioServer.get_bus_index(_silent_bus))
		_silent_bus = &""

func stop_session() -> void:
	_started = false
	stop()
	stream = null
