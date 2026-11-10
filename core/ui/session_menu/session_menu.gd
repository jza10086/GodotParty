## Presentation only. The app owns settings, session actions and gameplay input blocking.
extends Control

signal resume_requested()
signal framework_settings_requested()
signal minigame_settings_requested()
signal lobby_requested()

const TEXT: Dictionary[String, String] = {
	"Title": "游戏菜单",
	"Hint": "Esc 返回游戏",
	"Resume": "返回游戏",
	"FrameworkSettings": "框架设置",
	"MinigameSettings": "小游戏设置",
	"Lobby": "返回大厅",
}

func _ready() -> void:
	%Resume.pressed.connect(func() -> void: resume_requested.emit())
	%FrameworkSettings.pressed.connect(func() -> void: framework_settings_requested.emit())
	%MinigameSettings.pressed.connect(func() -> void: minigame_settings_requested.emit())
	%Lobby.pressed.connect(func() -> void: lobby_requested.emit())
	visibility_changed.connect(_focus_on_open)

func localize(i18n: RefCounted) -> void:
	for node_name: String in TEXT:
		get_node("%" + node_name).text = i18n.text("core", StringName(TEXT[node_name]))

func set_game_available(available: bool) -> void:
	%MinigameSettings.disabled = not available

func set_status(message: String) -> void:
	%Status.text = message
	%Status.visible = not message.is_empty()

func _focus_on_open() -> void:
	if is_visible_in_tree():
		%Resume.grab_focus()
