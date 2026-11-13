## Installed package browser. Configuration stays in the shared local preferences editor.
extends Control
signal back_requested()
signal preferences_requested(package_id: String, protocol_id: String)
const Row: PackedScene = preload("res://core/ui/content_browser/package_row.tscn")
const Paths = preload("res://core/config/party_paths.gd")
@onready var page: Control = %Workspace
var catalog: RefCounted
var store: RefCounted
var selected: String = ""
var _rows: Dictionary = {}
var _groups: Array[VBoxContainer] = []

func configure(content_catalog: RefCounted, config_store: RefCounted) -> void:
	catalog = content_catalog
	store = config_store
	page.set_title(_t("内容包"))
	page.get_node("%Reset").hide()
	page.back_requested.connect(func() -> void: back_requested.emit())
	%Search.placeholder_text = _t("搜索名称或 ID")
	%Search.text_changed.connect(_filter)
	%ProtocolLabel.text = _t("继承协议")
	%Configure.text = _t("配置本机设置")
	%Configure.pressed.connect(func() -> void:
		preferences_requested.emit(selected, str(%Protocol.get_selected_metadata())))
	%Protocol.item_selected.connect(func(_index: int) -> void: _details())
	_groups = [%Protocols, %MainGames, %MiniGames, %Assets]
	var kinds: Array[String] = ["protocols", "maingame", "minigame", "assets"]
	var titles: Array[String] = ["协议", "主游戏", "小游戏", "资产包"]
	for index: int in kinds.size():
		var group: VBoxContainer = _groups[index]
		for id: String in catalog.ids(kinds[index]):
			var row: Button = Row.instantiate()
			var definition: Dictionary = catalog.get_package(id)
			row.text = str(definition.name) + "  ·  " + str(definition.package_version)
			row.tooltip_text = id
			row.pressed.connect(_select.bind(id))
			row.focus_entered.connect(_select.bind(id))
			group.add_child(row)
			_rows[id] = row
		group.visibility_changed.connect(func() -> void:
			if group.is_visible_in_tree(): _select_visible.call_deferred(group))
		page.add_page(_t(titles[index]), group, _t("选择内容包，查看说明并配置本机设置。"))
	_filter("")

func _t(value: String) -> String:
	return catalog.i18n.text("core", StringName(value))

func _filter(query: String) -> void:
	var term: String = query.strip_edges().to_lower()
	for id: String in _rows:
		var row: Button = _rows[id]
		row.visible = term.is_empty() or term in (row.text + " " + id).to_lower()
	for group: VBoxContainer in _groups:
		group.get_node("Empty").visible = not _has_rows(group)
		group.get_node("Empty").text = _t("没有匹配的内容包。")
		if group.is_visible_in_tree(): _select_visible(group)

func _has_rows(group: VBoxContainer) -> bool:
	for child: Node in group.get_children():
		if child is Button and child.visible: return true
	return false

func _select_visible(group: VBoxContainer) -> void:
	if not group.is_visible_in_tree(): return
	if not selected.is_empty() and _rows[selected].get_parent() == group and _rows[selected].visible:
		_details()
		return
	for id: String in _rows:
		if _rows[id].get_parent() == group and _rows[id].visible:
			_select(id)
			return
	selected = ""
	%Configure.disabled = true
	%Protocol.clear()
	%Protocol.disabled = true
	page.status.text = _t("没有匹配的内容包。")
	page.show_help(_t("内容包"), "", "")

func _select(id: String) -> void:
	selected = id
	var definition: Dictionary = catalog.get_package(id)
	var protocols: Array[String] = []
	if definition.kind == "protocols":
		protocols.append(id)
	elif definition.kind == "maingame":
		if catalog.protocol_matches(definition.protocol): protocols.append(definition.protocol.id)
	elif definition.kind == "minigame":
		for adapter: Dictionary in definition.adapters:
			if catalog.protocol_matches(adapter.protocol) and adapter.protocol.id not in protocols:
				protocols.append(adapter.protocol.id)
	%Protocol.clear()
	for protocol: String in protocols:
		%Protocol.add_item(catalog.get_package(protocol).name)
		%Protocol.set_item_metadata(%Protocol.item_count - 1, protocol)
	if protocols.is_empty():
		%Protocol.add_item(_t("仅游戏自身设置（无可用协议）"))
		%Protocol.set_item_metadata(0, "")
	%Protocol.select(0)
	%Protocol.disabled = protocols.size() <= 1
	%Configure.disabled = definition.kind == "assets"
	%Configure.visible = definition.kind != "assets"
	%Protocol.visible = definition.kind != "assets"
	%ProtocolLabel.visible = definition.kind != "assets"
	for row_id: String in _rows:
		_rows[row_id].set_pressed_no_signal(row_id == id)
	_details()

func _details() -> void:
	var definition: Dictionary = catalog.get_package(selected)
	if definition.kind == "assets":
		var users: Array[String] = []
		for id: String in catalog.packages:
			if catalog.packages[id].get("dependencies", {}).has(selected):
				users.append(catalog.get_package(id).name)
		page.show_help(definition.name, definition.remark, "ID: " + selected + "\n" + definition.framework_version + "\n" + ", ".join(users))
		page.status.text = definition.package_version
		return
	var protocol: String = str(%Protocol.get_selected_metadata())
	var detail: String = "ID: " + selected + "\n" + _t("配置文件：") + "\n" + store.own_path(selected)
	if not protocol.is_empty() and protocol != selected:
		detail += "\n\n" + _t("协议覆盖文件：") + "\n" + Paths.configuration(store.root, catalog, selected, protocol).path_join("overrides.json")
	page.show_help(definition.name, str(definition.get("description", "")), detail)
	page.status.text = _t("修改后点击应用保存；房间规则仍在大厅中配置。")
