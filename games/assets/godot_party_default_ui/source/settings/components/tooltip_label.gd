extends Label

func _make_custom_tooltip(for_text: String) -> Object:
	var tooltip := preload("res://games/assets/godot_party_default_ui/source/settings/components/tooltip.tscn").instantiate()
	tooltip.text = for_text
	return tooltip
