class_name SettingsPage
extends Control
## Reusable scene-based settings with schema-driven data binding. See docs/SETTINGS_API.zh-CN.md.
signal setting_changed(id: String, value: Variant)
signal back_requested
signal binding_conflict(id: String, slot: int, conflicting_id: String)
const KeyBinding = preload("res://games/assets/godot_party_default_ui/source/settings/key_binding.gd")
var _capture_id := ""
var _capture_slot := 0
var _capture_overlay: Control
var _capture_message: Label
var _capture_return_focus: Control
var _swallow_key := 0
var last_error := ""
var _schema: Array = []
var _entries: Dictionary = {}
var _tabs: Dictionary = {}
var _option_lists: Array = []
var _generation := 0

func _ready() -> void:
	$Back.pressed.connect(func(): cancel_binding_capture(); back_requested.emit())
	$Tabs.tab_changed.connect(func(_index): cancel_binding_capture())
	visibility_changed.connect(func():
		if not is_visible_in_tree(): cancel_binding_capture()
	)

func configure(tabs: Array) -> bool:
	last_error = ""
	var ids: Dictionary = {}
	var tab_ids: Dictionary = {}
	for tab in tabs:
		if not tab is Dictionary or not _valid_id(tab.get("id", "")) or tab_ids.has(tab.id):
			return _fail("Invalid or duplicate tab id")
		tab_ids[tab.id] = true
		if not tab.get("options", []) is Array: return _fail("Tab options must be an Array")
		if not _validate_options(tab.get("options", []), ids): return false
	for spec in ids.values():
		var condition: Variant = spec.get("visible_when", {})
		if not condition is Dictionary or (not condition.is_empty() and (not ids.has(condition.get("id", "")) or not condition.has("equals"))):
			return _fail("Invalid visible_when reference")
	if not _validate_binding_conflicts(ids): return false
	clear()
	_schema = tabs.duplicate(true)
	for tab in _schema:
		_build_tab(tab)
	_refresh_visibility()
	return true

func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b) and not ((a is int or a is float) and (b is int or b is float)): return false
	return a == b

func _valid_toggle(value: Variant) -> bool:
	return value is bool or ((value is int or value is float) and (value == 0 or value == 1))

func _valid_id(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()

func _fail(message: String) -> bool:
	last_error = message
	return false

func _validate_options(options: Array, ids: Dictionary) -> bool:
	for spec in options:
		if not spec is Dictionary or not _valid_id(spec.get("id", "")) or ids.has(spec.id):
			return _fail("Invalid or duplicate option id")
		if not spec.get("type", "") is String: return _fail("Option type must be a String")
		var type: String = spec.get("type", "")
		if type not in ["label", "select", "toggle", "number", "slider", "note", "divider", "action", "group", "keybinding", "bindings_header"]:
			return _fail("Unknown option type")
		if type == "note" and spec.has("font_role"):
			if not spec.font_role is String or not preload("res://core/ui/source/ui/theme/party_theme.gd").TYPE_SIZES.has(spec.font_role):
				return _fail("Unknown note font_role")
		if spec.has("callback") and not spec.callback is Callable:
			return _fail("callback must be a Callable")
		if type in ["number", "slider"]:
			for key in ["min", "max", "step", "value"]:
				if spec.has(key) and (not (spec[key] is float or spec[key] is int) or not is_finite(float(spec[key]))):
					return _fail("Numeric settings require finite numbers")
			if float(spec.get("min", 0)) > float(spec.get("max", 100)) or float(spec.get("step", 1)) <= 0:
				return _fail("Invalid numeric range or step")
		if type == "toggle" and spec.has("value") and not _valid_toggle(spec.value):
			return _fail("Toggle initial value must be bool or 0/1")
		if type == "select":
			var items: Variant = spec.get("items", [])
			if not items is Array or items.is_empty():
				return _fail("select requires nonempty items")
			var seen: Array = []
			for item in items:
				if not item is Dictionary or not item.has("label") or not item.has("value") or item.value in seen:
					return _fail("Invalid or duplicate select item value")
				seen.append(item.value)
			if spec.has("value") and spec.value not in seen:
				return _fail("Initial select value is not in items")
		if type == "keybinding":
			if not KeyBinding.valid_pair(spec.get("value", [0, 0])): return _fail("Keybinding requires two distinct valid keycodes (0 means unbound)")
			if not spec.get("conflict_scope", "global") is String: return _fail("conflict_scope must be a String")
		ids[spec.id] = spec
		if type in ["group", "keybinding"]:
			if spec.has("expanded") and not spec.expanded is bool: return _fail("Group expanded must be bool")
			if not spec.get("children", []) is Array: return _fail("Group children must be an Array")
			if not _validate_options(spec.get("children", []), ids): return false
	return true

func clear() -> void:
	cancel_binding_capture(false)
	_generation += 1
	_entries.clear()
	_tabs.clear()
	_option_lists.clear()
	_schema.clear()
	for child in $Tabs.get_children():
		$Tabs.remove_child(child)
		child.queue_free()

func add_tab(id: String, title: String) -> bool:
	var next := _schema.duplicate(true)
	_capture_values(next)
	next.append({"id": id, "title": title, "options": []})
	return configure(next)

func add_option(tab_id: String, spec: Dictionary, parent_group: String = "") -> bool:
	var next := _schema.duplicate(true)
	_capture_values(next)
	for tab in next:
		if tab.id == tab_id:
			if not tab.has("options"): tab.options = []
			if parent_group.is_empty():
				tab.options.append(spec)
			elif not _append_group(tab.options, parent_group, spec):
				return _fail("Unknown parent group in tab")
			return configure(next)
	return _fail("Unknown tab id")

func _append_group(options: Array, group_id: String, spec: Dictionary) -> bool:
	for option in options:
		if option.type in ["group", "keybinding"]:
			if option.id == group_id:
				if not option.has("children"): option.children = []
				option.children.append(spec)
				return true
			if _append_group(option.get("children", []), group_id, spec): return true
	return false

func _capture_values(tabs: Array) -> void:
	for tab in tabs: _capture_options(tab.get("options", []))

func _capture_options(options: Array) -> void:
	for spec in options:
		if _entries.has(spec.id):
			if _entries[spec.id].has("expander"): spec.expanded = _entries[spec.id].expander.button_pressed
			if _entries[spec.id].has("value"): spec.value = _entries[spec.id].value.duplicate(true) if _entries[spec.id].value is Array else _entries[spec.id].value
		if spec.type in ["group", "keybinding"]: _capture_options(spec.get("children", []))

func get_value(id: String) -> Variant:
	var value: Variant = _entries.get(id, {}).get("value", null)
	return value.duplicate(true) if value is Array or value is Dictionary else value

func get_values() -> Dictionary:
	var values: Dictionary = {}
	for id in _entries:
		if _entries[id].has("value"): values[id] = _entries[id].value
	return values.duplicate(true)

func get_control(id: String) -> Control:
	return _entries.get(id, {}).get("control", null)

func get_number_control(id: String) -> SpinBox:
	return _entries.get(id, {}).get("number", null)

func set_value(id: String, value: Variant, notify: bool = false) -> bool:
	if not _entries.has(id): return _fail("Unknown option id")
	var entry: Dictionary = _entries[id]
	var spec: Dictionary = entry.spec
	match spec.type:
		"number", "slider":
			if not (value is int or value is float) or not is_finite(float(value)): return _fail("Value must be finite numeric")
			value = clampf(snappedf(float(value), float(spec.get("step", 1))), float(spec.get("min", 0)), float(spec.get("max", 100)))
		"toggle":
			if not _valid_toggle(value): return _fail("Toggle requires bool or 0/1")
			value = bool(value)
		"select":
			var found := false
			for item in spec.items:
				if _same(item.value, value): found = true
			if not found: return _fail("Value is not in select items")
		"keybinding":
			if not KeyBinding.valid_pair(value): return _fail("Keybinding requires two distinct valid keycodes (0 means unbound)")
			var conflict := _binding_conflict_for(id, value)
			if not conflict.is_empty(): return _fail("Key already assigned to " + str(_entries[conflict].spec.get("label", conflict)))
			value = value.duplicate(true)
		"label": value = str(value)
		_: return _fail("This option has no settable value")
	var changed: bool = not _same(entry.get("value"), value)
	entry.value = value
	_sync(entry)
	_refresh_visibility()
	if notify and changed:
		var callback: Callable = spec.get("callback", Callable())
		# Emit after model and widgets agree; callbacks may rebuild/free this page.
		var generation := _generation
		if callback.is_valid(): callback.call(get_value(id), id)
		if is_instance_valid(self) and not is_queued_for_deletion() and generation == _generation: setting_changed.emit(id, get_value(id))
	return true

func _sync(entry: Dictionary) -> void:
	var control: Control = entry.control
	match entry.spec.type:
		"keybinding":
			for slot in range(2):
				entry.bindings[slot].text = KeyBinding.label(entry.value[slot])
				entry.bindings[slot].tooltip_text = str(entry.spec.get("label", entry.spec.id)) + (" · 主按键" if slot == 0 else " · 次要按键") + "：点击重新绑定"
		"label": control.text = str(entry.value)
		"toggle":
			control.set_pressed_no_signal(entry.value)
			control.sync_visual(entry.get("visual_initialized", false))
			entry.visual_initialized = true
		"number", "slider":
			control.set_value_no_signal(entry.value)
			entry.number.set_value_no_signal(entry.value)
		"select":
			for index in range(entry.spec.items.size()):
				if _same(entry.spec.items[index].value, entry.value): control.select(index)

func _changed(value: Variant, id: String, generation: int) -> void:
	if generation == _generation: set_value(id, value, true)

func _selected(index: int, id: String, generation: int) -> void:
	if generation == _generation: set_value(id, _entries[id].spec.items[index].value, true)

func _action(id: String, generation: int) -> void:
	if generation != _generation: return
	var callback: Callable = _entries[id].spec.get("callback", Callable())
	if callback.is_valid(): callback.call(id)

func _expanded(_value: bool, generation: int) -> void:
	if generation == _generation: _refresh_visibility()

func _component(name: String) -> Control:
	return (load("res://games/assets/godot_party_default_ui/source/settings/components/" + name + ".tscn") as PackedScene).instantiate()

func _build_tab(tab: Dictionary) -> void:
	var scroll := _component("tab_content") as ScrollContainer
	scroll.name = tab.id
	$Tabs.add_child(scroll)
	$Tabs.set_tab_title(scroll.get_index(), str(tab.get("title", tab.id)))
	var content: VBoxContainer = scroll.get_node("Padding/Content")
	_tabs[tab.id] = content
	_build_options(content, tab.get("options", []))

func _divider() -> ColorRect:
	return _component("divider") as ColorRect

func _build_options(parent: VBoxContainer, options: Array) -> void:
	var items: Array = []
	for spec in options:
		var divider: ColorRect
		if spec.type not in ["note", "divider"] and not items.is_empty():
			divider = _divider()
			divider.name = "AutoDivider_" + str(spec.id).validate_node_name()
			divider.set_meta("automatic_row_divider", true)
			divider.visible = false
			parent.add_child(divider)
		_build_option(parent, spec)
		items.append({"id": spec.id, "divider": divider})
	_option_lists.append(items)

func _build_option(parent: VBoxContainer, source: Dictionary) -> void:
	var spec := source.duplicate(true)
	var id: String = spec.id
	var type: String = spec.type
	var entry := {"spec": spec}
	_entries[id] = entry
	var control: Control
	var root_node: Control
	if type in ["divider", "note", "action", "group"]:
		control = _component(type)
		root_node = control
		if type == "note":
			control.text = str(spec.get("text", ""))
			if spec.has("font_role"): control.theme_type_variation = "PartyLabel" + str(spec.font_role)
			if spec.has("font_size"): control.add_theme_font_size_override("font_size", spec.font_size)
			if spec.has("height"): control.custom_minimum_size.y = spec.height
		elif type in ["action", "group"]:
			control.text = str(spec.get("label", id))
			if type == "action": control.pressed.connect(_action.bind(id, _generation))
			else:
				entry.expander = control
				control.set_pressed_no_signal(spec.get("expanded", false))
				control.toggled.connect(_expanded.bind(_generation))
	elif type in ["keybinding", "bindings_header"]:
		root_node = _build_binding_row(parent, spec, entry)
		control = entry.control
	else:
		root_node = _component(type + "_row")
		if spec.has("row_height"): root_node.custom_minimum_size.y = spec.row_height
		var label: Label = root_node.get_node("Label")
		label.text = str(spec.get("label", id))
		label.name = spec.get("label_name", "Label")
		if spec.has("label_width"): label.custom_minimum_size.x = spec.label_width
		control = root_node.get_node("Value")
		match type:
			"select":
				for item in spec.items:
					control.add_item(str(item.label))
					control.set_item_metadata(control.item_count - 1, item.value)
				control.item_selected.connect(_selected.bind(id, _generation))
			"toggle":
				if spec.has("off_text"): control.off_text = str(spec.off_text)
				if spec.has("on_text"): control.on_text = str(spec.on_text)
				control.toggled.connect(_changed.bind(id, _generation))
			"number", "slider":
				var spin: SpinBox = root_node.get_node("Number") if type == "slider" else control
				spin.min_value = spec.get("min", 0)
				spin.max_value = spec.get("max", 100)
				spin.step = spec.get("step", 1)
				spin.suffix = spec.get("suffix", "")
				spin.get_line_edit().focus_exited.connect(spin.apply)
				spin.value_changed.connect(_changed.bind(id, _generation))
				entry.number = spin
				if type == "slider":
					control.min_value = spin.min_value
					control.max_value = spin.max_value
					control.step = spin.step
					control.value_changed.connect(_changed.bind(id, _generation))
					spin.name = spec.get("number_name", "Number")
		control.name = spec.get("control_name", "Value")
	entry.control = control
	root_node.name = spec.get("node_name", id.validate_node_name())
	entry.root = root_node
	parent.add_child(root_node)
	if type == "group" or (type == "keybinding" and spec.has("children")):
		var details := _component("group_details")
		details.name = spec.get("details_name", id.validate_node_name() + "Details")
		parent.add_child(details)
		entry.details = details
		details.header_control = entry.expander
		_build_options(details.get_node("Rows"), spec.get("children", []))
	if type == "keybinding":
		entry.value = spec.get("value", [0, 0]).duplicate(true)
		_sync(entry)
	elif type in ["label", "number", "slider", "toggle", "select"]:
		var default: Variant = "" if type == "label" else (false if type == "toggle" else 0)
		if type == "select": default = spec.items[0].value
		set_value(id, spec.get("value", default))

func _refresh_visibility() -> void:
	for entry in _entries.values():
		if not entry.has("root"): continue
		var condition: Dictionary = entry.spec.get("visible_when", {})
		var showing: bool = condition.is_empty() or _same(get_value(str(condition.get("id", ""))), condition.get("equals"))
		entry.root.visible = showing
		if entry.has("details"):
			entry.details.visible = showing and entry.expander.button_pressed
			entry.expander.icon = preload("res://core/ui/components/assets/chevron_down.svg") if entry.expander.button_pressed else preload("res://core/ui/components/assets/chevron_right.svg")

	# Only separate neighboring visible rows. Notes and explicit dividers are
	# intentional section boundaries; neither receives an extra automatic line.
	# Inside a fold, short tree branches replace ordinary row separators. Only
	# the closing boundary of an expanded child group keeps its long stroke.
	for items in _option_lists:
		var previous_row := false
		var previous_expanded := false
		for item in items:
			var entry: Dictionary = _entries[item.id]
			var showing: bool = entry.root.visible
			var is_row: bool = entry.spec.type not in ["note", "divider"]
			if item.divider != null:
				var parent: Node = entry.root.get_parent()
				var nested := parent.name == "Rows" and parent.get_parent().has_method("closing_spine_global")
				item.divider.visible = showing and is_row and previous_row and (not nested or previous_expanded)
			if showing:
				previous_row = is_row
				previous_expanded = entry.has("details") and entry.details.visible and not entry.details.get_visible_rows().is_empty()

func _input(event: InputEvent) -> void:
	if _route_binding_input(event): return
	route_scroll_input(event)

func route_scroll_input(event: InputEvent) -> void:
	if is_capturing_binding() or not is_visible_in_tree() or $Tabs.get_tab_count() == 0: return
	if not event is InputEventMouseButton or not event.pressed or event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]: return
	for entry in _entries.values():
		if entry.control is OptionButton and entry.control.get_popup().visible: return
	var scroll: ScrollContainer = $Tabs.get_current_tab_control()
	if scroll.get_global_rect().has_point(event.position):
		var direction := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
		scroll.scroll_vertical += int(direction * 64 * maxf(event.factor, 1))
		get_viewport().set_input_as_handled()

func _validate_binding_conflicts(ids: Dictionary) -> bool:
	var scopes: Dictionary = {}
	for id in ids:
		var spec: Dictionary = ids[id]
		if spec.type != "keybinding": continue
		var scope: String = spec.get("conflict_scope", "global")
		if not scopes.has(scope): scopes[scope] = {}
		for code in spec.get("value", [0, 0]):
			if code == 0: continue
			if scopes[scope].has(code): return _fail("Duplicate binding in scope " + scope + ": " + KeyBinding.label(code))
			scopes[scope][code] = id
	return true

func _binding_conflict_for(id: String, pair: Array) -> String:
	var scope: String = _entries[id].spec.get("conflict_scope", "global")
	for other_id in _entries:
		var other: Dictionary = _entries[other_id]
		if other_id == id or other.spec.type != "keybinding" or not other.has("value"): continue
		if other.spec.get("conflict_scope", "global") != scope: continue
		for code in pair:
			if code != 0 and code in other.value: return other_id
	return ""

func _binding_label_width(parent: Control, base_width: float) -> float:
	# Only subtract actual indentation; the scene owns the base column width.
	var width := base_width
	var ancestor: Node = parent
	while ancestor != null and ancestor.name != "Padding":
		if ancestor is MarginContainer: width -= ancestor.get_theme_constant("margin_left")
		ancestor = ancestor.get_parent()
	return maxf(width, 80.0)

func _build_binding_row(parent: Control, spec: Dictionary, entry: Dictionary) -> HBoxContainer:
	var expandable: bool = spec.type == "keybinding" and spec.has("children")
	var row := _component("keybinding_group" if expandable else spec.type) as HBoxContainer
	var name_control: Control = row.get_node("Function")
	name_control.text = "功能名称" if spec.type == "bindings_header" else str(spec.get("label", spec.id))
	name_control.tooltip_text = str(spec.get("label", "功能名称"))
	name_control.custom_minimum_size.x = _binding_label_width(parent, name_control.custom_minimum_size.x)
	if expandable:
		name_control.set_pressed_no_signal(spec.get("expanded", false))
		name_control.toggled.connect(_expanded.bind(_generation))
		entry.expander = name_control
	entry.bindings = []
	if spec.type == "keybinding":
		for slot in range(2):
			var button: Button = row.get_node("Primary" if slot == 0 else "Secondary")
			var generation := _generation
			button.pressed.connect(func():
				if generation == _generation: begin_binding_capture(spec.id, slot)
			)
			entry.bindings.append(button)
	entry.control = entry.bindings[0] if spec.type == "keybinding" else name_control
	return row

func get_binding_control(id: String, slot: int) -> Button:
	if slot not in [0, 1] or not _entries.has(id) or _entries[id].spec.type != "keybinding": return null
	return _entries[id].bindings[slot]

func get_expander(id: String) -> Button:
	return _entries.get(id, {}).get("expander", null)

func set_expanded(id: String, expanded: bool) -> bool:
	var button := get_expander(id)
	if button == null: return _fail("Option has no expandable children")
	button.set_pressed_no_signal(expanded)
	_refresh_visibility()
	if is_capturing_binding() and not _entries[_capture_id].root.is_visible_in_tree(): cancel_binding_capture()
	return true

func is_capturing_binding() -> bool:
	return not _capture_id.is_empty()

func begin_binding_capture(id: String, slot: int) -> bool:
	var button := get_binding_control(id, slot)
	if button == null or not button.is_visible_in_tree(): return _fail("Binding slot is unavailable")
	cancel_binding_capture(false)
	_capture_id = id
	_capture_slot = slot
	_capture_return_focus = button
	var overlay := _component("binding_capture")
	add_child(overlay)
	_capture_overlay = overlay
	overlay.get_node("Panel/Content/Title").text = str(_entries[id].spec.get("label", id)) + (" · 主按键" if slot == 0 else " · 次要按键")
	_capture_message = overlay.get_node("Panel/Content/Message")
	overlay.get_node("Panel/Content/Actions/Cancel").pressed.connect(cancel_binding_capture)
	overlay.get_node("Panel/Content/Actions/Clear").pressed.connect(func(): _commit_binding(0))
	button.release_focus()
	set_process(true)
	return true

func cancel_binding_capture(restore_focus: bool = true) -> void:
	_capture_id = ""
	if is_instance_valid(_capture_overlay):
		remove_child(_capture_overlay)
		_capture_overlay.queue_free()
	_capture_overlay = null
	_capture_message = null
	if restore_focus and is_instance_valid(_capture_return_focus) and _capture_return_focus.is_visible_in_tree():
		_capture_return_focus.grab_focus()
	_capture_return_focus = null
	set_process(false)

func _commit_binding(code: int) -> bool:
	if not is_capturing_binding(): return false
	var id := _capture_id
	var slot := _capture_slot
	var pair: Array = get_value(id)
	pair[slot] = code
	var conflict := _binding_conflict_for(id, pair)
	if not KeyBinding.valid_pair(pair) or not conflict.is_empty():
		var other: String = id if conflict.is_empty() else conflict
		last_error = "已用于「" + str(_entries[other].spec.get("label", other)) + "」，请先清除原绑定或换一个按键"
		_capture_message.text = last_error + "\nEsc 取消 · Delete / Backspace 清除"
		binding_conflict.emit(id, slot, other)
		return false
	# Dismiss before invoking arbitrary application callbacks (which may rebuild).
	cancel_binding_capture()
	return set_value(id, pair, true)

func _route_binding_input(event: InputEvent) -> bool:
	if event is InputEventKey and _swallow_key != 0 and event.keycode == _swallow_key:
		get_viewport().set_input_as_handled()
		if not event.pressed: _swallow_key = 0
		return true
	if not is_capturing_binding(): return false
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if not event.pressed or event.echo: return true
		if event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_NONE]: return true
		_swallow_key = event.keycode
		if event.keycode == KEY_ESCAPE: cancel_binding_capture()
		elif event.keycode in [KEY_DELETE, KEY_BACKSPACE]: _commit_binding(0)
		else: _commit_binding(event.get_keycode_with_modifiers())
		return true
	# Pointer events continue to the overlay's explicit clear / cancel buttons.
	return false

func _process(_delta: float) -> void:
	if is_capturing_binding() and (not _entries.has(_capture_id) or not _entries[_capture_id].root.is_visible_in_tree()):
		cancel_binding_capture()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_binding_capture(false)
		_swallow_key = 0
