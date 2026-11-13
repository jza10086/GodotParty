## Lobby-only draft. Row highlights select inspection/batch targets; checkboxes edit pool membership.
## Temporary presets live with this dialog. Only explicit preset saves write to disk.
extends VBoxContainer

const GAME_ROW: PackedScene = preload("res://core/ui/minigame_browser/game_card.tscn")

var app: Node
var draft: Dictionary = {}
var editable: bool = false
var main_id: String = ""
var pool_name: String = ""
var ids: Array[String] = []
var shown: Array[String] = []
var focused: String = ""
var highlighted: Array[String] = []
var anchor: String = ""
var temporary: Dictionary = {}
var preset_labels: Dictionary = {}
var rows: Dictionary[String, Control] = {}
var _row_pool: Array[Control] = []
var _top_space: Control
var _bottom_space: Control
var _row_height: float = 54.0
@onready var row_list: VBoxContainer = %Rows
@onready var list_scroll: ScrollContainer = %ListScroll
@onready var search: LineEdit = %Search
@onready var pool_picker: OptionButton = %PoolPicker
@onready var count_label: Label = %CountLabel
@onready var preview: TextureRect = %Preview
@onready var preview_note: Label = %PreviewNote
@onready var game_title: Label = %GameTitle
@onready var game_info: Label = %GameInfo
@onready var preset_picker: OptionButton = %PresetPicker
@onready var advanced: Button = %Advanced
@onready var local_preferences: Button = %LocalPreferences
@onready var folder: Button = %Folder
@onready var error_label: Label = %ErrorLabel

func configure(owner_app: Node, room: Dictionary, can_edit: bool) -> void:
	app = owner_app
	draft = room.duplicate(true)
	main_id = draft.main
	editable = can_edit
	ids = app.catalog.compatible_minis(main_id)
	for id: String in draft.children:
		var value: Dictionary = draft.children[id]
		preset_labels[id] = "默认预设"
		if value != app.catalog.defaults(id):
			temporary[id] = value.duplicate(true)
			preset_labels[id] = "临时预设"
			for saved_name: String in app.presets.names(id, app.catalog.get_package(draft.main).protocol.id):
				var saved: Dictionary = app.presets.read(id, app.catalog.get_package(draft.main).protocol.id, saved_name)
				if not saved.is_empty() and app.catalog.validate_settings(id, saved.room_own).get("value") == value and saved.room_common == draft.common_overrides.get(id, {}):
					preset_labels[id] = saved_name
					temporary.erase(id)
					break

func _ready() -> void:
	for value: String in app.catalog.get_package(main_id).get("pools", []):
		pool_picker.add_item("小游戏池" if value == "minigames" else value)
		pool_picker.set_item_metadata(pool_picker.item_count - 1, value)
	if pool_picker.item_count > 0:
		pool_name = pool_picker.get_item_metadata(0)
	pool_picker.item_selected.connect(func(index: int) -> void:
		pool_name = pool_picker.get_item_metadata(index)
		anchor = ""
		_refresh_rows())
	search.text_changed.connect(_filter_rows)
	for button: Button in [%SelectAll, %Invert, %Clear]:
		button.disabled = not editable or pool_name.is_empty()
	%SelectAll.pressed.connect(select_all.bind(false))
	%Invert.pressed.connect(select_all.bind(true))
	%Clear.pressed.connect(func() -> void:
		draft.pools[pool_name] = []
		_refresh_rows())
	%Load.pressed.connect(func() -> void: _select_preset(preset_picker.selected))
	%Refresh.pressed.connect(_refresh_inspector)
	advanced.pressed.connect(open_advanced)
	local_preferences.pressed.connect(open_preferences)
	folder.pressed.connect(_open_folder)
	if not editable:
		error_label.text = "当前为只读；房间设置由房主修改。"
	_top_space = Control.new()
	_bottom_space = Control.new()
	row_list.add_child(_top_space)
	row_list.add_child(_bottom_space)
	list_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _render_rows())
	list_scroll.resized.connect(_render_rows)
	_filter_rows(search.text)

## Reuse only the visible row window. Offscreen games never load previews.
func _render_rows() -> void:
	if _top_space == null:
		return
	var separation: int = row_list.get_theme_constant("separation")
	var stride: float = _row_height + separation
	var first: int = maxi(0, int(list_scroll.scroll_vertical / stride) - 1)
	var count: int = mini(shown.size() - first, ceili(list_scroll.size.y / stride) + 3)
	count = maxi(0, count)
	while _row_pool.size() < count:
		var row: HBoxContainer = GAME_ROW.instantiate()
		row_list.add_child(row)
		row_list.move_child(row, row_list.get_child_count() - 2)
		var inspect: Button = row.get_node("%Inspect")
		var check: CheckBox = row.get_node("%Check")
		inspect.pressed.connect(func() -> void: _inspect_pressed(row.get_meta("game_id")))
		check.pressed.connect(func() -> void: _check_pressed(row.get_meta("game_id"), check))
		_row_pool.append(row)
	rows.clear()
	for index: int in _row_pool.size():
		var row: Control = _row_pool[index]
		row.visible = index < count
		if not row.visible:
			row.get_node("%Inspect").icon = null
			continue
		var id: String = shown[first + index]
		row.set_meta("game_id", id)
		var inspect: Button = row.get_node("%Inspect")
		inspect.text = _title(id)
		inspect.icon = _cover(id)
		inspect.tooltip_text = inspect.text
		var check: CheckBox = row.get_node("%Check")
		check.disabled = not editable or pool_name.is_empty()
		check.tooltip_text = "加入或移出小游戏池 · " + inspect.text
		rows[id] = row
	_top_space.custom_minimum_size.y = maxf(0.0, first * stride - separation)
	_top_space.visible = first > 0
	var remaining: int = maxi(0, shown.size() - first - count)
	_bottom_space.custom_minimum_size.y = maxf(0.0, remaining * stride - separation)
	_bottom_space.visible = remaining > 0
	_refresh_rows()

func _cover(id: String) -> Texture2D:
	return app.catalog.cover(id)

func _title(id: String) -> String:
	return str(app.catalog.get_package(id).get("name", id)).trim_prefix("GodotPartyDefault · ")

func _inspect_pressed(id: String) -> void:
	choose(id, Input.is_key_pressed(KEY_CTRL), Input.is_key_pressed(KEY_SHIFT))

func _check_pressed(id: String, check: CheckBox) -> void:
	set_checked(id, check.button_pressed)

func _filter_rows(text: String) -> void:
	shown.clear()
	var query: String = text.strip_edges().to_lower()
	for id: String in ids:
		if query.is_empty() or query in (_title(id) + " " + id).to_lower():
			shown.append(id)
	if focused not in shown:
		focused = "" if shown.is_empty() else shown[0]
		highlighted.clear()
		anchor = focused
		if not focused.is_empty():
			highlighted.append(focused)
	%NoMatches.visible = shown.is_empty()
	list_scroll.scroll_vertical = 0
	_render_rows()
	_refresh_inspector()

## Highlighting never changes membership. Shift follows visible order; Ctrl+Shift adds a range.
func choose(id: String, control: bool, shift: bool) -> void:
	if id not in shown:
		return
	focused = id
	if shift and anchor in shown:
		if not control:
			highlighted.clear()
		var first: int = shown.find(anchor)
		var last: int = shown.find(id)
		for index: int in range(mini(first, last), maxi(first, last) + 1):
			if shown[index] not in highlighted:
				highlighted.append(shown[index])
	elif control:
		if id in highlighted:
			highlighted.erase(id)
		else:
			highlighted.append(id)
		anchor = id
	else:
		highlighted.assign([id])
		anchor = id
	_refresh_rows()
	_refresh_inspector()

## A highlighted check applies its state to visible highlighted rows; otherwise only to itself.
func set_checked(id: String, checked: bool) -> void:
	if not editable or pool_name.is_empty() or id not in shown:
		return
	var targets: Array[String] = []
	if id in highlighted:
		for target: String in shown:
			if target in highlighted:
				targets.append(target)
	else:
		targets.append(id)
	var selected: Array = draft.pools.get(pool_name, []).duplicate()
	for target: String in targets:
		if checked and target not in selected:
			selected.append(target)
		elif not checked:
			selected.erase(target)
	_store_selection(selected)
	focused = id
	_refresh_rows()
	_refresh_inspector()

func highlight_all(invert: bool) -> void:
	for id: String in shown:
		if invert and id in highlighted:
			highlighted.erase(id)
		elif id not in highlighted:
			highlighted.append(id)
	_refresh_rows()

func _store_selection(selected: Array) -> void:
	var ordered: Array = []
	for id: String in ids:
		if id in selected:
			ordered.append(id)
	draft.pools[pool_name] = ordered

func select_all(invert: bool) -> void:
	if not editable or pool_name.is_empty():
		return
	var selected: Array = draft.pools.get(pool_name, []).duplicate()
	for id: String in shown:
		if invert and id in selected:
			selected.erase(id)
		elif id not in selected:
			selected.append(id)
	_store_selection(selected)
	_refresh_rows()

func _refresh_rows() -> void:
	var selected: Array = draft.pools.get(pool_name, [])
	for id: String in rows:
		var row: Control = rows[id]
		var check: CheckBox = row.get_node("%Check")
		check.button_pressed = id in selected
		var inspect: Button = row.get_node("%Inspect")
		inspect.set_pressed_no_signal(id in highlighted)
	count_label.text = "已勾选 %d / %d · 允许开始：%s%s" % [selected.size(), ids.size(), app.connection.PlayerCounts.describe(app.connection.PlayerCounts.room_counts(draft, app.catalog)), " · 没有匹配结果" if shown.is_empty() else ""]

func _refresh_inspector() -> void:
	var valid: bool = not focused.is_empty()
	%Load.disabled = not editable or not valid
	%Refresh.disabled = not valid
	preset_picker.disabled = not editable or not valid
	advanced.disabled = not valid
	local_preferences.disabled = not valid
	folder.disabled = not valid or OS.has_feature("web") or OS.has_feature("standalone")
	if not valid:
		game_title.text = "选择一个小游戏"
		preview.texture = null
		preview_note.hide()
		%PlayerCounts.text = ""
		game_info.text = ""
		preset_picker.clear()
		return
	var manifest: Dictionary = app.catalog.get_package(focused)
	game_title.text = _title(focused)
	var counts: Array[int] = app.connection.PlayerCounts.game_counts(draft, focused, app.catalog)
	%PlayerCounts.text = "支持人数  ·  " + app.connection.PlayerCounts.describe(counts)
	game_info.text = manifest.get("introduction", "")
	preview.texture = _cover(focused)
	preview_note.text = "尚无专属预览图"
	preview_note.visible = not manifest.has("cover")
	preset_picker.clear()
	preset_picker.add_item("默认预设")
	for preset: String in app.presets.names(focused, app.catalog.get_package(draft.main).protocol.id):
		preset_picker.add_item(preset)
	if temporary.has(focused):
		preset_picker.add_item("临时预设")
	for index: int in preset_picker.item_count:
		if preset_picker.get_item_text(index) == preset_labels.get(focused, "默认预设"):
			preset_picker.select(index)

func _select_preset(index: int) -> void:
	if not editable or focused.is_empty():
		return
	var caption: String = preset_picker.get_item_text(index)
	var value: Dictionary
	if caption == "默认预设":
		value = app.catalog.defaults(focused)
		draft.common_overrides.erase(focused)
	elif caption == "临时预设":
		value = temporary[focused].duplicate(true)
	else:
		var report: Dictionary = app.presets.read(focused, app.catalog.get_package(draft.main).protocol.id, caption)
		if report.is_empty():
			error_label.text = app.presets.last_error
			_refresh_inspector()
			return
		value = app.catalog.validate_settings(focused, report.room_own).value
		draft.common_overrides[focused] = report.room_common.duplicate(true)
	draft.children[focused] = value.duplicate(true)
	preset_labels[focused] = caption
	error_label.text = ""
	_refresh_rows()
	_refresh_inspector()

## Local preferences are editable by each client, independently of host-only pool/rule drafts.
func open_preferences() -> void:
	if focused.is_empty():
		return
	var protocol: String = app.catalog.get_package(main_id).protocol.id
	app._preferences_dialog(focused, protocol)

func open_advanced() -> void:
	if focused.is_empty():
		return
	var id: String = focused
	var panel: Control = app._panel(id, draft.children[id] if draft.children.has(id) else app.catalog.defaults(id), editable)
	var context: Dictionary = {"schema": app.catalog.localized_schema(id), "audience": "room", "pools": draft.pools.duplicate(true), "fields": app.catalog.fields(id), "resources": app.catalog.packages.duplicate(true), "preview_asset": func(ref: Dictionary) -> Resource: return app.catalog.asset(ref, app.catalog.packages)}
	var editor: Control = app._configuration_editor("高级设置 · " + _title(id), panel, editable, "配置此小游戏的房间规则；应用后返回小游戏池草稿。", func() -> void: panel.configure(app.catalog.defaults(id), editable, context))
	editor.apply_button.text = "应用到草稿"
	var protocol: String = app.catalog.get_package(draft.main).protocol.id
	var state: Dictionary = {"common": draft.common_overrides.get(id, {}).duplicate(true)}
	var bar: Control = editor.presets
	bar.show()
	bar.configure(app.runner.config_store, id, protocol, func() -> Dictionary: return app.presets.snapshot(id, protocol, panel.get_value(), state.common), editable)
	bar.loaded.connect(func(value: Dictionary) -> void:
		panel.configure(app.catalog.validate_settings(id, value.room_own).value, editable, {"schema": app.catalog.localized_schema(id), "audience": "room", "fields": app.catalog.fields(id), "resources": app.catalog.packages.duplicate(true), "preview_asset": func(ref: Dictionary) -> Resource: return app.catalog.asset(ref, app.catalog.packages)})
		state.common = value.room_common.duplicate(true))
	var hint: Label = editor.page.status
	editor.apply_button.disabled = not editable
	editor.apply_requested.connect(func() -> void:
		if apply_advanced(id, panel.get_value()):
			draft.common_overrides[id] = state.common.duplicate(true)
			app._close_preferences()
			_refresh_rows()
			_refresh_inspector()
		else:
			hint.text = error_label.text)

## Validation and persistence succeed before replacing the draft. Cancel never reaches this method.
func apply_advanced(id: String, value: Dictionary) -> bool:
	if not editable:
		return false
	var report: Dictionary = app.catalog.validate_settings(id, value, true)
	if not report.get("ok", false):
		error_label.text = report.get("message", "配置无效")
		return false
	temporary[id] = report.value.duplicate(true)
	preset_labels[id] = "临时预设"
	draft.children[id] = report.value.duplicate(true)
	error_label.text = ""
	return true

func _open_folder() -> void:
	if focused.is_empty():
		return
	var path: String = ProjectSettings.globalize_path(app.catalog.get_package(focused).get("_root", ""))
	if not DirAccess.dir_exists_absolute(path):
		error_label.text = "此内容来自打包文件，没有可打开的源码目录。"
		return
	var error: Error = OS.shell_open(path)
	if error != OK:
		error_label.text = "无法打开目录：" + error_string(error)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	var owner: Control = get_viewport().gui_get_focus_owner()
	if owner is LineEdit or owner == preset_picker or owner == pool_picker:
		return
	if event.ctrl_pressed and event.keycode in [KEY_A, KEY_I]:
		highlight_all(event.keycode == KEY_I)
		get_viewport().set_input_as_handled()
