## Framework layout adapter for the unmodified GodotPartyUI settings API.
## The source component owns widgets, drafts and capture; this layer owns host sizing/actions.
extends "res://core/ui/source/settings/settings_page.gd"

@onready var actions: HBoxContainer = %Actions

func _ready() -> void:
	super._ready()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Tabs.offset_left = 48
	$Tabs.offset_top = 48
	$Tabs.offset_right = -48
	$Tabs.offset_bottom = -188
	var back: Button = $Back
	back.reparent(actions)
	back.custom_minimum_size = Vector2(200, 64)
	back.text = "取消 / 返回"
	actions.child_entered_tree.connect(_style_action)
	_style_action(back)

func _style_action(child: Node) -> void:
	if child is Button:
		child.theme_type_variation = "PartyButtonSetting"
		child.custom_minimum_size = Vector2(200, 72)
		child.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func focus_back() -> void:
	actions.get_node("Back").grab_focus()


## Attach a schema form to an existing tab; configure() releases it with the tab.
func add_content(tab_id: String, content: Control) -> void:
	_tabs[tab_id].add_child(content)
