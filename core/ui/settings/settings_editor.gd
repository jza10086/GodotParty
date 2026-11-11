## Fullscreen host for independent rule and profile editors; the caller owns draft/apply semantics.
extends Control
signal back_requested()
signal apply_requested()
const Form = preload("res://core/ui/party_config_form.gd")
@onready var page: Control = %Workspace
@onready var presets: Control = %Presets
@onready var apply_button: Button = %Apply

func _ready() -> void:
	page.back_requested.connect(func() -> void: back_requested.emit())
	apply_button.pressed.connect(func() -> void: apply_requested.emit())

func configure(title: String, panel: Control, editable: bool, description: String, reset: Callable = Callable()) -> void:
	page.set_title(title)
	apply_button.disabled = not editable
	if panel is Form:
		page.add_form(panel)
	else:
		page.add_option(panel)
		page.add_page("设置", panel, description, reset if editable else Callable())
	page.status.text = "修改先保留为草稿，点击应用后生效。" if editable else "只读查看：当前不能修改此设置。"
