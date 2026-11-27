## Session-owned music. Only the current track is loaded; the bag holds package-relative paths.
extends AudioStreamPlayer

const MusicControl = preload("res://games/protocols/GP_default_protocol/audio/music_control.gd")
const PACK: String = "GP_lofi_music"
var _api: PartyAPI
var _tracks: Array[String] = []
var _bag: Array[String] = []
var _last: String = ""
var _started: bool = false
var _yield_music: bool = false
var _music_control: MusicControl
var _child_config: PartyConfig

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

func _attach_child(root: Node, _scope_id: String, config: PartyConfig) -> void:
	_child_config = config
	_child_config.effective_changed.connect(_child_settings_changed)
	_music_control = MusicControl.for_game(root)
	_music_control.tree_exiting.connect(_detach_child, CONNECT_ONE_SHOT)
	_music_control.state_changed.connect(_music_changed)
	_apply_gain()
	_apply_override()

func _playlist_settings_changed(_common: PackedStringArray, own: PackedStringArray) -> void:
	_apply_gain()
	if "override_minigame_bgm" in own and _music_control != null:
		_apply_override()

func _apply_override() -> void:
	_music_control.set_background_muted(_api.config.get_own(&"override_minigame_bgm"))
	_music_changed(_music_control.state)

func _music_changed(state: MusicControl.State) -> void:
	_yield_music = state == MusicControl.State.GAMEPLAY or (state == MusicControl.State.BACKGROUND and not _api.config.get_own(&"override_minigame_bgm"))
	stream_paused = _yield_music

func _child_settings_changed(_common: PackedStringArray, _own: PackedStringArray) -> void:
	_apply_gain()

func _apply_gain() -> void:
	var config: PartyConfig = _child_config if _child_config != null else _api.config
	volume_linear = float(config.get_common(&"audio.master")) * float(config.get_common(&"audio.music"))

func _detach_child() -> void:
	_child_config.effective_changed.disconnect(_child_settings_changed)
	_child_config = null
	_music_control.state_changed.disconnect(_music_changed)
	_music_control = null
	_yield_music = false
	stream_paused = false

func stop_session() -> void:
	_started = false
	stop()
	stream = null
