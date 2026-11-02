## A compact setting/group row. Folded children and inherited editor drafts remain alive.
extends VBoxContainer
signal inheritance_changed(inherited: bool)
var inherited: bool = false
var _expanded: bool = true
var _enabled: bool = true
var _field_mode: bool = false
var _has_children: bool = true
var _children_available: bool = true
var _open: bool = true
var _reveal: float = 1.0
var _motion: Tween
var _hovered: bool = false
var _pressed_here: bool = false

func _ready() -> void:
	%HeaderHit.gui_input.connect(_fold_input)
	%Header.gui_input.connect(_header_input)
	%Header.focus_entered.connect(_highlight_header)
	%Header.focus_exited.connect(_highlight_header)
	%HeaderHit.mouse_entered.connect(_set_hovered.bind(true))
	%HeaderHit.mouse_exited.connect(_set_hovered.bind(false))
	%Padding.reparent(%Clip, false)
	%Padding.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	%Padding.offset_top = 6.0
	%Padding.minimum_size_changed.connect(_sync_height)
	_sync_height()

func configure(title: String, expanded: bool, show_inherit: bool = false, inherit_value: bool = false, inherit_label: String = "继承协议") -> void:
	_expanded = expanded
	inherited = inherit_value
	%Title.text = title
	%Inherit.visible = show_inherit
	%Inherit.text = inherit_label
	%Inherit.set_value_silently(inherited)
	%Inherit.toggled.connect(func(on: bool) -> void:
		inherited = on
		_refresh()
		inheritance_changed.emit(on))
	_refresh()

func set_field(editor: Control, has_children: bool) -> void:
	_field_mode = true
	_has_children = has_children
	%Editor.add_child(editor)
	_refresh()

func set_available(enabled: bool, reason: String = "") -> void:
	_enabled = enabled
	%Summary.text = reason
	_refresh()

func set_children_available(value: bool) -> void:
	_children_available = value
	_refresh()

func is_available() -> bool:
	return _enabled and not inherited

func set_inheritance(value: bool) -> void:
	inherited = value
	%Inherit.set_value_silently(value)
	_refresh()

func set_inheritance_editable(enabled: bool) -> void:
	%Inherit.disabled = not enabled

func body() -> VBoxContainer:
	return %Body

func can_fold() -> bool:
	return _has_children and _children_available and is_available()

func owns_fold_target(control: Control) -> bool:
	return can_fold() and %Header.get_focus_mode_with_override() == Control.FOCUS_ALL and (%HeaderHit == control or %HeaderHit.is_ancestor_of(control))

func is_expanded() -> bool:
	return _open

func toggle_fold() -> void:
	if can_fold():
		_expanded = not _expanded
		_refresh()

func _set_hovered(value: bool) -> void:
	_hovered = value
	_highlight_header()

func _highlight_header() -> void:
	var highlighted: bool = can_fold() and is_inside_tree() and (%Header.has_focus() or _hovered)
	%Title.theme_type_variation = &"FoldHeaderActive" if highlighted else &"FoldHeader"

## Only this header receives fold clicks. The body and nested headers are separate siblings.
func _fold_input(event: InputEvent) -> void:
	if not can_fold() or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_pressed_here = true
		%Header.grab_focus()
	elif _pressed_here and Rect2(Vector2.ZERO, %HeaderHit.size).has_point(event.position):
		toggle_fold()
	if not event.pressed:
		_pressed_here = false
	%HeaderHit.accept_event()

func _header_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_pressed(&"ui_accept"):
		toggle_fold()
		%Header.accept_event()

func _refresh() -> void:
	var enabled: bool = is_available()
	var open: bool = enabled and _children_available and _expanded and _has_children
	%Header.focus_mode = Control.FOCUS_ALL if can_fold() else Control.FOCUS_NONE
	%HeaderHit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_fold() else Control.CURSOR_ARROW
	_highlight_header()
	%Title.modulate.a = 1.0 if enabled else 0.45
	%Editor.modulate.a = 1.0 if enabled else 0.45
	%Summary.modulate.a = 0.6
	%Editor.visible = _field_mode and not inherited
	%Summary.visible = inherited and not %Summary.text.is_empty()
	if open == _open:
		return
	_open = open
	if _motion:
		_motion.kill()
	var clip: Control = %Clip
	if not _has_children or not is_node_ready() or not is_visible_in_tree():
		_finish_fold(open)
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if not open and focus != null and clip.is_ancestor_of(focus):
		if not can_fold():
			focus.release_focus()
		else:
			%Header.grab_focus()
	clip.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	clip.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	clip.show()
	_motion = create_tween()
	_motion.tween_method(_set_reveal, _reveal, float(open), 0.22 * absf(float(open) - _reveal)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_callback(_finish_fold.bind(open))

func _finish_fold(open: bool) -> void:
	%Clip.visible = open
	%Clip.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	%Clip.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	_set_reveal(float(open))

func _set_reveal(amount: float) -> void:
	_reveal = amount
	_sync_height()

## Nested panels and wrapped text can change height while the parent is moving.
func _sync_height() -> void:
	var minimum: Vector2 = %Padding.get_combined_minimum_size()
	%Padding.offset_bottom = %Padding.offset_top + minimum.y
	%Clip.custom_minimum_size = Vector2(minimum.x, ceilf((%Padding.offset_top + minimum.y) * _reveal))
