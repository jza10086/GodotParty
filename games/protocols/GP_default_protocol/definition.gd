## Lightweight catalog rules; the runtime protocol loads only when selected.
extends RefCounted

static func party_definition() -> Dictionary:
	return {"player_counts": [1, 2, 3, 4, 5, 6, 7, 8], "config_directories": {"maingame": "godot_party_default_v1", "minigame": "godot_party_default_v1"}}
