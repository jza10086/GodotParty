extends Node

const Backdrop = preload("res://core/ui/ambient_reveal/components/parts/popup_backdrop.tscn")


func _ready() -> void:
	get_parent().ready.connect(_install, CONNECT_ONE_SHOT)


func _install() -> void:
	var button: Node = get_parent()
	var popup: Window = button.get_popup()
	popup.add_child(Backdrop.instantiate())
	if button is ColorPickerButton:
		button.get_picker().theme = preload("res://core/ui/ambient_reveal/compact_picker_theme.tres")
