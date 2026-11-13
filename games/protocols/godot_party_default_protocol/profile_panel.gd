## Supplies protocol-owned appearance choices to the reusable profile editor.
extends "res://games/assets/godot_party_default_ui/profile_panel.gd"
const Protocol = preload("res://games/protocols/godot_party_default_protocol/protocol.gd")

func configure(value: Dictionary, editable: bool, context: Dictionary = {}) -> void:
	protocol_id = Protocol.ID
	colors = Protocol.COLORS
	color_names = Protocol.COLOR_NAMES
	super.configure(value, editable, context)
