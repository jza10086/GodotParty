## Lobby-only draft. Card highlights select inspection/batch targets; corner checks edit pool membership.
## Temporary presets live with this dialog. Only explicit preset saves write to disk.
extends VBoxContainer

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
var cards: Dictionary = {}
var _page: int = 0
@onready var grid: GridContainer = %Grid
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
var advanced_dialog: GPPartyDialog

func configure(owner_app: Node, room: Dictionary, can_edit: bool) -> void:
	app = owner_app
	draft = room.duplicate(true)
	main_id = draft.main
	editable = can_edit
	ids = app.catalog.compatible_minis(main_id)
	for id: String in ids:
		var value: Dictionary = draft.children.get(id, app.catalog.defaults(id))
		draft.children[id] = value.duplicate(true)
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
		_refresh_cards())
	search.text_changed.connect(func(_query: String) -> void:
		_page = 0
		_build_cards())
	list_scroll.resized.connect(_resize_grid)
	for button: Button in [%SelectAll, %Invert, %Clear]:
		button.disabled = not editable
	%SelectAll.pressed.connect(select_all.bind(false))
	%Invert.pressed.connect(select_all.bind(true))
	%Clear.pressed.connect(func() -> void:
		draft.pools[pool_name] = []
		_refresh_cards())
	%Load.pressed.connect(func() -> void: _select_preset(preset_picker.selected))
	%Refresh.pressed.connect(_refresh_inspector)
	advanced.pressed.connect(open_advanced)
	local_preferences.pressed.connect(open_preferences)
	folder.pressed.connect(_open_folder)
	if not editable:
		error_label.text = "当前为只读；房间设置由房主修改。"
	%Prev.pressed.connect(_turn_page.bind(-1))
	%Next.pressed.connect(_turn_page.bind(1))
	for card: Button in grid.get_children():
		card.pressed.connect(func() -> void: choose(card.get_meta("game_id"), Input.is_key_pressed(KEY_CTRL), Input.is_key_pressed(KEY_SHIFT)))
		card.get_node("%Check").toggled.connect(func(on: bool) -> void: set_checked(card.get_meta("game_id"), on))
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree() and is_instance_valid(advanced_dialog):
			advanced_dialog.hide())
	_build_cards()
	if not ids.is_empty():
		focused = ids[0]
	_refresh_inspector()

func _cover(id: String) -> Texture2D:
	var cover: String = app.catalog.get_package(id).get("cover", "")
	if not cover.is_empty():
		var path: String = app.catalog.path(id, cover)
		if ResourceLoader.exists(path):
			var resource: Resource = load(path)
			if resource is Texture2D:
				return resource
	return preload("res://icon.svg")

func _title(id: String) -> String:
	return str(app.catalog.get_package(id).get("name", id)).trim_prefix("GodotPartyDefault · ")

func _build_cards() -> void:
	shown.clear()
	var query: String = search.text.strip_edges().to_lower()
	for id: String in ids:
		if not query.is_empty() and not (_title(id) + " " + id).to_lower().contains(query):
			continue
		shown.append(id)
	_display_page()

func _turn_page(direction: int) -> void:
	_page += direction
	_display_page()

func _display_page() -> void:
	cards.clear()
	var capacity: int = grid.get_child_count()
	var pages: int = maxi(1, ceili(float(shown.size()) / capacity))
	_page = clampi(_page, 0, pages - 1)
	%Pages.visible = pages > 1
	%PageNumber.text = "%d / %d" % [_page + 1, pages]
	%Prev.disabled = _page == 0
	%Next.disabled = _page + 1 >= pages
	list_scroll.scroll_vertical = 0
	for index: int in capacity:
		var card: Button = grid.get_child(index)
		var offset: int = _page * capacity + index
		card.visible = offset < shown.size()
		if not card.visible:
			continue
		var id: String = shown[offset]
		card.set_meta("game_id", id)
		card.tooltip_text = _title(id)
		card.get_node("%Cover").texture = _cover(id)
		card.get_node("%Caption").text = _title(id)
		var check: Button = card.get_node("%Check")
		check.disabled = not editable or pool_name.is_empty()
		cards[id] = {"card": card, "check": check}
	_resize_grid()
	_refresh_cards()

func _resize_grid() -> void:
	grid.columns = maxi(1, int((list_scroll.size.x - 16) / 224.0))

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
	_refresh_cards()
	_refresh_inspector()

## A highlighted check applies its state to visible highlighted cards; otherwise only to itself.
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
	_refresh_cards()
	_refresh_inspector()

func highlight_all(invert: bool) -> void:
	for id: String in shown:
		if invert and id in highlighted:
			highlighted.erase(id)
		elif id not in highlighted:
			highlighted.append(id)
	_refresh_cards()

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
	_refresh_cards()

func _refresh_cards() -> void:
	var selected: Array = draft.pools.get(pool_name, [])
	for id: String in cards:
		cards[id].check.set_pressed_no_signal(id in selected)
		cards[id].check.text = "✓" if id in selected else ""
		cards[id].check.theme_type_variation = &"PoolCheckChecked" if id in selected else &"PoolCheck"
		cards[id].card.set_pressed_no_signal(id in highlighted)
	count_label.text = "已勾选 %d / %d · 允许开始：%s%s" % [selected.size(), ids.size(), app.connection.PlayerCounts.describe(app.connection.PlayerCounts.room_counts(draft, app.catalog)), " · 没有匹配结果" if shown.is_empty() else ""]

func _refresh_inspector() -> void:
	var valid: bool = not focused.is_empty()
	preset_picker.disabled = not editable or not valid
	advanced.disabled = not valid
	local_preferences.disabled = not valid
	folder.disabled = not valid or OS.has_feature("web") or OS.has_feature("standalone")
	if not valid:
		return
	var manifest: Dictionary = app.catalog.get_package(focused)
	game_title.text = _title(focused)
	var counts: Array[int] = app.connection.PlayerCounts.game_counts(draft, focused, app.catalog)
	game_info.text = "当前配置：%s\n%s" % [app.connection.PlayerCounts.describe(counts), manifest.get("introduction", "在高级设置中调整本小游戏的房间规则。")]
	preview.texture = _cover(focused)
	preview_note.text = "预览图" if manifest.has("cover") else "该小游戏尚未提供预览图"
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
	_refresh_cards()
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
	if is_instance_valid(advanced_dialog):
		advanced_dialog.queue_free()
	var id: String = focused
	advanced_dialog = preload("res://core/ui/dialogs/minigame_rules.tscn").instantiate()
	advanced_dialog.title = "高级设置 · " + _title(id)
	advanced_dialog.ok_button_text = "应用到草稿"
	advanced_dialog.dialog_hide_on_ok = false
	app.get_node("%DialogHost").add_child(advanced_dialog)
	var panel: Control = app._panel(id, draft.children[id], editable)
	advanced_dialog.content.get_node("FormSlot").add_child(panel)
	var protocol: String = app.catalog.get_package(draft.main).protocol.id
	var state: Dictionary = {"common": draft.common_overrides.get(id, {}).duplicate(true)}
	var bar: Control = advanced_dialog.content.get_node("Presets")
	bar.configure(app.runner.config_store, id, protocol, func() -> Dictionary: return app.presets.snapshot(id, protocol, panel.get_value(), state.common), editable)
	bar.loaded.connect(func(value: Dictionary) -> void:
		panel.configure(app.catalog.validate_settings(id, value.room_own).value, editable, {"schema": app.catalog.schema(id), "audience": "room", "fields": app.catalog.fields(id), "resources": app.catalog.packages.duplicate(true), "preview_asset": func(ref: Dictionary) -> Resource: return app.catalog.asset(ref, app.catalog.packages)})
		state.common = value.room_common.duplicate(true))
	var hint: Label = advanced_dialog.content.get_node("Hint")
	advanced_dialog.get_ok_button().disabled = not editable
	advanced_dialog.confirmed.connect(func() -> void:
		if apply_advanced(id, panel.get_value()):
			draft.common_overrides[id] = state.common.duplicate(true)
			advanced_dialog.hide()
			_refresh_cards()
			_refresh_inspector()
		else:
			hint.text = error_label.text)
	advanced_dialog.popup_centered(Vector2i(1100, 850))

## Validation and persistence succeed before replacing the draft. Cancel never reaches this method.
func apply_advanced(id: String, value: Dictionary) -> bool:
	if not editable:
		return false
	var report: Dictionary = app.catalog.validate_settings(id, value)
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

func _exit_tree() -> void:
	if is_instance_valid(advanced_dialog):
		advanced_dialog.hide()
		advanced_dialog.queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if is_instance_valid(advanced_dialog) and advanced_dialog.visible:
		return
	var owner: Control = get_viewport().gui_get_focus_owner()
	if owner is LineEdit or owner == preset_picker or owner == pool_picker:
		return
	if event.ctrl_pressed and event.keycode in [KEY_A, KEY_I]:
		highlight_all(event.keycode == KEY_I)
		get_viewport().set_input_as_handled()

