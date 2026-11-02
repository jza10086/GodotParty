## Business-owned setting defaults, constraints and UI hierarchy. No runtime side effects.
extends RefCounted

static func schema() -> Dictionary:
	return {
		"schema_format": 3,
		"settings_version": 1,
		"fields": {
			"graphics.quality": {
				"type": "string",
				"default": "极高",
				"title": "画质档位",
				"description": "控制阴影图、抗锯齿与 AO 采样；独立开关不随档位重置。",
				"audience": "local",
				"apply": "immediate",
				"overridable": true,
				"values": [
					"低",
					"中",
					"高",
					"极高"
				],
				"control": "select"
			},
			"graphics.shadows": {
				"type": "bool",
				"default": true,
				"title": "日光阴影",
				"description": "关闭真实日光投影。",
				"audience": "local",
				"apply": "immediate",
				"overridable": true,
				"control": "toggle"
			},
			"graphics.pcss": {
				"type": "bool",
				"default": false,
				"title": "PCSS 软阴影",
				"description": "可变半影；可能产生采样噪点，关闭时使用较硬的 PCF。",
				"audience": "local",
				"apply": "immediate",
				"overridable": true,
				"control": "toggle"
			},
			"graphics.ao": {
				"type": "bool",
				"default": false,
				"title": "环境光遮蔽（AO）",
				"description": "增强接触细节；需要 Forward+。",
				"audience": "local",
				"apply": "immediate",
				"overridable": true,
				"control": "toggle"
			},
			"graphics.taa": {
				"type": "bool",
				"default": true,
				"title": "时间抗锯齿（TAA）",
				"description": "减少闪烁，运动中可能柔化或拖影。",
				"audience": "local",
				"apply": "immediate",
				"overridable": true,
				"control": "toggle"
			},
			"graphics.bloom": {
				"type": "bool",
				"default": false,
				"title": "辉光",
				"description": "开启场景定义的高光辉光。",
				"audience": "local",
				"apply": "immediate",
				"overridable": true,
				"control": "toggle"
			},
			"graphics.render_scale": {
				"type": "float",
				"default": 1,
				"title": "三维渲染比例",
				"description": "不影响 UI；低于 1 提速，高于 1 超采样。",
				"audience": "local",
				"apply": "immediate",
				"overridable": true,
				"min": 0.5,
				"max": 2,
				"step": 0.05,
				"control": "number"
			},
			"ui.player_cursors": {
				"type": "bool",
				"default": true,
				"title": "显示其他玩家鼠标",
				"description": "仅对接入协议鼠标组件的游戏生效，不影响他人看到自己的鼠标。",
				"audience": "local",
				"apply": "immediate",
				"overridable": true,
				"control": "toggle"
			}
		},
		"layout": [
			{
				"id": "graphics",
				"title": "画面",
				"expanded": true,
				"children": [
					{
						"field": "graphics.quality"
					},
					{
						"id": "effects",
						"title": "独立画面效果",
						"expanded": false,
						"children": [
							{
								"field": "graphics.shadows"
							},
							{
								"field": "graphics.pcss"
							},
							{
								"field": "graphics.ao"
							},
							{
								"field": "graphics.taa"
							},
							{
								"field": "graphics.bloom"
							}
						]
					},
					{
						"field": "graphics.render_scale"
					}
				]
			},
			{
				"id": "interface",
				"title": "界面",
				"expanded": true,
				"children": [
					{
						"field": "ui.player_cursors"
					}
				]
			}
		]
	}
