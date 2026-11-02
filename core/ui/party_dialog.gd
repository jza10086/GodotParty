## Fixed modal layout. The active content owns its draft and commit callbacks.
class_name GPPartyDialog
extends Control

signal confirmed()
signal canceled()
var title: String = ""
var dialog_text: String = ""
var ok_button_text: String = "确定"
var cancel_button_text: String = "取消"
var dialog_hide_on_ok: bool = true
var scroll_content: bool = true
@onready var content: VBoxContainer = %Content
@onready var _panel: Panel = %Panel
@onready var _title: Label = %Title
@onready var _ok: Button = %Confirm
@onready var _cancel: Button = %Cancel
var _requested_size: Vector2 = Vector2(1200, 860)
var _focus_modes: Dictionary = {}
var _previous_focus: Control

func _ready() -> void:
	add_to_group(&"framework_modal")
	_ok.text = ok_button_text
	if not scroll_content:
		%Scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cancel.pressed.connect(_cancel_pressed)
	_ok.pressed.connect(func() -> void:
		confirmed.emit()
		if dialog_hide_on_ok:
			hide())
	visibility_changed.connect(_visibility_changed)
	resized.connect(_fit)
	hide()

func get_ok_button() -> Button:
	return _ok

func popup_centered(requested: Vector2i = Vector2i(1200, 860)) -> void:
	_requested_size = Vector2(requested)
	_title.text = title
	_cancel.text = cancel_button_text
	%Message.visible = not dialog_text.is_empty()
	%Message.text = dialog_text
	_previous_focus = get_viewport().gui_get_focus_owner()
	_lock_background(get_tree().root)
	move_to_front()
	show()
	_fit()
	_cancel.grab_focus()

func _fit() -> void:
	if _panel == null:
		return
	_panel.size = _requested_size.min((size - Vector2(64, 64)).max(Vector2(320, 240)))
	_panel.position = (size - _panel.size) / 2.0

func _lock_background(node: Node) -> void:
	if node == self:
		return
	if node is Control and node.is_visible_in_tree() and node.focus_mode != Control.FOCUS_NONE:
		_focus_modes[node] = node.focus_mode
		node.focus_mode = Control.FOCUS_NONE
	for child: Node in node.get_children():
		_lock_background(child)

func _visibility_changed() -> void:
	if visible:
		return
	_restore_focus()

func _restore_focus() -> void:
	for node: Variant in _focus_modes:
		if is_instance_valid(node):
			node.focus_mode = _focus_modes[node]
	_focus_modes.clear()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	_previous_focus = null

func _cancel_pressed() -> void:
	hide()
	canceled.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		var modals: Array[Node] = get_tree().get_nodes_in_group("framework_modal")
		modals.reverse()
		for modal: Node in modals:
			if modal.is_visible_in_tree():
				if modal != self:
					return
				break
		get_viewport().set_input_as_handled()
		_cancel_pressed()

func _exit_tree() -> void:
	_restore_focus()
