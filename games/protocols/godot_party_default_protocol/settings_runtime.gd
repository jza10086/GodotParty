extends "res://games/protocols/godot_party_default_protocol/graphics_settings.gd"
## Owns protocol-local pointer appearance alongside the existing graphics effects.
## One settings activation owns the native arrow; leaving restores the engine cursor.
const Cursor: Script = preload("res://games/protocols/godot_party_default_protocol/appearance/player_cursor.gd")
var _api: PartyAPI
var _cursor_installed: bool = false

func configure(api: PartyAPI) -> void:
	super.configure(api)
	_api = api

func enter() -> Dictionary:
	var report: Dictionary = super.enter()
	if not report.ok:
		return report
	_api.players_changed.connect(_players_changed)
	return _apply_cursor(report)

func attach_view(view_root: Node) -> Dictionary:
	return super.attach_view(view_root)

func apply(common_keys: PackedStringArray, own_keys: PackedStringArray) -> Dictionary:
	return _apply_cursor(super.apply(common_keys, own_keys))

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
	if _active:
		_api.players_changed.disconnect(_players_changed)
	if _cursor_installed:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		_cursor_installed = false
	super.leave()
