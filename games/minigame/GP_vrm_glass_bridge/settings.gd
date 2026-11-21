extends RefCounted
const Definition = preload("definition.gd")
const KEYS: Dictionary[String, Key] = {"vrm_bridge_left": KEY_A, "vrm_bridge_right": KEY_D, "vrm_bridge_forward": KEY_W, "vrm_bridge_back": KEY_S, "vrm_bridge_jump": KEY_SPACE, "vrm_bridge_sprint": KEY_SHIFT}

const DEFAULT_RUN_SPEED: float = 4.8
const DEFAULT_SPRINT_SPEED: float = 6.2
const DEFAULT_JUMP_HEIGHT: float = 2.2

static func schema() -> Dictionary:
	var titles: Dictionary = Definition.party_definition().controls
	var fields: Dictionary = {
		"run_speed": {"title": "移动速度（米/秒）", "type": "float", "control": "number", "min": 0.1, "step": 0.1,
			"default": DEFAULT_RUN_SPEED, "audience": "room", "apply": "next_round"},
		"sprint_speed": {"title": "冲刺速度（米/秒）", "type": "float", "control": "number", "min": 0.1, "step": 0.1,
			"default": DEFAULT_SPRINT_SPEED, "audience": "room", "apply": "next_round"},
		"jump_height": {"title": "跳跃高度（米）", "type": "float", "control": "number", "min": 0.05, "step": 0.05,
			"default": DEFAULT_JUMP_HEIGHT, "audience": "room", "apply": "next_round"}
	}
	var layout: Array[Dictionary] = [{"field": "run_speed"}, {"field": "sprint_speed"}, {"field": "jump_height"}]
	for action: String in KEYS:
		fields[action] = {"type": "array", "control": "binding", "action": action, "title": titles[action],
			"default": [{"kind": "key", "code": KEYS[action], "physical": true}],
			"audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"},
			"max_items": 2, "combinations": false}
		layout.append({"field": action})
	return {"schema_format": 3, "settings_version": 2, "fields": fields, "layout": layout}
