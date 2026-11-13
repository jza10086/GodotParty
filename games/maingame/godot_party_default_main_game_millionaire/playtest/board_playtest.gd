## F6 单玩家流程验证：非正式联机游戏，不接管框架会话；主地图不被加载或修改。
extends "res://games/maingame/godot_party_default_main_game_millionaire/map_preview.gd"
const HUD: PackedScene = preload("res://games/assets/godot_party_default_ui/source/ui/pages/monopoly_overlay.tscn")
const Dice = preload("res://games/maingame/godot_party_default_main_game_millionaire/playtest/dice_presenter.gd")
enum Phase { READY, ROLLING, MOVING, CHOICE, INTERACTION }
var phase: Phase = Phase.READY
var hud: Control
var dice: Node3D
## 使用原版形象包的 Cube；正式会话可用 api.load_asset 解析同一公开资源。
@export var pawn_scene: PackedScene = preload("res://games/protocols/godot_party_default_protocol/avatars/godot_party_default_avatars/character_3d.tscn")
var pawn: Node3D
var tile_id: String = "START"
var remaining: int = 0
var turn_number: int = 1
var last_roll: int = 0
# 仅为 F6 交互测试提供初始资金；不表示正式原版经济规则。
var money: int = 1000
var diamonds: int = 0
var items: int = 0
var properties: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _move_tween: Tween
var _event_id: String = ""
var _event_kind: String = ""
var _event_serial: int = 0
var _allowed: Array[String] = []
var _after_move: Dictionary = {}
var _hops: int = 0

func _ready() -> void:
	super._ready()
	_rng.randomize()
	assert(pawn_scene != null, "必须指定原版协议人物场景")
	pawn = pawn_scene.instantiate() as Node3D
	assert(pawn != null and pawn.has_method("apply_color"), "棋子必须是支持 apply_color 的 Node3D")
	pawn.name = "TestPlayer"
	pawn.apply_color(Color("#49b6f5"))
	add_child(pawn)
	pawn.position = _tile_position(tile_id)
	dice = Dice.new()
	dice.name = "DiceTray"
	dice.position = Vector3(2, 0.15, 3.4)
	add_child(dice)
	dice.landed.connect(_on_dice_landed)
	_sync("流程测试 · 第 1 回合，点击右下角掷骰")

func _build_hud() -> void:
	var overlay: CanvasLayer = HUD.instantiate()
	add_child(overlay)
	hud = overlay.get_node("HUD")
	hud.roll_requested.connect(_request_roll)
	hud.event_choice_requested.connect(_choose)
	hud.item_requested.connect(_item_requested)

func _reset_camera() -> void:
	_target = Vector3(3.5, 0, 2.7)
	_distance = 18.5
	_yaw = deg_to_rad(15)
	_pitch = deg_to_rad(55)
	camera.fov = 45
	camera.far = 100
	_refresh_camera()

func _tile_position(id: String) -> Vector3:
	var tile: Dictionary = board.find_tile(id)
	return Vector3(tile.x, 0.07, tile.z)

func _sync(message: String) -> void:
	hud.set_snapshot({
		"money": money, "diamonds": diamonds,
		"leaderboard": [{"id":"test-player", "name":"测试玩家", "money":money, "diamonds":diamonds, "is_self":true}],
		"inventory": [{"id":"test-item", "name":"测试道具", "count":items, "enabled":false, "reason":"本轮仅验证购买流程"}],
		"roll_enabled": phase == Phase.READY,
		"roll_hint": "第 %d 回合" % turn_number, "status":message})

func _request_roll() -> void:
	if phase != Phase.READY or dice.busy:
		return
	last_roll = _rng.randi_range(1, 6)
	phase = Phase.ROLLING
	_sync("骰子翻滚中…")
	if not dice.roll(last_roll, _rng.randi()):
		phase = Phase.READY
		_sync("骰子忙，请重试")

func _on_dice_landed(value: int) -> void:
	if phase != Phase.ROLLING or value != last_roll:
		return
	remaining = value
	_hops = 0
	phase = Phase.MOVING
	_sync("掷出 %d 点" % value)
	_advance()

func _advance() -> void:
	if phase != Phase.MOVING:
		return
	if remaining <= 0:
		_end_turn()
		return
	var tile: Dictionary = board.find_tile(tile_id)
	if tile.next.size() > 1:
		phase = Phase.CHOICE
		var choices: Array[Dictionary] = []
		for id: String in tile.next:
			var next: Dictionary = board.find_tile(id)
			choices.append({"id":id, "label":"前往 (%d, %d)" % [next.x, next.z]})
		_show("branch", "选择分叉路线", "分叉不消耗行动力，剩余 %d 步。" % remaining, choices)
	elif tile.next.size() == 1:
		_move_to(tile.next[0])
	else:
		phase = Phase.INTERACTION
		_show("end", "路线不可继续", "测试地图没有合法出口。", [{"id":"continue","label":"结束本回合"}])

func _move_to(id: String) -> void:
	var step: Dictionary = board.step(tile_id, id, remaining)
	if not step.ok:
		push_error("Rejected board step: " + str(step))
		_end_turn()
		return
	_hops += 1
	if _hops > board.tiles.size() * 2:
		_end_turn()
		return
	phase = Phase.MOVING
	_after_move = step
	_sync("移动中 · 剩余 %d 步" % remaining)
	_move_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_move_tween.tween_property(pawn, "position", _tile_position(id), 0.55).set_trans(Tween.TRANS_SINE)
	_move_tween.tween_callback(_arrived)

func _arrived() -> void:
	if phase != Phase.MOVING or _after_move.is_empty():
		return
	tile_id = _after_move.tile
	remaining = _after_move.remaining
	var interaction: String = _after_move.interaction
	var settlement: String = _after_move.settlement
	_after_move = {}
	if not interaction.is_empty():
		phase = Phase.INTERACTION
		if interaction == "shop":
			_show("shop", "经过商店", "测试道具 100 金币；购买或跳过后继续剩余行动。", [
				{"id":"buy","label":"购买测试道具（100）","enabled":money >= 100}, {"id":"continue","label":"跳过"}])
		else:
			_show("diamond", "经过钻石格", "测试价格：200 金币购买 1 钻石。", [
				{"id":"buy","label":"购买 1 钻石（200）","enabled":money >= 200}, {"id":"continue","label":"跳过"}])
	elif settlement == "property":
		phase = Phase.INTERACTION
		var owned: bool = properties.has(tile_id)
		_show("property", "停留地产", "测试价格：购置 150，升级 100；尚无其他玩家收租。", [
			{"id":"buy","label":"升级（100）" if owned else "购置（150）","enabled":money >= (100 if owned else 150)}, {"id":"continue","label":"跳过"}])
	elif settlement == "event":
		phase = Phase.INTERACTION
		_show("end", "随机事件占位", "停留触发；具体事件规则尚未设计，本次不改变资产。", [{"id":"continue","label":"结束回合"}])
	else:
		_advance()

func _show(kind: String, title: String, body_text: String, choices: Array[Dictionary]) -> void:
	_event_serial += 1
	_event_id = "turn-%d-event-%d" % [turn_number, _event_serial]
	_event_kind = kind
	_allowed.clear()
	for choice: Dictionary in choices:
		if choice.get("enabled", true):
			_allowed.append(choice.id)
	_sync("选择操作 · 剩余 %d 步" % remaining)
	if not hud.show_event({"id":_event_id,"title":title,"body":body_text,"choices":choices,"dismissible":false}):
		push_error(hud.last_error)

func _choose(id: String, choice: String) -> void:
	if id != _event_id or choice not in _allowed or phase not in [Phase.CHOICE, Phase.INTERACTION]:
		return
	var kind: String = _event_kind
	_event_id = ""
	_allowed.clear()
	hud.dismiss_event(id)
	if kind == "branch":
		_move_to(choice)
		return
	if choice == "buy":
		if kind == "shop" and money >= 100:
			money -= 100
			items += 1
		elif kind == "diamond" and money >= 200:
			money -= 200
			diamonds += 1
		elif kind == "property":
			var price: int = 100 if properties.has(tile_id) else 150
			if money >= price:
				money -= price
				properties[tile_id] = int(properties.get(tile_id, 0)) + 1
				set_property_color(tile_id, Color("#49b6f5"))
	phase = Phase.MOVING
	if kind in ["property", "end"]:
		_end_turn()
	else:
		_advance()

func _end_turn() -> void:
	remaining = 0
	turn_number += 1
	phase = Phase.READY
	_sync("第 %d 回合 · 上次掷出 %d 点" % [turn_number, last_roll])

func _item_requested(_id: String) -> void:
	pass

func _exit_tree() -> void:
	if _move_tween != null:
		_move_tween.kill()
	super._exit_tree()
