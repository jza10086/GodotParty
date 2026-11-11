## Playlist-owned room editor. Zero rounds stays automatic in saved rules and presets.
extends VBoxContainer
const NumberRow: PackedScene = preload("res://core/ui/settings/number.tscn")
const ToggleRow: PackedScene = preload("res://core/ui/settings/toggle.tscn")
var _value: Dictionary
var _fields: Dictionary
var _editable: bool
var _pool_count: int
var _manual_rounds: int
var _rounds: Control
var _avoid_repeat: Control
var _interval: Control

func _ready() -> void:
	%Automatic.toggled.connect(_automatic_changed)

func configure(value: Dictionary, editable: bool, context: Dictionary) -> void:
	_value = value.duplicate(true)
	_fields = context.schema.fields
	_editable = editable
	_pool_count = context.pools.get("minigames", []).size()
	_manual_rounds = maxi(1, _pool_count if value.rounds == 0 else int(value.rounds))
	%Automatic.set_value_silently(value.rounds == 0)
	%Automatic.disabled = not editable
	_build_rounds()
	_avoid_repeat = _row(%AvoidSlot, ToggleRow, "avoid_repeat", value.avoid_repeat, editable)
	%AvoidSlot.visible = value.rotation == "随机"
	%RepeatHelp.visible = %AvoidSlot.visible
	_interval = _row(%IntervalSlot, NumberRow, "interval", value.interval, editable)

func _row(slot: VBoxContainer, scene: PackedScene, key: String, value: Variant, editable: bool, overrides: Dictionary = {}) -> Control:
	for child: Node in slot.get_children():
		slot.remove_child(child)
		child.queue_free()
	var field: Dictionary = _fields[key].duplicate(true)
	field.key = key
	field.merge(overrides, true)
	var row: Control = scene.instantiate()
	slot.add_child(row)
	row.configure(field, value, editable)
	return row

func _build_rounds() -> void:
	var automatic: bool = %Automatic.button_pressed
	_rounds = _row(%RoundsSlot, NumberRow, "rounds", _pool_count if automatic else _manual_rounds, _editable and not automatic, {"min": 0 if automatic else 1, "max": maxi(100, _pool_count) if automatic else 100})

func _automatic_changed(automatic: bool) -> void:
	if automatic:
		_rounds.flush()
		_manual_rounds = int(_rounds.get_value())
	_build_rounds()

func get_value() -> Dictionary:
	_rounds.flush()
	_interval.flush()
	var result: Dictionary = _value.duplicate(true)
	result.rounds = 0 if %Automatic.button_pressed else int(_rounds.get_value())
	result.avoid_repeat = _avoid_repeat.get_value()
	result.interval = _interval.get_value()
	return result
