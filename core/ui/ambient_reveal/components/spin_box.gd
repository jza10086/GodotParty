extends SpinBox

const SURFACE = preload("res://core/ui/ambient_reveal/components/parts/input_surface.tscn")


func _ready() -> void:
	get_line_edit().add_child(SURFACE.instantiate())
