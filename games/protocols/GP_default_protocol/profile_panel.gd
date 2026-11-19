## Supplies protocol-owned appearance choices to the reusable profile editor.
extends "res://games/assets/GP_default_ui/profile_panel.gd"
const Protocol = preload("res://games/protocols/GP_default_protocol/protocol.gd")

var _account_id: String = ""

func configure(value: Dictionary, editable: bool, context: Dictionary = {}) -> void:
	appearance_types = {"avatar_2d": "GP_default_avatar_2d", "character_3d": "GP_default_character_3d"}
	colors = Protocol.COLORS
	color_names = Protocol.COLOR_NAMES
	super.configure(value, editable, context)
	if context.has("steam_profile_changed"):
		var updates: Signal = context.steam_profile_changed
		if not updates.is_connected(_steam_changed):
			updates.connect(_steam_changed, CONNECT_DEFERRED)
	_refresh_steam_choice()

func _steam_changed(id: String) -> void:
	if _account_id.is_empty() or _account_id == id:
		_refresh_steam_choice()

## Keep the selected snapshot usable offline. A newly fetched image remains a separate draft choice.
func _refresh_steam_choice() -> void:
	var picker: OptionButton = _choices.avatar_2d
	var selected: Dictionary = _value.avatar_2d
	for i: int in range(picker.item_count - 1, -1, -1):
		if picker.get_item_metadata(i).has("portrait_rgba"):
			picker.remove_item(i)
	var account: Dictionary = _context.steam_profile.call() if _context.has("steam_profile") else {}
	_account_id = account.get("steam_id", "")
	var live: Dictionary = {}
	if account.get("avatar") != null:
		live = Protocol.new().steam_portrait(account.avatar)
	if selected.has("portrait_rgba") and selected != live:
		picker.add_item("Steam 头像（已保存）")
		picker.set_item_metadata(picker.item_count - 1, selected)
	if not live.is_empty():
		picker.add_item("Steam 头像")
		picker.set_item_metadata(picker.item_count - 1, live)
	for i: int in picker.item_count:
		if picker.get_item_metadata(i) == selected:
			picker.select(i)
			break
