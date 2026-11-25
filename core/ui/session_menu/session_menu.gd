## Presentation only. The app owns settings, session actions and gameplay input blocking.
extends Control

signal resume_requested()
signal framework_settings_requested()
signal protocol_settings_requested()
signal minigame_settings_requested()
signal lobby_requested()
signal main_panel_requested(panel: GPPartyDialog)

const TEXT: Dictionary[String, String] = {
	"Title": "游戏菜单",
	"Hint": "Esc 返回游戏",
	"Resume": "返回游戏",
	"FrameworkSettings": "框架设置",
	"ProtocolSettings": "协议设置",
	"MinigameSettings": "小游戏设置",
	"Lobby": "返回大厅",
}

func _ready() -> void:
	%Resume.pressed.connect(func() -> void: resume_requested.emit())
	%FrameworkSettings.pressed.connect(func() -> void: framework_settings_requested.emit())
	%ProtocolSettings.pressed.connect(func() -> void: protocol_settings_requested.emit())
	%MinigameSettings.pressed.connect(func() -> void: minigame_settings_requested.emit())
	%Lobby.pressed.connect(func() -> void: lobby_requested.emit())
	visibility_changed.connect(_focus_on_open)

func localize(i18n: RefCounted) -> void:
	for node_name: String in TEXT:
		get_node("%" + node_name).text = i18n.text("core", StringName(TEXT[node_name]))

func set_game_available(available: bool) -> void:
	%MinigameSettings.disabled = not available

## Rebuild only on menu open. The main controller owns the actual dialog across rounds.
func set_main_panels(controller: Node) -> void:
	for button: Node in %MainPanels.get_children():
		%MainPanels.remove_child(button)
		button.queue_free()
	for panel: GPPartyDialog in get_tree().get_nodes_in_group(&"party_main_menu_panel"):
		if controller.is_ancestor_of(panel):
			var button: Button = preload("res://core/ui/ambient_reveal/components/button.tscn").instantiate()
			button.custom_minimum_size.y = %Resume.custom_minimum_size.y
			button.text = panel.title
			button.pressed.connect(main_panel_requested.emit.bind(panel))
			%MainPanels.add_child(button)
	%MainPanels.visible = %MainPanels.get_child_count() > 0

func set_status(message: String) -> void:
	%Status.text = message
	%Status.visible = not message.is_empty()

func _focus_on_open() -> void:
	if is_visible_in_tree():
		%Resume.grab_focus()
