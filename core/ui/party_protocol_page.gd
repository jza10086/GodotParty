## Protocol selection and local drafts share the standard category/list/help layout.
extends Control
signal back_requested()
signal profile_requested(protocol: String)
signal protocol_selected(protocol: String)
const Form = preload("res://core/ui/party_config_form.gd")
const Schema = preload("res://core/config/party_schema.gd")
@onready var page: Control = %Workspace
var status: Label
var selected: String = ""
var catalog: RefCounted
var store: RefCounted
var _drafts: Dictionary = {}
var _picker: OptionButton
var _apply: Button
var _form: Form

func configure(config_store: RefCounted, content_catalog: RefCounted, initial: String = "", room_bound: bool = false) -> void:
	store = config_store
	catalog = content_catalog
	page.set_title("协议设置")
	page.back_requested.connect(func() -> void: back_requested.emit())
	_picker = %ProtocolPicker
	for id: String in catalog.ids("protocols"):
		if not room_bound or id == initial:
			_picker.add_item(catalog.get_package(id).get("name", id))
			_picker.set_item_metadata(_picker.item_count - 1, id)
	_picker.disabled = room_bound
	_picker.item_selected.connect(func(index: int) -> void: select_protocol(_picker.get_item_metadata(index)))
	_apply = %Apply
	_apply.pressed.connect(apply)
	%EditProfile.pressed.connect(func() -> void: profile_requested.emit(selected))
	%System.visible = room_bound
	%Game.visible = room_bound
	status = page.status
	if _picker.item_count == 0:
		status.text = "尚未安装协议。"
		_apply.disabled = true
	else:
		select_protocol(initial if not initial.is_empty() else _picker.get_item_metadata(0))

func select_protocol(id: String) -> void:
	_flush_form()
	selected = id
	for index: int in _picker.item_count:
		if _picker.get_item_metadata(index) == id:
			_picker.select(index)
	if not _drafts.has(id):
		var record: Dictionary = store.read(id)
		_drafts[id] = {"record": record, "own": record.get("own", {}).duplicate(true), "error": store.last_error if record.is_empty() else ""}
	_build()
	protocol_selected.emit(id)

func _build() -> void:
	page.clear_pages()
	_form = null
	var draft: Dictionary = _drafts[selected]
	if not draft.record.is_empty():
		_form = preload("res://core/ui/party_config_form.tscn").instantiate()
		_form.configure(draft.own, true, {"schema": catalog.schema(selected), "audience": "local"})
		_form.field_changed.connect(_changed)
		_form.category_reset.connect(func(keys: Array[String]) -> void:
			for key: String in keys:
				draft.own.erase(key)
			_update_labels())
		page.add_form(_form)
	page.add_page("个人资料与形象", %Profile, "人物形象和昵称由当前协议提供，在独立窗口中编辑和保存。")
	_apply.disabled = draft.record.is_empty()
	status.text = draft.error if draft.record.is_empty() else "修改仅进入当前协议的草稿，应用后保存。"
	_update_labels()

func _update_labels() -> void:
	for index: int in _picker.item_count:
		var id: String = _picker.get_item_metadata(index)
		var dirty: bool = _drafts.has(id) and _drafts[id].own != _drafts[id].record.get("own", {})
		_picker.set_item_text(index, catalog.get_package(id).name + (" *" if dirty else ""))

func _changed(key: String, value: Variant) -> void:
	var field: Dictionary = catalog.schema(selected).fields[key]
	if field.get("readonly", false):
		return
	var checked: Dictionary = Schema.normalize(field, value)
	_drafts[selected].own[key] = checked.value if checked.ok else value
	status.text = "草稿已修改，尚未应用。" if checked.ok else key + "：" + checked.message
	_update_labels()

func _flush_form() -> void:
	if _form != null:
		_form.flush()

func restore_defaults() -> void:
	if selected.is_empty() or _drafts[selected].record.is_empty():
		return
	_drafts[selected].own = {}
	_build()
	status.text = "已恢复协议默认值，点击应用后保存。"

## Apply exactly one owner using its captured revision; failure keeps every draft.
func apply() -> Error:
	if selected.is_empty() or _drafts[selected].record.is_empty():
		return ERR_INVALID_DATA
	_flush_form()
	var draft: Dictionary = _drafts[selected]
	var edits: Array = []
	for field: Dictionary in Schema.fields(catalog.schema(selected), "local"):
		var key: String = field.key
		if field.get("readonly", false):
			continue
		if draft.own.has(key):
			edits.append({"target": "own", "op": "set", "key": key, "value": draft.own[key]})
		else:
			edits.append({"target": "own", "op": "unset", "key": key})
	var error: Error = store.commit(selected, selected, int(draft.record.revision), edits)
	if error != OK:
		status.text = "未应用，草稿保留：" + store.last_error
		return error
	draft.record = store.read(selected)
	_update_labels()
	status.text = "当前协议已保存；实际效果按各项生效时机应用。"
	return OK
