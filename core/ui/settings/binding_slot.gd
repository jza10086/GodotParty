## Primary/alternate keyboard or enumerated mouse input. No persistence.
extends VBoxContainer
signal changed()
const MOUSE_NAMES: Array[String] = ["鼠标左键", "鼠标右键", "鼠标中键", "滚轮向上", "滚轮向下", "滚轮向左", "滚轮向右", "鼠标侧键 1", "鼠标侧键 2"]
var _editable: bool = true

func configure(value: Dictionary, editable: bool, combinations: bool) -> void:
	%Capture.allow_combinations = combinations
	%Capture.configure(value if value.get("kind") == "key" else {})
	%Kind.add_item("键盘")
	%Kind.add_item("鼠标")
	%Kind.select(1 if value.get("kind") == "mouse" else 0)
	%Mouse.add_item("未设置")
	for caption: String in MOUSE_NAMES:
		%Mouse.add_item(caption)
	%Mouse.select(int(value.code) if value.get("kind") == "mouse" else 0)
	%Kind.item_selected.connect(func(_index: int) -> void:
		_refresh()
		changed.emit())
	%Mouse.item_selected.connect(func(_index: int) -> void: changed.emit())
	%Capture.binding_changed.connect(func(_value: Dictionary) -> void: changed.emit())
	%Clear.pressed.connect(func() -> void:
		%Capture.configure({})
		%Mouse.select(0)
		changed.emit())
	set_editable(editable)
	_refresh()

func set_editable(editable: bool) -> void:
	_editable = editable
	%Kind.disabled = not editable
	%Mouse.disabled = not editable
	%Capture.disabled = not editable
	%Clear.visible = editable
	if not editable:
		%Capture.cancel()

func get_value() -> Dictionary:
	if %Kind.selected == 0:
		return %Capture.binding.duplicate()
	return {} if %Mouse.selected == 0 else {"kind": "mouse", "code": %Mouse.selected}

func _refresh() -> void:
	%Capture.visible = %Kind.selected == 0
	%Mouse.visible = %Kind.selected == 1
	%Capture.cancel()
