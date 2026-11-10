## Local preferences share one category strip and contextual help across own/protocol settings.
extends PanelContainer
signal back_requested()
const AmbientSwitch = preload("res://core/ui/ambient_reveal/animated_switch.gd")
const Form = preload("res://core/ui/party_config_form.gd")
const Schema = preload("res://core/config/party_schema.gd")
var store: RefCounted
var package_id: String
var protocol_id: String
var revision: int
var forms: Dictionary = {}
var error_label: Label
@onready var page: Control = %Workspace
var _all_inherit: AmbientSwitch

func configure(settings_store: RefCounted, target: String, protocol: String) -> void:
	store = settings_store
	package_id = target
	protocol_id = protocol
	page.set_embedded()
	theme_type_variation = &"PreferencesEmbedded"
	error_label = page.status
	var data: Dictionary = store.read(target, protocol)
	if data.is_empty():
		error_label.text = store.last_error
		var reset: Button = %Repair
		reset.show()
		reset.pressed.connect(func() -> void:
			var error: Error = store.reset(target)
			error_label.text = "已重置，请重新打开设置页。" if error == OK else error_string(error))
		return
	revision = data.revision
	_section("own", store.catalog.schema(target), data.own, {}, "", false)
	if not protocol.is_empty() and target != protocol:
		var layers: Dictionary = store.local_layers(target, protocol)
		if layers.is_empty():
			error_label.text = store.last_error
			return
		var base: Dictionary = Schema.defaults(store.catalog.schema(protocol), "local")
		base.merge(layers.protocol, true)
		_section("common", store.catalog.schema(protocol), layers.overrides, base, "协议 · ", true)
		_all_inherit = preload("res://core/ui/settings/switch_option.tscn").instantiate()
		_all_inherit.size_flags_horizontal = Control.SIZE_SHRINK_END
		_all_inherit.set_value_silently(layers.overrides.is_empty())
		var inherit_row: Control = preload("res://core/ui/settings/setting_section.tscn").instantiate()
		inherit_row.configure("全部继承协议", true)
		inherit_row.set_field(_all_inherit, false)
		page.add_option(inherit_row)
		var explain: Callable = func() -> void:
			page.show_help("全部继承协议", "开启后，所有协议选项使用协议设置；关闭后可以为本游戏逐项覆盖。游戏自己的设置不受影响。", "修改继承关系后，点击应用并保存。")
		inherit_row.get_node("%Header").mouse_entered.connect(explain)
		_all_inherit.focus_entered.connect(explain)
		_all_inherit.toggled.connect(func(value: bool) -> void:
			forms.common.inherit_all(value)
			error_label.text = "继承关系已修改，应用后保存。")
		forms.common.field_changed.connect(func(_key: String, _value: Variant) -> void: _sync_inheritance())
		forms.common.category_reset.connect(func(_keys: Array[String]) -> void: _sync_inheritance())
	error_label.text = "修改仅进入草稿，应用后保存到本机。"

## The same preferences component can be embedded in author previews or fill the application.
func present_fullscreen() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme_type_variation = &"PreferencesFullscreen"
	page.get_node("%Heading").show()
	page.get_node("%Back").show()
	page.set_title(store.catalog.get_package(package_id).name + " · 本机设置")
	page.back_requested.connect(func() -> void: back_requested.emit())
	%Save.show()
	%Save.pressed.connect(apply)

func _sync_inheritance() -> void:
	_all_inherit.set_value_silently(forms.common.explicit_values().is_empty())

func _section(domain: String, schema: Dictionary, stored: Dictionary, base: Dictionary, prefix: String, common: bool) -> void:
	var form: Form = preload("res://core/ui/party_config_form.tscn").instantiate()
	form.configure(stored, true, {"schema": schema, "audience": "local", "inherit": common, "overrides": common, "base": base, "inherit_label": "继承协议" if common else "默认"})
	page.add_form(form, prefix)
	forms[domain] = form

func apply() -> Error:
	var edits: Array = []
	for domain: String in forms:
		var values: Dictionary = forms[domain].explicit_values()
		var schema: Dictionary = store.catalog.schema(protocol_id if domain == "common" else package_id)
		for key: String in schema.fields:
			var field: Dictionary = schema.fields[key]
			if field.audience != "local" or field.get("readonly", false) or (domain == "common" and not field.overridable):
				continue
			edits.append({"target": domain, "key": key, "op": "set" if values.has(key) else "unset", "value": values.get(key)})
	var error: Error = store.commit(package_id, protocol_id, revision, edits)
	error_label.text = "已保存；效果按声明的生效时机应用。" if error == OK else store.last_error
	if error == OK:
		revision = store.read(package_id).revision
	return error
