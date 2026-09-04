## Keeps the persistent application root and swaps feature screens on session events.
extends Node

@export var screen_root: Control
@export var start_menu_scene: PackedScene
@export var lobby_scene: PackedScene
@export var placeholder_game_scene: PackedScene


func _ready() -> void:
	assert(screen_root != null, "Main requires an exported screen_root.")
	assert(start_menu_scene != null, "Main requires an exported start_menu_scene.")
	assert(lobby_scene != null, "Main requires an exported lobby_scene.")
	assert(placeholder_game_scene != null, "Main requires an exported placeholder_game_scene.")
	NetworkManager.lobby_joined.connect(_on_lobby_joined)
	NetworkManager.session_left.connect(_on_session_left)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.game_started.connect(_on_game_started)
	_show_start_menu()


func _on_lobby_joined() -> void:
	call_deferred("_show_lobby")


func _on_session_left(_reason: String) -> void:
	call_deferred("_show_start_menu")


func _on_connection_failed(_reason: String) -> void:
	call_deferred("_show_start_menu")


func _on_game_started() -> void:
	call_deferred("_show_placeholder_game")


func _show_start_menu() -> void:
	_replace_screen(start_menu_scene)


func _show_lobby() -> void:
	_replace_screen(lobby_scene)


func _show_placeholder_game() -> void:
	_replace_screen(placeholder_game_scene)


func _replace_screen(scene: PackedScene) -> void:
	var existing_children: Array[Node] = []
	for child: Node in screen_root.get_children():
		existing_children.append(child)
	for child: Node in existing_children:
		screen_root.remove_child(child)
		child.queue_free()

	var instance: Node = scene.instantiate()
	assert(instance is Control, "Main screens must use a Control root.")
	screen_root.add_child(instance)
