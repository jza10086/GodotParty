## Shared settings layout: scrolling categories, compact list, contextual help and footer.
extends VBoxContainer
signal back_requested()
signal reset_requested()
var actions: HBoxContainer:
	get: return %Actions
var tools_row: HBoxContainer:
	get: return %Tools
var status: Label:
	get: return %Status
var _forms: Array[Control] = []
var _prefixes: Dictionary = {}
var _extras: Array[Dictionary] = []
var _tabs: Array[Dictionary] = []
var _selected: int = 0

func _ready() -> void:
	add_to_group(&"settings_workspace")
	%Previous.pressed.connect(func() -> void: select_tab(maxi(0, _selected - 1)))
	%Next.pressed.connect(func() -> void: select_tab(mini(_tabs.size() - 1, _selected + 1)))
	%Back.pressed.connect(func() -> void: back_requested.emit())
	%Reset.pressed.connect(func() -> void:
		for form: Control in _forms:
			form.reset_defaults()
		if not _tabs.is_empty() and _tabs[_selected].form == null and _tabs[_selected].reset.is_valid():
			_tabs[_selected].reset.call()
		status.text = "本页设置已恢复默认草稿，应用后保存。"
		reset_requested.emit())
	%TabScroll.get_h_scroll_bar().value_changed.connect(func(_value: float) -> void: _update_scroll_indicator())
	%TabScroll.get_h_scroll_bar().changed.connect(_update_scroll_indicator)
	%TabTrack.resized.connect(_update_scroll_indicator)

func set_title(value: String) -> void:
	%Heading.text = value

func set_embedded() -> void:
	%Heading.hide()
	%Back.hide()

func focus_back() -> void:
	%Back.grab_focus()

## Page-wide options stay inside the list above the selected category.
func add_option(option: Control) -> void:
	%Forms.add_child(option)
	%Forms.move_child(option, 0)

func add_form(form: Control, prefix: String = "") -> void:
	_forms.append(form)
	_prefixes[form] = prefix
	%Forms.add_child(form)
	form.help_requested.connect(show_help)
	form.rebuilt.connect(_rebuild_tabs)
	_rebuild_tabs()

func add_page(title: String, content: Control, description: String = "", reset: Callable = Callable()) -> void:
	_extras.append({"form": null, "id": title, "title": title, "content": content, "description": description, "reset": reset})
	_rebuild_tabs()

func clear_pages() -> void:
	for tab: Dictionary in _extras:
		tab.content.hide()
	for child: Control in _forms:
		%Forms.remove_child(child)
		child.queue_free()
	_forms.clear()
	_prefixes.clear()
	_extras.clear()
	_tabs.clear()
	_selected = 0
	_rebuild_tabs()

func _rebuild_tabs() -> void:
	var selected_form: Control = _tabs[_selected].form if not _tabs.is_empty() else null
	var selected_id: String = _tabs[_selected].id if not _tabs.is_empty() else ""
	for child: Node in %Tabs.get_children():
		%Tabs.remove_child(child)
		child.queue_free()
	_tabs.clear()
	for form: Control in _forms:
		for category: Dictionary in form.categories():
			_tabs.append({"form": form, "id": category.id, "title": str(_prefixes[form]) + category.title})
	_tabs.append_array(_extras)
	var group: ButtonGroup = ButtonGroup.new()
	_selected = 0
	for index: int in _tabs.size():
		var tab: Dictionary = _tabs[index]
		var button: Button = preload("res://core/ui/settings/category_tab.tscn").instantiate()
		button.text = tab.title
		button.tooltip_text = tab.title
		button.button_group = group

		button.pressed.connect(select_tab.bind(index))
		%Tabs.add_child(button)
		tab.button = button
		if tab.form == selected_form and tab.id == selected_id:
			_selected = index
	%Reset.disabled = _tabs.is_empty()
	%Previous.disabled = _tabs.is_empty()
	%Next.disabled = _tabs.is_empty()
	if not _tabs.is_empty():
		select_tab(_selected)

func inside_category_content(focus: Control) -> bool:
	return focus != null and %Forms.is_ancestor_of(focus) and not _tabs.is_empty()

func focus_selected_category() -> void:
	_tabs[_selected].button.grab_focus()
	_reveal_selected()

func pad_category(direction: int, focus_tab: bool) -> void:
	if _tabs.is_empty():
		return
	select_tab(0 if direction == 0 else wrapi(_selected + direction, 0, _tabs.size()))
	if focus_tab:
		focus_selected_category()

func in_tab_strip(control: Control) -> bool:
	return control != null and %Navigation.is_ancestor_of(control)

## Scrollable rows may be physically above the tools or below the footer. Order each region
## independently so one vertical step visits exactly the next available setting row.
func pad_rows(targets: Array[Control]) -> Array[Array]:
	var rows: Array[Array] = []
	for region: Control in [%Tools, %Forms, %Actions]:
		var controls: Array[Control] = []
		for target: Control in targets:
			if region.is_ancestor_of(target):
				controls.append(target)
		controls.sort_custom(func(a: Control, b: Control) -> bool:
			return a.get_global_rect().get_center().y < b.get_global_rect().get_center().y)
		var row: Array[Control] = []
		var baseline: float = 0.0
		for control: Control in controls:
			var rect: Rect2 = control.get_global_rect()
			if row.is_empty() or rect.position.y >= baseline:
				row = []
				rows.append(row)
				baseline = rect.get_center().y
			row.append(control)
	for row: Array in rows:
		row.sort_custom(func(a: Control, b: Control) -> bool:
			if a.is_ancestor_of(b):
				return true
			if b.is_ancestor_of(a):
				return false
			return a.get_global_rect().get_center().x < b.get_global_rect().get_center().x)
	return rows

func first_pad_target(targets: Array[Control]) -> Control:
	for target: Control in targets:
		if %Forms.is_ancestor_of(target):
			return target
	var rows: Array[Array] = pad_rows(targets)
	return null if rows.is_empty() else rows[0][0]

func pad_neighbor(focus: Control, side: Side, targets: Array[Control]) -> Control:
	var rows: Array[Array] = pad_rows(targets)
	for index: int in rows.size():
		var row: Array = rows[index]
		var column: int = row.find(focus)
		if column < 0:
			continue
		var step: int = -1 if side in [SIDE_TOP, SIDE_LEFT] else 1
		if side in [SIDE_LEFT, SIDE_RIGHT]:
			return row[clampi(column + step, 0, row.size() - 1)]
		var next: int = index + step
		if next < 0 or next >= rows.size():
			return focus
		var x: float = focus.get_global_rect().get_center().x
		var nearest: Control
		var distance: float = INF
		for candidate: Control in rows[next]:
			var offset: float = absf(candidate.get_global_rect().get_center().x - x)
			if offset < distance:
				distance = offset
				nearest = candidate
		return nearest
	return first_pad_target(targets)

func focus_pad_target(target: Control) -> void:
	if target != null:
		target.grab_focus()
		if %Forms.is_ancestor_of(target):
			%List.ensure_control_visible(target)

func select_tab(index: int) -> void:
	if index != _selected:
		get_tree().call_group(&"ambient_menu_audio", &"page")
	_selected = index
	for form: Control in _forms:
		form.hide()
	for tab: Dictionary in _extras:
		tab.content.hide()
	for tab: Dictionary in _tabs:
		tab.button.set_pressed_no_signal(false)
	var selected: Dictionary = _tabs[index]
	selected.button.set_pressed_no_signal(true)
	%Previous.disabled = index == 0
	%Next.disabled = index == _tabs.size() - 1
	%Reset.disabled = _forms.is_empty() and not _tabs[index].reset.is_valid()
	%List.scroll_vertical = 0
	if selected.form != null:
		selected.form.show()
		selected.form.select_category(selected.id)
	else:
		selected.content.show()
		show_help(selected.title, selected.description, "")
	_reveal_selected.call_deferred()

func _reveal_selected() -> void:
	if is_inside_tree() and not _tabs.is_empty():
		%TabScroll.ensure_control_visible(_tabs[_selected].button)

func show_help(title: String, description: String, detail: String) -> void:
	%HelpTitle.text = title
	%HelpDescription.text = description
	%HelpDetail.text = detail

## Wheel input belongs to the tab strip even when the pointer is over a tab button.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventMouseButton:
		return
	if not event.pressed or not %Navigation.get_global_rect().has_point(event.position):
		return
	var direction: int = 0
	match event.button_index:
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT: direction = 1
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT: direction = -1
	if direction != 0:
		%TabScroll.scroll_horizontal += roundi(direction * 120.0 * event.factor)
		get_viewport().set_input_as_handled()

func _update_scroll_indicator() -> void:
	var bar: HScrollBar = %TabScroll.get_h_scroll_bar()
	var width: float = maxf(0.0, %TabTrack.size.x - 4.0)
	var total: float = maxf(bar.max_value, bar.page)
	var fraction: float = bar.page / total if total > 0.0 else 1.0
	var thumb_width: float = minf(width, maxf(32.0, width * fraction))
	var travel: float = maxf(0.0, bar.max_value - bar.page)
	%TabRemaining.visible = travel > 0.0
	%TabThumb.size = Vector2(thumb_width, %TabTrack.size.y - 4.0)
	%TabThumb.position = Vector2(2.0 + ((width - thumb_width) * bar.value / travel if travel > 0.0 else 0.0), 2.0)
