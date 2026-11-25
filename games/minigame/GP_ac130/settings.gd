extends RefCounted

const Definition = preload("res://games/minigame/GP_ac130/definition.gd")

static func schema() -> Dictionary:
	var bindings: Dictionary = {
		"ac130_pulse": {"kind": "mouse", "code": MOUSE_BUTTON_LEFT},
		"ac130_polarity": {"kind": "key", "code": KEY_V, "physical": true},
		"ac130_zoom": {"kind": "mouse", "code": MOUSE_BUTTON_RIGHT}
	}
	var fields: Dictionary = {}
	var layout: Array[Dictionary] = []
	for action: String in bindings:
		fields[action] = {"type": "array", "control": "binding", "default": [bindings[action]],
			"title": Definition.CONTROLS[action], "action": action, "audience": "local", "apply": "immediate",
			"items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false}
		layout.append({"field": action})
	return {"schema_format": 3, "settings_version": 1, "fields": fields, "layout": layout}
