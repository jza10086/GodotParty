## Reusable controls bind business declarations to draft values, never files or gameplay effects.
extends VBoxContainer
signal value_changed(value: Variant)
const Schema = preload("res://core/config/party_schema.gd")
var _field: Dictionary
var _control: String
var _parts: Array[Control] = []
var _choices: Array[CheckButton] = []
var _editable: bool = true
var _scale: float = 1.0

func configure(field: Dictionary, value: Variant, editable: bool) -> void:
	_field = field.duplicate(true)
	_control = Schema.control_for(field)
	%Label.text = field.get("title", field.key)
	tooltip_text = field.get("description", "")
	match _control:
		"toggle":
			%Value.set_pressed_no_signal(value)
			%Value.toggled.connect(func(_on: bool) -> void: _notify())
		"select":
			for index: int in range(field.values.size()):
				%Value.add_item(str(field.get("labels", field.values)[index]))
			%Value.select(field.values.find(value))
			%Value.item_selected.connect(func(_index: int) -> void: _notify())
		"text":
			%Value.visible = not field.get("multiline", false)
			%Multiline.visible = field.get("multiline", false)
			%Value.max_length = field.get("max_length", 4096)
			%Value.text = value
			%Multiline.text = value
			%Value.placeholder_text = field.get("placeholder", "")
			%Multiline.placeholder_text = field.get("placeholder", "")
			%Value.text_changed.connect(func(_text: String) -> void: _notify())
			%Multiline.text_changed.connect(_notify)
		"number":
			_scale = field.get("display_scale", 1.0)
			var spin: SpinBox = %Number
			spin.min_value = field.get("min", -1000000000.0) * _scale
			spin.max_value = field.get("max", 1000000000.0) * _scale
			spin.allow_lesser = not field.has("min")
			spin.allow_greater = not field.has("max")
			spin.step = 1.0 if field.type == "int" else 0.0
			spin.custom_arrow_step = field.get("step", 1.0 if field.type == "int" else 0.01) * _scale
			spin.suffix = field.get("suffix", "")
			spin.set_value_no_signal(value * _scale)
			spin.get_line_edit().focus_exited.connect(spin.apply)
			%Value.visible = field.has("min") and field.has("max")
			if %Value.visible:
				%Value.min_value = spin.min_value
				%Value.max_value = spin.max_value
				%Value.step = spin.custom_arrow_step
				%Value.set_value_no_signal(value * _scale)
				%Value.value_changed.connect(func(number: float) -> void: spin.value = number)
				spin.value_changed.connect(func(number: float) -> void: %Value.set_value_no_signal(number))
			spin.value_changed.connect(func(_number: float) -> void: _notify())
		"numbers":
			for index: int in range(value.size()):
				var part: Control = load("res://core/ui/settings/number_component.tscn").instantiate()
				var declaration: Dictionary = field.items.duplicate(true)
				declaration.key = str(index)
				declaration.title = field.labels[index] if index < field.get("labels", []).size() else str(index + 1)
				part.configure(declaration, value[index], editable)
				%Value.add_child(part)
				_parts.append(part)
				part.value_changed.connect(func(_next: Variant) -> void: _notify())
		"switches":
			for candidate: Variant in field.items.values:
				var choice: CheckButton = load("res://core/ui/settings/switch_option.tscn").instantiate()
				choice.text = str(candidate)
				choice.button_pressed = candidate in value
				choice.set_meta("value", candidate)
				%Value.add_child(choice)
				_choices.append(choice)
				choice.toggled.connect(func(_on: bool) -> void: _notify())
		"color":
			%Value.edit_alpha = field.get("alpha", true)
			%Value.color = Color(value[0], value[1], value[2], value[3])
			%Value.color_changed.connect(func(_color: Color) -> void: _notify())
		"path":
			%Value.text = value
			%Picker.access = FileDialog.ACCESS_FILESYSTEM
			%Picker.use_native_dialog = true
			%Picker.file_mode = FileDialog.FILE_MODE_OPEN_DIR if field.get("path_mode", "file") == "directory" else FileDialog.FILE_MODE_OPEN_FILE
			%Picker.filters = PackedStringArray(field.get("filters", []))
			%Browse.pressed.connect(func() -> void: %Picker.popup_centered_ratio(0.7))
			%Picker.file_selected.connect(_path_selected)
			%Picker.dir_selected.connect(_path_selected)
			%Clear.pressed.connect(func() -> void: _path_selected(""))
		"binding":
			%AlternateLabel.visible = not field.get("readonly", false)
			%Slot1.visible = not field.get("readonly", false)
			for index: int in range(2):
				var slot: Control = get_node("%Slot" + str(index))
				slot.configure(value[index] if index < value.size() else {}, editable, field.get("combinations", true))
				if field.get("readonly", false):
					slot.get_node("%Kind").hide()
				slot.changed.connect(_notify)
				_parts.append(slot)
	set_editable(editable)

func set_editable(editable: bool) -> void:
	_editable = editable and not _field.get("readonly", false)
	match _control:
		"toggle", "select", "color": %Value.disabled = not _editable
		"text":
			%Value.editable = _editable
			%Multiline.editable = _editable
		"number":
			%Number.editable = _editable
			%Value.editable = _editable
		"numbers", "binding":
			for part: Control in _parts:
				part.set_editable(_editable)
		"switches":
			for choice: CheckButton in _choices:
				choice.disabled = not _editable
		"path":
			%Browse.disabled = not _editable
			%Clear.disabled = not _editable

func flush() -> void:
	if _control == "number" and %Number.get_line_edit().has_focus():
		%Number.apply()
	elif _control == "numbers":
		for part: Control in _parts:
			part.flush()

func get_value() -> Variant:
	match _control:
		"toggle": return %Value.button_pressed
		"select": return _field.values[%Value.selected]
		"text": return %Multiline.text if _field.get("multiline", false) else %Value.text
		"number": return int(%Number.value / _scale) if _field.type == "int" else %Number.value / _scale
		"numbers", "binding":
			var values: Array = []
			for part: Control in _parts:
				values.append(part.get_value())
			if _control == "binding":
				while not values.is_empty() and values.back().is_empty():
					values.pop_back()
			return values
		"switches":
			var values: Array = []
			for choice: CheckButton in _choices:
				if choice.button_pressed:
					values.append(choice.get_meta("value"))
			return values
		"color":
			var color: Color = %Value.color
			return [color.r, color.g, color.b, color.a]
		"path": return %Value.text
	push_error("Unknown control: " + _control)
	return null

func _path_selected(path: String) -> void:
	%Value.text = path
	_notify()

func _notify() -> void:
	value_changed.emit(get_value())



static func describe(field: Dictionary, value: Variant) -> String:
	match Schema.control_for(field):
		"toggle": return "开启" if value else "关闭"
		"select":
			var index: int = field.values.find(value)
			return str(field.get("labels", field.values)[index])
		"binding":
			var labels: PackedStringArray = []
			for binding: Dictionary in value:
				if not binding.is_empty():
					labels.append(preload("res://core/ui/party_binding_button.gd").label_for(binding))
			return " / ".join(labels) if not labels.is_empty() else "未绑定"
		"color": return "#" + Color(value[0], value[1], value[2], value[3]).to_html()
		"path": return value.get_file() if not value.is_empty() else "未选择"
	return str(value).left(60)
