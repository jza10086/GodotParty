## Supplies protocol-owned appearance choices to the reusable profile editor.
extends "res://games/assets/GP_default_ui/profile_panel.gd"
const Protocol = preload("res://games/protocols/GP_default_protocol/protocol.gd")

func configure(value: Dictionary, editable: bool, context: Dictionary = {}) -> void:
	protocol_id = Protocol.ID
	colors = Protocol.COLORS
	color_names = Protocol.COLOR_NAMES
	super.configure(value, editable, context)
