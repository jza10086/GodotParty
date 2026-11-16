## Business-owned setting defaults, constraints and UI hierarchy. No runtime side effects.
extends RefCounted

static func schema() -> Dictionary:
	return {
		"schema_format": 3,
		"settings_version": 2,
		"fields": {
			"rounds": {
				"type": "int",
				"default": 0,
				"title": "轮换局数",
				"min": 0,
				"max": 100,
				"description": "0 表示自动按已选小游戏数量设置；大于 0 表示手动局数。",
				"audience": "room",
				"apply": "lobby",
				"control": "number"
			},
			"rotation": {
				"type": "string",
				"default": "顺序",
				"title": "轮换方式",
				"values": [
					"顺序",
					"随机"
				],
				"description": "顺序按小游戏列表排列；随机由房主抽取并保存整次队列。",
				"audience": "room",
				"apply": "lobby",
				"control": "select"
			},
			"avoid_repeat": {
				"type": "bool",
				"default": true,
				"title": "避免游戏重复",
				"description": "仅随机轮换生效。开启后每个小游戏最多出现一次，实际局数不超过已选小游戏数。",
				"audience": "room",
				"apply": "lobby",
				"control": "toggle"
			},
			"interval": {
				"type": "int",
				"default": 0,
				"title": "局间间隔（秒）",
				"min": 0,
				"max": 30,
				"description": "默认 0：上一局正式结算后直接加载下一局，无需手动确认。",
				"audience": "room",
				"apply": "lobby",
				"control": "number"
			}
		},
		"layout": [
			{
				"id": "room",
				"title": "游戏规则",
				"expanded": true,
				"children": [
					{
						"field": "rounds"
					},
					{
						"field": "rotation"
					},
					{
						"field": "avoid_repeat",
						"enabled_when": {"field": "rotation", "equals": "随机"}
					},
					{
						"field": "interval"
					}
				]
			}
		]
	}
