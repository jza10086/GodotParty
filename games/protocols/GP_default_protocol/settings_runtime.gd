extends "res://games/protocols/GP_default_protocol/graphics_settings.gd"
## Owns protocol-local graphics, pointer appearance and per-activation game audio buses.
## One settings activation owns the native arrow; leaving restores the engine cursor.
const Cursor: Script = preload("res://games/assets/GP_default_ui/appearance/player_cursor.gd")
const AudioMixer = preload("res://games/protocols/GP_default_protocol/audio/audio_mixer.gd")
const MusicControl = preload("res://games/protocols/GP_default_protocol/audio/music_control.gd")
var _music_control: MusicControl
var _audio_mixer: AudioMixer
var _audio_target: PartyGameAudio
var _api: PartyAPI
var _cursor_installed: bool = false

func configure(api: PartyAPI) -> void:
	super.configure(api)
	_api = api

func enter() -> Dictionary:
	var report: Dictionary = super.enter()
	if not report.ok:
		return report
	_audio_mixer = AudioMixer.new()
	_audio_mixer.open(_api.scope_id)
	_audio_mixer.apply(_api.config)
	_api.players_changed.connect(_players_changed)
	report = _apply_cursor(report)
	if report.ok:
		var applied: PackedStringArray = report.get("applied", PackedStringArray())
		applied.append_array(AudioMixer.KEYS)
		report["applied"] = applied
	return report

func attach_view(view_root: Node) -> Dictionary:
	_release_audio_view()
	if view_root.has_method("godot_party_audio_target"):
		_audio_target = view_root.godot_party_audio_target()
		if _audio_target != null:
			_audio_target.bind_buses(_audio_mixer.buses)
	var report: Dictionary = super.attach_view(view_root)
	if report.ok and not _api.round_id.is_empty():
		_music_control = MusicControl.new()
		_music_control.attach(view_root, _audio_mixer, _audio_target)
	return report

func _release_audio_view() -> void:
	if is_instance_valid(_music_control):
		_music_control.free()
		_music_control = null
	if is_instance_valid(_audio_target):
		_audio_target.close_scope()
	_audio_target = null

func apply(common_keys: PackedStringArray, own_keys: PackedStringArray) -> Dictionary:
	var report: Dictionary = _apply_cursor(super.apply(common_keys, own_keys))
	if report.ok and _active:
		_audio_mixer.apply(_api.config)
		var applied: PackedStringArray = report.get("applied", PackedStringArray())
		applied.append_array(AudioMixer.KEYS)
		report["applied"] = applied
	return report

func _apply_cursor(report: Dictionary) -> Dictionary:
	if not report.ok or not _active:
		return report
	var tint: Color = Color.WHITE
	for player: Dictionary in _api.get_room_players():
		if player.is_local:
			tint = Color(_api.get_appearance(player.player_id).color)
			break
	var texture: ImageTexture = Cursor.texture_for(_config.get_common(&"ui.cursor_theme"), tint)
	if texture == null:
		return {"ok": false, "message": "无法生成协议鼠标指针"}
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, Cursor.HOTSPOT)
	_cursor_installed = true
	var applied: PackedStringArray = report.get("applied", PackedStringArray())
	applied.append("ui.cursor_theme")
	report["applied"] = applied
	return report

func _players_changed() -> void:
	var report: Dictionary = _apply_cursor({"ok": true})
	if not report.ok:
		_api.fail("cursor_failed", report.message)

func leave() -> void:
	_release_audio_view()
	if _audio_mixer != null:
		_audio_mixer.close()
	if _active:
		_api.players_changed.disconnect(_players_changed)
	if _cursor_installed:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		_cursor_installed = false
	super.leave()
