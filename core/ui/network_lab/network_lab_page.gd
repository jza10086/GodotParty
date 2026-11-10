## Local-only network experiment drafts. Saving affects the next connection, never a live peer.
extends Control
signal back_requested()
const Form = preload("res://core/ui/party_config_form.gd")
const ButtonScene: PackedScene = preload("res://core/ui/ambient_reveal/components/button.tscn")
@onready var page: Control = %Workspace
var status: Label
var _settings: PartyInput
var _i18n: RefCounted
var _form: Form
var _schema: Dictionary

func configure(settings: PartyInput, i18n: RefCounted) -> void:
	_settings = settings
	_i18n = i18n
	_schema = PartyInput.network_lab_schema()
	page.set_title(_text("网络实验"))
	page.back_requested.connect(func() -> void: back_requested.emit())
	var display_schema: Dictionary = _schema.duplicate(true)
	for field: Dictionary in display_schema.fields.values():
		field.title = _text(field.title)
		field.description = _text(field.description)
	for category: Dictionary in display_schema.layout:
		category.title = _text(category.title)
	var note: Label = Label.new()
	note.text = _text("设置仅保存在本机，下次连接生效。房主侧影响本机发往客机的包；客机侧影响本机发往房主的包。可靠消息仍由 ENet 重传，原生 RPC、语音和时钟同步都会受到影响。")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_option(note)
	_form = preload("res://core/ui/party_config_form.tscn").instantiate()
	page.add_form(_form)
	var stored: Dictionary = {}
	for key: String in _schema.fields:
		if _settings.config.has_section_key("network_lab", key):
			stored[key] = _settings.config.get_value("network_lab", key)
	_form.configure(stored, true, {"schema": display_schema, "audience": "local"})
	var apply_button: Button = ButtonScene.instantiate()
	apply_button.text = _text("保存实验设置")
	apply_button.custom_minimum_size = Vector2(220, 56)
	page.actions.add_child(apply_button)
	apply_button.pressed.connect(_apply)
	status = page.status
	status.text = _text("默认关闭。先修改草稿，再保存；离开此页不会自动保存。")

func _text(value: String) -> String:
	return _i18n.text("core", StringName(value))

func _apply() -> void:
	var draft: Dictionary = _form.explicit_values()
	var previous: Dictionary = _settings.config.sections.duplicate(true)
	for key: String in _schema.fields:
		_settings.config.set_value("network_lab", key, draft.get(key, _schema.fields[key].default))
	var error: Error = _settings.save_settings()
	if error != OK:
		_settings.config.sections = previous
		status.text = _text("实验设置保存失败：") + error_string(error)
		return
	status.text = _text("实验设置已保存，下次创建或加入房间时生效。")
