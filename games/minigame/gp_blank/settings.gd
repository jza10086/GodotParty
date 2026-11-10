## Local configuration UI examples; these values do not change the finish-button game.
extends RefCounted

static func schema() -> Dictionary:
	return {
		"schema_format": 3,
		"settings_version": 1,
		"fields": {
			"enabled": {
				"type": "bool",
				"control": "toggle",
				"default": true,
				"title": "开关示例",
				"audience": "local",
				"apply": "immediate"
			},
			"count": {
				"type": "int",
				"control": "number",
				"default": 4,
				"title": "整数：数量",
				"audience": "local",
				"apply": "immediate",
				"min": 0,
				"max": 20,
				"step": 1
			},
			"volume": {
				"type": "float",
				"control": "number",
				"default": 0.65,
				"title": "小数：百分比显示",
				"audience": "local",
				"apply": "immediate",
				"min": 0,
				"max": 1,
				"step": 0.01,
				"display_scale": 100,
				"suffix": "%"
			},
			"offset": {
				"type": "float",
				"control": "number",
				"default": 1.234567,
				"title": "小数：无界输入",
				"audience": "local",
				"apply": "immediate",
				"step": 0.01,
				"suffix": "秒"
			},
			"title": {
				"type": "string",
				"control": "text",
				"default": "空白测试小游戏",
				"title": "单行文本",
				"audience": "local",
				"apply": "immediate",
				"max_length": 40,
				"placeholder": "输入标题"
			},
			"notes": {
				"type": "string",
				"control": "text",
				"default": "第一行：UI 测试\n第二行：支持中文与换行",
				"title": "多行文本",
				"audience": "local",
				"apply": "immediate",
				"multiline": true,
				"max_length": 512
			},
			"difficulty": {
				"type": "string",
				"control": "select",
				"default": "normal",
				"title": "枚举：字符串",
				"audience": "local",
				"apply": "immediate",
				"values": [
					"easy",
					"normal",
					"hard"
				],
				"labels": [
					"简单",
					"普通",
					"困难"
				]
			},
			"frame_limit": {
				"type": "int",
				"control": "select",
				"default": 60,
				"title": "枚举：整数",
				"audience": "local",
				"apply": "immediate",
				"values": [
					30,
					60,
					120,
					0
				],
				"labels": [
					"30 FPS",
					"60 FPS",
					"120 FPS",
					"不限"
				]
			},
			"features": {
				"type": "array",
				"control": "switches",
				"default": [
					"背景音乐",
					"界面动画"
				],
				"title": "多选：开关组",
				"audience": "local",
				"apply": "immediate",
				"items": {
					"type": "string",
					"values": [
						"背景音乐",
						"界面动画",
						"粒子特效"
					],
					"labels": ["背景音乐", "界面动画", "粒子特效"]
				},
				"unique": true,
				"max_items": 3
			},
			"range": {
				"type": "array",
				"control": "numbers",
				"default": [
					2,
					8
				],
				"title": "区间：两个数值",
				"audience": "local",
				"apply": "immediate",
				"items": {
					"type": "float",
					"min": 0,
					"max": 10,
					"step": 0.1
				},
				"min_items": 2,
				"max_items": 2,
				"ordered": true,
				"labels": [
					"下限",
					"上限"
				],
				"description": "分别输入区间的下限与上限，下限不能高于上限。"
			},
			"position": {
				"type": "array",
				"control": "numbers",
				"default": [
					0.25,
					0.5,
					0.75
				],
				"title": "三分量：多个数值",
				"audience": "local",
				"apply": "immediate",
				"items": {
					"type": "float",
					"min": -10,
					"max": 10,
					"step": 0.01
				},
				"min_items": 3,
				"max_items": 3,
				"labels": [
					"X",
					"Y",
					"Z"
				],
				"description": "三个数值分别代表 X、Y、Z，复用同一种数字输入组件。"
			},
			"accent": {
				"type": "array",
				"control": "color",
				"default": [
					0.3,
					0.6,
					0.9,
					0.6
				],
				"title": "颜色：RGBA",
				"audience": "local",
				"apply": "immediate",
				"items": {
					"type": "float",
					"min": 0,
					"max": 1
				},
				"min_items": 4,
				"max_items": 4,
				"alpha": true
			},
			"solid_color": {
				"type": "array",
				"control": "color",
				"default": [
					0.9,
					0.6,
					0.3,
					1
				],
				"title": "颜色：固定不透明",
				"audience": "local",
				"apply": "immediate",
				"items": {
					"type": "float",
					"min": 0,
					"max": 1
				},
				"min_items": 4,
				"max_items": 4,
				"alpha": false
			},
			"image_path": {
				"type": "string",
				"control": "path",
				"default": "",
				"title": "文件选择",
				"audience": "local",
				"apply": "immediate",
				"path_mode": "file",
				"filters": [
					"*.png,*.jpg,*.webp ; 图片",
					"*.json ; JSON"
				]
			},
			"directory_path": {
				"type": "string",
				"control": "path",
				"default": "",
				"title": "目录选择",
				"audience": "local",
				"apply": "immediate",
				"path_mode": "directory"
			},
			"single_key": {
				"type": "array",
				"control": "binding",
				"default": [
					{
						"kind": "key",
						"code": 32,
						"physical": true
					},
					{
						"kind": "key",
						"code": 69,
						"physical": true
					}
				],
				"title": "单一按键＋备用键",
				"audience": "local",
				"apply": "immediate",
				"items": {
					"type": "object",
					"format": "binding"
				},
				"max_items": 2,
				"action": "blank_sample_single_key",
				"combinations": false
			},
			"combo_key": {
				"type": "array",
				"control": "binding",
				"default": [
					{
						"kind": "key",
						"code": 83,
						"physical": true,
						"ctrl": true
					},
					{
						"kind": "key",
						"code": 83,
						"physical": true,
						"ctrl": true,
						"shift": true
					}
				],
				"title": "组合按键",
				"audience": "local",
				"apply": "immediate",
				"items": {
					"type": "object",
					"format": "binding"
				},
				"max_items": 2,
				"action": "blank_sample_combo_key",
				"combinations": true,
				"description": "主键与备用键都支持 Ctrl、Alt、Shift、Meta 组合。点击录入按钮后按下组合键，Esc 取消录入。"
			},
			"mouse_key": {
				"type": "array",
				"control": "binding",
				"default": [
					{
						"kind": "mouse",
						"code": 1
					},
					{
						"kind": "mouse",
						"code": 2
					}
				],
				"title": "特殊按键：鼠标枚举",
				"audience": "local",
				"apply": "immediate",
				"items": {
					"type": "object",
					"format": "binding"
				},
				"max_items": 2,
				"action": "blank_sample_mouse_key",
				"combinations": false
			},
			"unbound_key": {
				"type": "array",
				"control": "binding",
				"default": [],
				"title": "空绑定：清空与重新录入",
				"audience": "local",
				"apply": "immediate",
				"items": {
					"type": "object",
					"format": "binding"
				},
				"max_items": 2,
				"action": "blank_sample_unbound_key",
				"combinations": true
			},
			"fixed_escape": {
				"type": "array",
				"control": "binding",
				"default": [
					{
						"kind": "key",
						"code": 4194305,
						"physical": false
					}
				],
				"title": "固定按键：Esc",
				"audience": "local",
				"apply": "immediate",
				"items": {
					"type": "object",
					"format": "binding"
				},
				"max_items": 2,
				"readonly": true,
				"description": "固定导航键，仅展示；不会保存到用户配置。"
			},
			"borderless": {
				"type": "bool",
				"control": "toggle",
				"default": false,
				"title": "模拟无边框全屏",
				"audience": "local",
				"apply": "immediate",
				"description": "此开关用于测试父项控制子项的布局。开启时分辨率子项隐藏，关闭后可重新展开。"
			},
			"resolution": {
				"type": "array",
				"control": "select",
				"default": [
					1920,
					1080
				],
				"title": "窗口分辨率",
				"audience": "local",
				"apply": "immediate",
				"items": {
					"type": "int",
					"min": 1
				},
				"min_items": 2,
				"max_items": 2,
				"values": [
					[
						1280,
						720
					],
					[
						1920,
						1080
					],
					[
						2560,
						1440
					]
				],
				"labels": [
					"1280 × 720",
					"1920 × 1080",
					"2560 × 1440"
				],
				"description": "调整窗口画面的输出分辨率。开启上方的无边框全屏示例后，父项的展开箭头会禁用；恢复窗口模式后保留之前的选择。"
			},
			"advanced_enabled": {
				"type": "bool",
				"control": "toggle",
				"default": false,
				"title": "启用高级设置",
				"audience": "local",
				"apply": "immediate"
			},
			"advanced_strength": {
				"type": "float",
				"control": "number",
				"default": 0.5,
				"title": "效果强度",
				"audience": "local",
				"apply": "immediate",
				"min": 0,
				"max": 1,
				"step": 0.01
			},
			"advanced_detail": {
				"type": "int",
				"control": "number",
				"default": 3,
				"title": "三级折叠中的数值",
				"audience": "local",
				"apply": "immediate",
				"min": 1,
				"max": 8
			}
		},
		"layout": [
			{
				"id": "scalars",
				"title": "基础设置",
				"expanded": true,
				"children": [
					{
						"field": "enabled"
					},
					{
						"field": "count"
					},
					{
						"field": "volume"
					},
					{
						"field": "offset"
					}
				]
			},
			{
				"id": "choices",
				"title": "选项设置",
				"expanded": false,
				"children": [
					{
						"field": "difficulty"
					},
					{
						"field": "frame_limit"
					}
				]
			},
			{
				"id": "components",
				"title": "多分量数值",
				"expanded": false,
				"children": [
					{
						"field": "range"
					},
					{
						"field": "position"
					}
				]
			},
			{
				"id": "paths",
				"title": "文件选择",
				"expanded": false,
				"children": [
					{
						"field": "image_path"
					}
				]
			},
			{
				"id": "input",
				"title": "按键绑定",
				"expanded": false,
				"children": [
					{
						"field": "single_key"
					},
					{
						"field": "combo_key"
					},
					{
						"field": "unbound_key"
					}
				]
			},
			{
				"id": "conditions",
				"title": "联动与层级",
				"expanded": true,
				"children": [
					{
						"field": "borderless",
						"children": [
							{
								"field": "resolution",
								"enabled_when": {
									"field": "borderless",
									"equals": false
								},
								"disabled_reason": "无边框全屏时沿用屏幕尺寸，保留窗口分辨率草稿。"
							}
						]
					},
					{
						"field": "advanced_enabled"
					},
					{
						"id": "advanced",
						"title": "高级效果（二级）",
						"expanded": true,
						"enabled_when": {
							"field": "advanced_enabled",
							"equals": true
						},
						"disabled_reason": "开启高级设置后可编辑。",
						"children": [
							{
								"field": "advanced_strength"
							},
							{
								"id": "detail",
								"title": "细节（三级）",
								"expanded": false,
								"children": [
									{
										"field": "advanced_detail"
									}
								]
							}
						]
					}
				]
			},
			{
				"id": "text",
				"title": "文字设置",
				"expanded": true,
				"children": [
					{
						"field": "title"
					},
					{
						"field": "notes"
					}
				]
			},
			{
				"id": "switches",
				"title": "多选开关",
				"expanded": true,
				"children": [
					{
						"field": "features"
					}
				]
			},
			{
				"id": "colors",
				"title": "颜色样式",
				"expanded": true,
				"children": [
					{
						"field": "accent"
					},
					{
						"field": "solid_color"
					}
				]
			},
			{
				"id": "directories",
				"title": "目录选择",
				"expanded": true,
				"children": [
					{
						"field": "directory_path"
					}
				]
			},
			{
				"id": "mouse",
				"title": "鼠标按键",
				"expanded": true,
				"children": [
					{
						"field": "mouse_key"
					}
				]
			},
			{
				"id": "fixed",
				"title": "固定按键",
				"expanded": true,
				"children": [
					{
						"field": "fixed_escape"
					}
				]
			}
		]
	}
