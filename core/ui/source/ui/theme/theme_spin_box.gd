@tool
extends SpinBox
## SpinBox's native LineEdit does not inherit its parent's size variation.
## A private Theme bridges resolved defaults; child Theme Overrides still win.
var _editor_theme := Theme.new()

func _ready() -> void:
	theme_changed.connect(_sync_editor_theme)
	_sync_editor_theme()

func _sync_editor_theme() -> void:
	var editor := get_line_edit()
	if editor == null: return
	var changed := false
	_editor_theme.set_block_signals(true)
	if _editor_theme.default_font != get_theme_font("font"):
		_editor_theme.default_font = get_theme_font("font")
		changed = true
	if _editor_theme.default_font_size != get_theme_font_size("font_size"):
		_editor_theme.default_font_size = get_theme_font_size("font_size")
		changed = true
	for color in ["font_color", "font_selected_color", "font_uneditable_color", "font_placeholder_color", "caret_color", "selection_color"]:
		var value := get_theme_color(color, "LineEdit")
		if not _editor_theme.has_color(color, "LineEdit") or _editor_theme.get_color(color, "LineEdit") != value:
			_editor_theme.set_color(color, "LineEdit", value)
			changed = true
	_editor_theme.set_block_signals(false)
	if editor.theme != _editor_theme: editor.theme = _editor_theme
	if changed: _editor_theme.emit_changed()
