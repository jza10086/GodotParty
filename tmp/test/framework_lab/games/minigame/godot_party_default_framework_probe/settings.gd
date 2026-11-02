extends RefCounted
static func schema() -> Dictionary:
	return {"schema_format": 3, "settings_version": 1, "fields": {
		"ready_delay": {"type": "float", "default": 0.3, "min": 0.0, "max": 5.0,
			"title": "就绪延迟（秒）", "audience": "room", "apply": "next_round"}
	}, "layout": [{"field": "ready_delay"}]}
