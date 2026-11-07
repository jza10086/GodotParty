class_name PartyGameAudio
extends Node
## Scene-owned playback. Protocol runtime supplies formal buses; F6 owns a temporary mixer.
const Cue = preload("res://games/protocols/godot_party_default_protocol/audio/audio_cue.gd")
const Handle = preload("res://games/protocols/godot_party_default_protocol/audio/audio_handle.gd")
const Mixer = preload("res://games/protocols/godot_party_default_protocol/audio/audio_mixer.gd")
enum Category { MUSIC, SFX, DIALOGUE, AMBIENCE, UI }
enum DialogueMode { REPLACE, QUEUE, IGNORE_IF_BUSY }
signal playback_started(handle: Handle, cue: Cue, category: Category)
signal playback_ended(handle: Handle, cue: Cue, category: Category, reason: Handle.EndReason)
signal subtitle_changed(key: StringName)
@export_range(-24.0, 0.0, 0.1) var dialogue_duck_db: float = -8.0
@export_range(0.01, 2.0, 0.01) var duck_attack: float = 0.12
@export_range(0.01, 2.0, 0.01) var duck_release: float = 0.35
@export_range(1, 32, 1) var dialogue_queue_limit: int = 8
var _managed: bool = false
var _closed: bool = false
var _buses: Dictionary[String, StringName] = {}
var _preview_mixer: Mixer
var _players: Dictionary = {}
var _active: Dictionary[int, Dictionary] = {}
var _queue: Array[Dictionary] = []
var _last_play: Dictionary[Cue, float] = {}
var _serial: int = 0
var _clock: float = 0.0
var _paused: bool = false
var _music_paused: bool = false
var _duck: float = 1.0
var _stopping: bool = false
var _spatial: Array[Node] = []

## Called by the game's party_setup before entering the tree.
func prepare_scope() -> void:
	_managed = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_players = {Category.MUSIC: [$MusicA, $MusicB], Category.DIALOGUE: [$Dialogue],
		Category.SFX: $Effects.get_children(), Category.AMBIENCE: $Ambience.get_children(), Category.UI: $UI.get_children()}
	for group: Array in _players.values():
		for player: AudioStreamPlayer in group:
			player.finished.connect(_player_finished.bind(player))
	if not _managed:
		_preview_mixer = Mixer.new()
		_preview_mixer.open("preview.audio." + str(get_instance_id()))
		bind_buses(_preview_mixer.buses)

func bind_buses(buses: Dictionary[String, StringName]) -> void:
	_buses = buses
	_closed = false
	for category: int in _players:
		for player: AudioStreamPlayer in _players[category]:
			player.bus = buses[Mixer.CHANNELS[category]]

func set_preview_volume(channel: String, linear: float) -> void:
	assert(not _managed, "Formal preferences are applied by the protocol settings runtime.")
	_preview_mixer.set_volume(channel, linear)

func play_music(cue: Cue, fade_seconds: float = 0.6, restart: bool = false) -> Handle:
	if not restart:
		for record: Dictionary in _active.values():
			if record.category == Category.MUSIC and record.cue == cue and not record.stopping:
				return record.handle
	var handle: Handle = _request(cue)
	if handle.is_done:
		return handle
	var music: Array[Dictionary] = _records(Category.MUSIC)
	# Keep at most one outgoing track when a third request interrupts a crossfade.
	while music.size() > 1:
		_end(music.pop_front().handle.id, Handle.EndReason.REPLACED)
	for record: Dictionary in music:
		_fade_out(record, fade_seconds, Handle.EndReason.REPLACED)
	_start(handle, cue, Category.MUSIC, _free_player(Category.MUSIC), maxf(0.0, fade_seconds))
	return handle

func play_sfx(cue: Cue) -> Handle:
	return _play_effect(cue, Category.SFX, 0.0)

func play_ui(cue: Cue) -> Handle:
	return _play_effect(cue, Category.UI, 0.0)

func play_ambience(cue: Cue, fade_seconds: float = 0.3) -> Handle:
	return _play_effect(cue, Category.AMBIENCE, maxf(0.0, fade_seconds))

func _request(cue: Cue) -> Handle:
	_serial += 1
	var handle: Handle = Handle.new()
	handle.id = _serial
	handle._stop = _stop_handle
	if _closed:
		handle.error = ERR_UNAVAILABLE
		handle.complete(Handle.EndReason.SCOPE_CLOSED)
	elif _stopping:
		handle.complete(Handle.EndReason.STOPPED)
	elif cue == null or cue.validate() != OK:
		handle.error = ERR_INVALID_PARAMETER
		handle.complete(Handle.EndReason.INVALID_CUE)
	elif _buses.is_empty():
		push_error("Audio component must be attached to its scope before playback.")
		handle.error = ERR_UNCONFIGURED
		handle.complete(Handle.EndReason.INVALID_CUE)
	return handle

func _play_effect(cue: Cue, category: Category, fade_seconds: float) -> Handle:
	var handle: Handle = _request(cue)
	if handle.is_done:
		return handle
	var matching: int = 0
	for record: Dictionary in _active.values():
		if record.cue == cue:
			matching += 1
	if matching >= cue.max_instances or (_last_play.has(cue) and _clock - _last_play[cue] < cue.cooldown):
		handle.complete(Handle.EndReason.DROPPED)
		return handle
	var player: AudioStreamPlayer = _free_player(category)
	if player == null:
		var candidates: Array[Dictionary] = _records(category)
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.cue.priority < b.cue.priority if a.cue.priority != b.cue.priority else a.handle.id < b.handle.id)
		var victim: Dictionary = candidates[0]
		if victim.cue.priority > cue.priority:
			handle.complete(Handle.EndReason.DROPPED)
			return handle
		player = victim.player
		_end(victim.handle.id, Handle.EndReason.STOLEN)
	_start(handle, cue, category, player, fade_seconds)
	return handle

func play_dialogue(cue: Cue, mode: DialogueMode = DialogueMode.REPLACE) -> Handle:
	var handle: Handle = _request(cue)
	if handle.is_done:
		return handle
	if mode == DialogueMode.REPLACE:
		_clear_queue(Handle.EndReason.REPLACED)
		for record: Dictionary in _records(Category.DIALOGUE):
			_end(record.handle.id, Handle.EndReason.REPLACED)
	elif not _records(Category.DIALOGUE).is_empty() or not _queue.is_empty():
		if mode == DialogueMode.IGNORE_IF_BUSY or _queue.size() >= dialogue_queue_limit:
			handle.complete(Handle.EndReason.DROPPED)
		else:
			_queue.append({"handle": handle, "cue": cue})
		return handle
	_start(handle, cue, Category.DIALOGUE, $Dialogue, 0.0)
	return handle

func _start(handle: Handle, cue: Cue, category: Category, player: AudioStreamPlayer, fade: float) -> void:
	var record: Dictionary = {"handle": handle, "cue": cue, "category": category, "player": player,
		"gain": 0.0 if fade > 0.0 else 1.0, "from": 0.0, "target": 1.0,
		"duration": fade, "elapsed": 0.0, "stopping": false, "end_reason": Handle.EndReason.STOPPED}
	_active[handle.id] = record
	_last_play[cue] = _clock
	player.stream = cue.playback_stream()
	player.pitch_scale = cue.pitch_scale
	player.stream_paused = false
	_apply_gain(record)
	player.play()
	player.stream_paused = _category_paused(category)
	if category == Category.DIALOGUE:
		subtitle_changed.emit.call_deferred(cue.subtitle_key)
	playback_started.emit(handle, cue, category)

func _records(category: Category) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for record: Dictionary in _active.values():
		if record.category == category:
			records.append(record)
	return records

func _free_player(category: Category) -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _players[category]:
		var busy: bool = false
		for record: Dictionary in _active.values():
			if record.player == player:
				busy = true
				break
		if not busy:
			return player
	return null

func _player_finished(player: AudioStreamPlayer) -> void:
	for record: Dictionary in _active.values():
		if record.player == player:
			_end(record.handle.id, Handle.EndReason.COMPLETED)
			return

func _end(id: int, reason: Handle.EndReason) -> void:
	if not _active.has(id):
		return
	var record: Dictionary = _active[id]
	_active.erase(id)
	record.player.stop()
	record.player.stream = null
	if record.category == Category.DIALOGUE:
		subtitle_changed.emit.call_deferred(&"")
		_next_dialogue.call_deferred()
	record.handle.complete(reason)
	playback_ended.emit.call_deferred(record.handle, record.cue, record.category, reason)

func _next_dialogue() -> void:
	if _closed or _stopping or _queue.is_empty() or not _records(Category.DIALOGUE).is_empty():
		return
	var next: Dictionary = _queue.pop_front()
	_start(next.handle, next.cue, Category.DIALOGUE, $Dialogue, 0.0)

func _fade_out(record: Dictionary, duration: float, reason: Handle.EndReason) -> void:
	if duration <= 0.0:
		_end(record.handle.id, reason)
		return
	record.from = record.gain
	record.target = 0.0
	record.duration = duration
	record.elapsed = 0.0
	record.stopping = true
	record.end_reason = reason

func _stop_handle(handle: Handle, fade: float) -> void:
	for i: int in _queue.size():
		if _queue[i].handle == handle:
			_queue.remove_at(i)
			handle.complete(Handle.EndReason.STOPPED)
			return
	if _active.has(handle.id):
		_fade_out(_active[handle.id], fade, Handle.EndReason.STOPPED)

func stop_music(fade_seconds: float = 0.5) -> void:
	stop_category(Category.MUSIC, fade_seconds)

func pause_music() -> void:
	_music_paused = true
	_apply_pause()

func resume_music() -> void:
	_music_paused = false
	_apply_pause()

func skip_dialogue() -> void:
	for record: Dictionary in _records(Category.DIALOGUE):
		_end(record.handle.id, Handle.EndReason.STOPPED)

func clear_dialogue_queue() -> void:
	_clear_queue(Handle.EndReason.STOPPED)

func _clear_queue(reason: Handle.EndReason) -> void:
	var pending: Array[Dictionary] = _queue.duplicate()
	_queue.clear()
	for item: Dictionary in pending:
		item.handle.complete(reason)

func stop_dialogue(fade_seconds: float = 0.0) -> void:
	clear_dialogue_queue()
	stop_category(Category.DIALOGUE, fade_seconds)

func stop_category(category: Category, fade_seconds: float = 0.0) -> void:
	if category == Category.DIALOGUE:
		clear_dialogue_queue()
	for record: Dictionary in _records(category):
		_fade_out(record, fade_seconds, Handle.EndReason.STOPPED)
	for player: Node in _spatial:
		if is_instance_valid(player) and player.get_meta("party_audio_category") == category:
			player.stop()

func stop_all() -> void:
	_stop_all(Handle.EndReason.STOPPED)

func _stop_all(reason: Handle.EndReason) -> void:
	_stopping = true
	_clear_queue(reason)
	for id: int in _active.keys():
		_end(id, reason)
	for player: Node in _spatial:
		if is_instance_valid(player):
			player.stop()
	_last_play.clear()
	_duck = 1.0
	_stopping = false

func set_gameplay_paused(paused: bool) -> void:
	_paused = paused
	_apply_pause()

func _category_paused(category: Category) -> bool:
	return (_paused and category != Category.UI) or (_music_paused and category == Category.MUSIC)

func _apply_pause() -> void:
	for record: Dictionary in _active.values():
		record.player.stream_paused = _category_paused(record.category)
	for player: Node in _spatial:
		if is_instance_valid(player):
			player.stream_paused = _category_paused(player.get_meta("party_audio_category"))

## Register a fixed native spatial source. The game controls play; this component owns routing/pause/cleanup.
func route_spatial(player: Node, category: Category = Category.SFX) -> void:
	assert(player is AudioStreamPlayer2D or player is AudioStreamPlayer3D, "Spatial routing requires a native 2D/3D audio player.")
	assert(not _buses.is_empty(), "Attach audio buses before registering a spatial player.")
	player.bus = _buses[Mixer.CHANNELS[category]]
	player.set_meta("party_audio_category", category)
	if not _spatial.has(player):
		_spatial.append(player)
	player.stream_paused = _category_paused(category)

func _process(delta: float) -> void:
	_clock += delta
	var speaking: bool = not _records(Category.DIALOGUE).is_empty() and not _paused
	var duck_target: float = db_to_linear(dialogue_duck_db) if speaking else 1.0
	_duck = move_toward(_duck, duck_target, delta / (duck_attack if speaking else duck_release))
	for record: Dictionary in _active.values():
		if _category_paused(record.category):
			continue
		if record.duration > 0.0:
			record.elapsed += delta
			record.gain = lerpf(record.from, record.target, minf(1.0, record.elapsed / record.duration))
			if record.stopping and record.elapsed >= record.duration:
				_end(record.handle.id, record.end_reason)
				continue
		_apply_gain(record)

func _apply_gain(record: Dictionary) -> void:
	record.player.volume_linear = db_to_linear(record.cue.volume_db) * record.gain * (_duck if record.category == Category.MUSIC else 1.0)

func status() -> Dictionary:
	var counts: Dictionary = {}
	for category: int in _players:
		counts[Mixer.CHANNELS[category]] = _records(category).size()
	return {"playing": counts, "queued": _queue.size(), "paused": _paused, "music_paused": _music_paused, "duck": _duck}

func close_scope() -> void:
	_closed = true
	_stop_all(Handle.EndReason.SCOPE_CLOSED)
	_buses = {}
	_spatial.clear()

func _exit_tree() -> void:
	close_scope()
	if _preview_mixer != null:
		_preview_mixer.close()
