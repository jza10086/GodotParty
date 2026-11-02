extends RefCounted

static func schema() -> Dictionary:
	return {"schema_format": 3, "settings_version": 2, "fields": {
		"ready_delay": {"type": "float", "default": 0.3, "min": 0.0, "max": 5.0, "step": 0.1,
			"title": "就绪延迟（秒）", "audience": "room", "apply": "next_round"},
		"spectator_seats": {"type": "array", "control": "switches", "default": [],
			"items": {"type": "int", "values": [1, 2, 3, 4, 5, 6, 7, 8]},
			"title": "观战席位", "description": "按大厅玩家列表从 1 开始编号。选中的席位在测试局观战，请保留至少一位在线参赛者。",
			"audience": "room", "apply": "next_round"}
	}, "layout": [{"field": "ready_delay"}, {"field": "spectator_seats"}]}
