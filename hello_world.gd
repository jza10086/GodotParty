## Minimal command-line smoke test for the Godot 4.7 automation path.
extends SceneTree

const MESSAGE: String = "Hello, GodotParty!"


func _init() -> void:
	print(MESSAGE)
	quit(0)
