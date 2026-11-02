## Business-owned setting defaults, constraints and UI hierarchy. No runtime side effects.
extends RefCounted

static func schema() -> Dictionary:
	return {
		"schema_format": 3,
		"settings_version": 1,
		"fields": {
			"rounds": {
				"type": "int",
				"default": 4,
				"title": "总局数",
				"min": 1,
				"max": 100,
				"description": "关闭重复时，实际局数最多为所选小游戏数量。",
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
			"allow_repeat": {
				"type": "bool",
				"default": true,
				"title": "允许小游戏重复",
				"description": "开启后顺序循环、随机有放回抽取；单选一个小游戏可连续测试。",
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
						"field": "allow_repeat"
					},
					{
						"field": "interval"
					}
				]
			}
		]
	}
