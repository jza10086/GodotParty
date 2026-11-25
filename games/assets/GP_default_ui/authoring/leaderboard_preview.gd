## Authoring preview for SettlementView (multi-metric) and PartyMiniLeaderboard (4/8/12 players).
extends Control

const SAMPLE_NAMES: PackedStringArray = [
	"小林", "阿木", "白露", "星野",
	"青禾", "苏墨", "南枝", "景行",
	"知夏", "长风", "明川", "清欢"
]
const SAMPLE_COLORS: Array[Color] = [
	Color("#ff6673"), Color("#4cd97b"), Color("#4da6ff"), Color("#2be3f0"),
	Color("#c77dff"), Color("#ffe047"), Color("#ff9442"), Color("#ff80c4"),
	Color("#b4f046"), Color("#8d96ff"), Color("#f4f7fb"), Color("#a6b7cc"),
]

var _count: int = 4
var _mode: String = "settlement"

@onready var _settlement: Control = %SettlementView
@onready var _mini: PartyMiniLeaderboard = %MiniLeaderboard

func _ready() -> void:
	%ModeSettlement.pressed.connect(func() -> void: _set_mode("settlement"))
	%ModeMini.pressed.connect(func() -> void: _set_mode("mini"))
	%Count4.pressed.connect(func() -> void: _set_count(4))
	%Count8.pressed.connect(func() -> void: _set_count(8))
	%Count12.pressed.connect(func() -> void: _set_count(12))
	_refresh()

func _set_mode(next_mode: String) -> void:
	_mode = next_mode
	_refresh()

func _set_count(next_count: int) -> void:
	_count = next_count
	_refresh()

func _refresh() -> void:
	var rows: Array[Dictionary] = []
	var mini_entries: Array[Dictionary] = []
	for index: int in _count:
		var gold: int = 2400 - index * 170
		var diamonds: int = maxi(0, 6 - index / 2)
		var score: int = gold + diamonds * 200
		var delta_gold: int = 350 - index * 45
		rows.append({
			"player_id": "p%d" % (index + 1),
			"name": SAMPLE_NAMES[index],
			"rank": index + 1,
			"color": SAMPLE_COLORS[index],
			"is_self": index == 1,
			"connected": index != _count - 1 or _count <= 4,
			"metrics": {"gold": gold, "diamonds": diamonds, "score": score},
			"deltas": {"gold": delta_gold, "diamonds": 1 if index < 3 else 0},
		})
		mini_entries.append({
			"rank": index + 1,
			"name": SAMPLE_NAMES[index],
			"score": score,
			"color": SAMPLE_COLORS[index],
			"is_self": index == 1,
			"connected": index != _count - 1 or _count <= 4,
		})
	_settlement.visible = _mode == "settlement"
	_mini.visible = _mode == "mini"
	if _mode == "settlement":
		_settlement.configure({
			"title": "本轮结算",
			"subtitle": "第 3 / 5 轮",
			"columns": [
				{"key": "gold", "title": "金币", "format": "integer", "animated": true},
				{"key": "diamonds", "title": "钻石", "format": "integer", "width": 160.0},
				{"key": "score", "title": "总积分", "format": "integer", "animated": true},
			],
			"rows": rows,
		})
		_settlement.set_countdown(5.0)
	else:
		_mini.set_entries(mini_entries)
