## Business declarations produce compact rows. The workspace presents their top-level categories.
extends VBoxContainer
signal field_changed(key: String, value: Variant)
signal help_requested(title: String, description: String, detail: String)
signal rebuilt()
signal category_reset(keys: Array[String])
const Schema = preload("res://core/config/party_schema.gd")
const Row = preload("res://core/ui/settings/setting_row.gd")
const Section = preload("res://core/ui/settings/setting_section.gd")
const SectionScene: PackedScene = preload("res://core/ui/settings/setting_section.tscn")
## Scene-owned controls appended below a group's fields and retained across draft rebuilds.
var group_footers: Dictionary[String, Control] = {}
var _entries: Dictionary = {}
var _groups: Dictionary = {}
var _pages: Array[Dictionary] = []
var _schema: Dictionary
var _context: Dictionary
var _editable: bool
var _error: Label
var _selected_key: String = ""

func configure(value: Dictionary, editable: bool, context: Dictionary) -> void:
	_schema = context.schema
	_context = context
	_editable = editable
	_selected_key = ""
	for footer: Control in group_footers.values():
		footer.reparent(self, false)
	for child: Node in %Entries.get_children():
		%Entries.remove_child(child)
		child.queue_free()
	_entries.clear()
	_groups.clear()
	_pages.clear()
	_build(_schema.layout, %Entries, value, [], "")
	for id: String in group_footers:
		group_footers[id].reparent(_groups[id].section.body(), false)
	_error = %Error
	_error.hide()
	_refresh_conditions()
	rebuilt.emit()

func _build(layout: Array, parent: VBoxContainer, values: Dictionary, ancestors: Array, category: String) -> void:
	for spec: Dictionary in layout:
		if spec.has("field") and _schema.fields[spec.field].audience != _context.get("audience", "room"):
			continue
		var section: Section = SectionScene.instantiate()
		var page_id: String = category
		if category.is_empty():
			page_id = spec.get("id", spec.get("field", ""))
		var context: Dictionary = {"spec": spec, "section": section}
		if spec.has("field"):
			var key: String = spec.field
			var field: Dictionary = _schema.fields[key].duplicate(true)
			field.key = key
			var base: Variant = _context.get("base", {}).get(key, Schema.normalize(field, field.default).value)
			var inherit: bool = _context.get("inherit", false) and not field.get("readonly", false)
			section.configure(field.get("title", key), spec.get("expanded", true), inherit, inherit and not values.has(key), _context.get("inherit_label", "继承协议"))
			parent.add_child(section)
			var row: Row = load("res://core/ui/settings/" + Schema.control_for(field) + ".tscn").instantiate()
			row.configure(field, values.get(key, base), editable_field(field))
			row.get_node("%Label").hide()
			section.set_field(row, not spec.get("children", []).is_empty())
			_entries[key] = {"row": row, "section": section, "field": field, "base": base, "spec": spec, "ancestors": ancestors.duplicate(), "category": page_id}
			row.value_changed.connect(func(next: Variant) -> void:
				_refresh_conditions()
				show_help(key)
				field_changed.emit(key, next))
			section.inheritance_changed.connect(func(_inherited: bool) -> void:
				_refresh_conditions()
				show_help(key)
				field_changed.emit(key, effective_value(key)))
			_watch(section.get_node("%Header"), key)
		else:
			section.configure(spec.title, spec.get("expanded", true))
			parent.add_child(section)
			_groups[spec.id] = {"section": section, "spec": spec, "ancestors": ancestors.duplicate()}
		if spec.has("children"):
			_build(spec.children, section.body(), values, ancestors + [context], page_id)
		if not spec.has("field") and section.body().get_child_count() == 0:
			parent.remove_child(section)
			section.queue_free()
			_groups.erase(spec.id)
			continue
		if category.is_empty():
			_pages.append({"id": page_id, "title": _schema.fields[spec.field].get("title", spec.field) if spec.has("field") else spec.title, "section": section, "group": not spec.has("field")})

func categories() -> Array[Dictionary]:
	return _pages

func select_category(id: String) -> void:
	for page: Dictionary in _pages:
		page.section.visible = page.id == id
	for key: String in _entries:
		if _entries[key].category == id:
			show_help(key)
			break

func reset_category(id: String) -> void:
	var values: Dictionary = explicit_values()
	var keys: Array[String] = []
	for key: String in _entries:
		if _entries[key].category == id and editable_field(_entries[key].field):
			values.erase(key)
			keys.append(key)
	configure(values, _editable, _context)
	category_reset.emit(keys)

func reset_defaults() -> void:
	var values: Dictionary = explicit_values()
	var keys: Array[String] = []
	for key: String in _entries:
		if editable_field(_entries[key].field):
			values.erase(key)
			keys.append(key)
	configure(values, _editable, _context)
	category_reset.emit(keys)

func editable_field(field: Dictionary) -> bool:
	return _editable and not field.get("readonly", false) and field.key not in _context.get("locked", []) and (not _context.get("overrides", false) or field.overridable)

func effective_value(key: String) -> Variant:
	var entry: Dictionary = _entries[key]
	return entry.base if entry.section.inherited else entry.row.get_value()

func _condition(spec: Dictionary) -> bool:
	return not spec.has("enabled_when") or effective_value(spec.enabled_when.field) == spec.enabled_when.equals

func _ancestors_enabled(ancestors: Array) -> bool:
	for ancestor: Dictionary in ancestors:
		if not _condition(ancestor.spec) or ancestor.section.inherited:
			return false
	return true

func _refresh_conditions() -> void:
	for group: Dictionary in _groups.values():
		var enabled: bool = _condition(group.spec) and _ancestors_enabled(group.ancestors)
		group.section.set_available(enabled, "" if enabled else group.spec.get("disabled_reason", "当前选项下不适用"))
	for entry: Dictionary in _entries.values():
		var enabled: bool = _condition(entry.spec) and _ancestors_enabled(entry.ancestors)
		entry.section.set_available(enabled, ("沿用：" + Row.describe(entry.field, entry.base)) if entry.section.inherited else "")
		entry.section.set_inheritance_editable(enabled and editable_field(entry.field))
		entry.row.set_editable(enabled and not entry.section.inherited and editable_field(entry.field))
		if entry.spec.has("children"):
			entry.section.set_children_available(entry.spec.children.any(func(child: Dictionary) -> bool: return _condition(child)))
	if not _selected_key.is_empty():
		show_help(_selected_key)

func _watch(node: Node, key: String) -> void:
	if node is Control:
		node.mouse_entered.connect(show_help.bind(key))
		node.focus_entered.connect(show_help.bind(key))
	for child: Node in node.get_children():
		_watch(child, key)

func show_help(key: String) -> void:
	_selected_key = key
	var entry: Dictionary = _entries[key]
	var field: Dictionary = entry.field
	var instructions: Dictionary = {
		"toggle": "开启或关闭此选项。",
		"select": "从下拉列表中选择一个选项。",
		"text": "输入文本；修改会保留在草稿中。",
		"number": "直接输入数值，或拖动滑条进行调整。",
		"numbers": "分别调整各个分量的数值。",
		"switches": "每个开关独立选择，可以同时启用多项。",
		"color": "选择颜色，并按设置允许的范围调整透明度。",
		"path": "点击浏览，从系统窗口中选择文件或目录。",
		"binding": "选择键盘或鼠标；主键和备用键均可触发同一个操作。录入时 Esc 取消。"
	}
	var detail: String = "当前值：" + Row.describe(field, effective_value(key))
	if field.get("readonly", false):
		detail += "\n固定设置，仅供查看。"
	elif entry.section.inherited:
		detail += "\n" + _context.get("inherit_label", "继承协议") + "已开启，关闭后可单独编辑。"
	if not _condition(entry.spec) or not _ancestors_enabled(entry.ancestors):
		detail += "\n" + entry.spec.get("disabled_reason", "此项受上级设置限制，当前不可编辑。")
	help_requested.emit(field.get("title", key), field.get("description", instructions[Schema.control_for(field)]), detail)

func flush() -> void:
	for entry: Dictionary in _entries.values():
		entry.row.flush()

func get_value() -> Dictionary:
	flush()
	var values: Dictionary = {}
	for key: String in _entries:
		values[key] = effective_value(key)
	return values

func explicit_values() -> Dictionary:
	flush()
	var values: Dictionary = {}
	for key: String in _entries:
		var entry: Dictionary = _entries[key]
		if not entry.section.inherited and not entry.field.get("readonly", false):
			values[key] = entry.row.get_value()
	return values

func inherit_all(inherit: bool) -> void:
	for entry: Dictionary in _entries.values():
		if editable_field(entry.field):
			entry.section.set_inheritance(inherit)
	_refresh_conditions()

func get_field_control(key: String) -> Control:
	return _entries[key].row

func get_section(key: String) -> Control:
	return _entries[key].section

func show_error(message: String) -> void:
	_error.text = message
	_error.visible = not message.is_empty()
