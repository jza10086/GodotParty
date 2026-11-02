extends ColorRect

signal closed
signal key_pressed

@onready var single: LineEdit = %Single
@onready var multi: TextEdit = %Multi
@onready var text_keys: VBoxContainer = %Keys.get_node("TextKeys")
@onready var number_keys: VBoxContainer = %Keys.get_node("NumberKeys")
var keys: VBoxContainer

var _target: Control
var _letters: Array[Button] = []
var _uppercase: bool = false
var _current: Button
var _highlighted: Button
var _pointer: bool = false
var _column_x: float = NAN


func _ready() -> void:
	for layout: VBoxContainer in [text_keys, number_keys]:
		for row in layout.get_children():
			for button: Button in row.get_children():
				_bind_key(button)
	if visible:
		_show_keys(false)


func open_for(field: Control) -> void:
	_target = field
	var numeric: bool = field.get_parent() is SpinBox
	single.visible = field is LineEdit
	multi.visible = field is TextEdit
	if field is LineEdit:
		single.secret = field.secret
		single.max_length = field.max_length
		single.text = field.text
		single.caret_column = field.caret_column
		if numeric:
			single.select_all()
		elif field.has_selection():
			single.select(field.get_selection_from_column(), field.get_selection_to_column())
	else:
		var editor: TextEdit = field as TextEdit
		multi.text = editor.text
		multi.set_caret_line(editor.get_caret_line())
		multi.set_caret_column(editor.get_caret_column())
		if editor.has_selection():
			multi.select(editor.get_selection_from_line(), editor.get_selection_from_column(),
				editor.get_selection_to_line(), editor.get_selection_to_column())
	_show_keys(numeric)


func _show_keys(numeric: bool) -> void:
	_pointer = false
	_column_x = NAN
	$Center/Panel.custom_minimum_size.x = 476 if numeric else 912
	text_keys.visible = not numeric
	number_keys.visible = numeric
	text_keys.get_node("%Newline").visible = multi.visible
	keys = number_keys if numeric else text_keys
	_current = number_keys.get_node("%Key5") if numeric else text_keys.get_node("%KeyQ")
	show()
	_current.grab_focus()


func _bind_key(button: Button) -> void:
	var caption: String = button.text
	if caption.to_upper() != caption:
		_letters.append(button)
	button.pressed.connect(_press_key.bind(button))
	button.focus_entered.connect(func() -> void:
		_current = button
		if not _pointer:
			_highlight(button))
	button.mouse_entered.connect(func() -> void:
		if _pointer:
			_point_to(button))
	button.mouse_exited.connect(func() -> void:
		if _pointer and _highlighted == button:
			_highlight(null))


func _press_key(button: Button) -> void:
	key_pressed.emit()
	match button.name:
		&"Left": _move_caret(-1)
		&"Right": _move_caret(1)
		&"Shift": _shift()
		&"Space": _insert(" ")
		&"Newline": _insert("\n")
		&"Backspace": _backspace()
		&"Cancel": finish(false)
		&"Done": finish(true)
		_: _insert(button.text)


func set_pointer_mode(enabled: bool) -> void:
	_pointer = enabled
	if enabled:
		var hovered: Control = get_viewport().gui_get_hovered_control()
		if hovered is Button and keys.is_ancestor_of(hovered):
			_point_to(hovered)
		else:
			_highlight(null)
	else:
		_current.grab_focus()
		_highlight(_current)


func _point_to(button: Button) -> void:
	_column_x = NAN
	button.grab_focus()
	_highlight(button)


func _highlight(button: Button) -> void:
	if _highlighted != null:
		_highlighted.theme_type_variation = &"KeyboardKey"
	_highlighted = button
	if button != null:
		button.theme_type_variation = &"KeyboardKeyActive"


func move_focus(side: Side) -> void:
	var row: Node = _current.get_parent()
	if side == SIDE_LEFT or side == SIDE_RIGHT:
		_column_x = NAN
		var step: int = -1 if side == SIDE_LEFT else 1
		var index: int = _current.get_index() + step
		while index >= 0 and index < row.get_child_count():
			var next: Button = row.get_child(index)
			if next.visible:
				next.grab_focus()
				break
			index += step
		return
	var row_index: int = row.get_index() + (-1 if side == SIDE_TOP else 1)
	if row_index < 0 or row_index >= keys.get_child_count():
		return
	# Keep the original column across wide keys such as Space.
	if is_nan(_column_x):
		_column_x = _current.get_global_rect().get_center().x
	var nearest: Button
	var best_distance: float = INF
	for candidate: Button in keys.get_child(row_index).get_children():
		if not candidate.visible:
			continue
		var rect: Rect2 = candidate.get_global_rect()
		var distance: float = absf(_column_x - clampf(_column_x, rect.position.x, rect.end.x))
		if distance < best_distance:
			nearest = candidate
			best_distance = distance
	nearest.grab_focus()


func _shift() -> void:
	_uppercase = not _uppercase
	for key in _letters:
		key.text = key.text.to_upper() if _uppercase else key.text.to_lower()


func _insert(characters: String) -> void:
	if single.visible:
		if single.has_selection():
			single.delete_text(single.get_selection_from_column(), single.get_selection_to_column())
			single.deselect()
		single.insert_text_at_caret(characters)
	else:
		multi.insert_text_at_caret(characters)


func _backspace() -> void:
	if multi.visible:
		multi.backspace()
	elif single.has_selection():
		single.delete_text(single.get_selection_from_column(), single.get_selection_to_column())
		single.deselect()
	elif single.caret_column > 0:
		single.delete_text(single.caret_column - 1, single.caret_column)


func _move_caret(step: int) -> void:
	if single.visible:
		single.deselect()
		single.caret_column = clampi(single.caret_column + step, 0, single.text.length())
		return
	multi.deselect()
	var line: int = multi.get_caret_line()
	var column: int = multi.get_caret_column() + step
	if column < 0 and line > 0:
		line -= 1
		column = multi.get_line(line).length()
	elif column > multi.get_line(line).length() and line + 1 < multi.get_line_count():
		line += 1
		column = 0
	multi.set_caret_line(line)
	multi.set_caret_column(clampi(column, 0, multi.get_line(line).length()))


func finish(commit: bool, submit: bool = true) -> void:
	var field: Control = _target
	if commit and is_instance_valid(field) and field.is_visible_in_tree():
		if field is LineEdit:
			if field.text != single.text:
				field.text = single.text
				field.text_changed.emit(field.text)
			field.caret_column = single.caret_column
			if submit:
				field.text_submitted.emit(field.text)
			elif field.get_parent() is SpinBox:
				var spin: SpinBox = field.get_parent()
				spin.apply()
		else:
			var editor: TextEdit = field as TextEdit
			if editor.text != multi.text:
				editor.select_all()
				editor.insert_text_at_caret(multi.text)
			editor.set_caret_line(multi.get_caret_line())
			editor.set_caret_column(multi.get_caret_column())
	hide()
	_highlight(null)
	_current = null
	if _uppercase:
		_shift()
	single.clear()
	multi.clear()
	_target = null
	closed.emit()
	if is_instance_valid(field) and field.is_visible_in_tree():
		field.grab_focus()
