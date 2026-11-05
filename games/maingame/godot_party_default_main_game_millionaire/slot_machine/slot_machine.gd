extends Control
## Standalone slot-machine presentation. Emits a result, never reads or changes a wallet.

signal spin_started
signal spin_finished(symbols: PackedInt32Array, multiplier: int)

const REEL_SCRIPT: GDScript = preload("res://games/maingame/godot_party_default_main_game_millionaire/slot_machine/slot_reel.gd")
const TRIPLE_MULTIPLIERS: PackedInt32Array = [5, 8, 12, 20, 50]

@export_range(0.5, 6.0, 0.1) var spin_duration: float = 2.4
@export_range(0.1, 1.5, 0.05) var stop_interval: float = 0.45
## Disable the local button when a future event controller supplies authoritative results.
@export var allow_random_spins: bool = true

var is_spinning: bool = false
var last_symbols: PackedInt32Array = []
var last_multiplier: int = 0
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _spin_tween: Tween

@onready var _reels: Array[Control] = [%ReelLeft, %ReelMiddle, %ReelRight]
@onready var _spin_button: Button = %SpinButton
@onready var _result_title: Label = %ResultTitle
@onready var _result_detail: Label = %ResultDetail
@onready var _status: Label = %Status
@onready var _rules: PanelContainer = %RulesPanel

func _ready() -> void:
	_random.randomize()
	_spin_button.disabled = not allow_random_spins
	_spin_button.pressed.connect(start_spin)
	%RulesButton.pressed.connect(_toggle_rules)
	%CloseRulesButton.pressed.connect(_toggle_rules)

## Runs a local demonstration; a nonnegative seed reproduces the symbol result.
## Returns false while another spin is active. No balance or reward is persisted.
func start_spin(random_seed: int = -1) -> bool:
	if is_spinning:
		return false
	if random_seed >= 0:
		_random.seed = random_seed
	var symbols: PackedInt32Array = []
	for index: int in range(3):
		symbols.append(_random.randi_range(0, REEL_SCRIPT.SYMBOL_COUNT - 1))
	return play_result(symbols)

## Animates three supplied symbol IDs (0 cherry, 1 lemon, 2 bell, 3 diamond, 4 seven).
## Future events can choose results outside this component. Invalid input is rejected.
func play_result(symbols: PackedInt32Array) -> bool:
	if is_spinning:
		return false
	if symbols.size() != 3:
		push_error("Slot machine requires exactly three symbols.")
		return false
	for symbol: int in symbols:
		if symbol < 0 or symbol >= REEL_SCRIPT.SYMBOL_COUNT:
			push_error("Slot machine symbol is outside 0..4.")
			return false
	is_spinning = true
	_rules.hide()
	%RulesShade.hide()
	_spin_button.disabled = true
	_spin_button.text = "好运转动中…"
	_status.text = "转动中"
	_result_title.text = "好运正在路上"
	_result_detail.text = "三只转轴将依次停下"
	_result_title.modulate = Color.WHITE
	_spin_tween = create_tween().set_parallel(true)
	for index: int in range(_reels.size()):
		var reel: Control = _reels[index]
		var start: float = fposmod(reel.reel_position, float(REEL_SCRIPT.SYMBOL_COUNT))
		reel.reel_position = start
		var distance: float = fposmod(float(symbols[index]) - start, float(REEL_SCRIPT.SYMBOL_COUNT))
		var target: float = start + float(7 + index * 2) * REEL_SCRIPT.SYMBOL_COUNT + distance
		_spin_tween.tween_property(reel, "reel_position", target, spin_duration + float(index) * stop_interval).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_spin_tween.chain().tween_callback(_finish_spin.bind(symbols.duplicate()))
	spin_started.emit()
	return true

## Pure combination rule for exactly three valid symbol IDs; values are demo multipliers.
static func combination_multiplier(symbols: PackedInt32Array) -> int:
	if symbols[0] == symbols[1] and symbols[1] == symbols[2]:
		return TRIPLE_MULTIPLIERS[symbols[0]]
	if symbols[0] == symbols[1] or symbols[1] == symbols[2] or symbols[0] == symbols[2]:
		return 1
	return 0

func _finish_spin(symbols: PackedInt32Array) -> void:
	last_symbols = symbols
	last_multiplier = combination_multiplier(symbols)
	for index: int in range(_reels.size()):
		_reels[index].reel_position = float(symbols[index])
	var names: PackedStringArray = []
	for symbol: int in symbols:
		names.append(REEL_SCRIPT.SYMBOL_NAMES[symbol])
	var combination: String = "  ·  ".join(names)
	if last_multiplier >= 5:
		_result_title.text = "幸运七大奖！" if symbols[0] == 4 else "三连同款！"
		_result_detail.text = "%s    /    演示倍率 ×%d" % [combination, last_multiplier]
		_result_title.modulate = Color("#ffe2a0")
	elif last_multiplier == 1:
		_result_title.text = "一对好搭档"
		_result_detail.text = "%s    /    演示倍率 ×1" % combination
	else:
		_result_title.text = "差一点点，再试一次"
		_result_detail.text = "%s    /    本次未连线" % combination
	_status.text = "已揭晓"
	is_spinning = false
	_spin_button.disabled = not allow_random_spins
	_spin_button.text = "再转一次"
	spin_finished.emit(symbols.duplicate(), last_multiplier)

func _toggle_rules() -> void:
	_rules.visible = not _rules.visible
	%RulesShade.visible = _rules.visible
	if _rules.visible:
		%CloseRulesButton.grab_focus()
	else:
		%RulesButton.grab_focus()
