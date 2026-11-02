extends Label

func _make_custom_tooltip(for_text: String) -> Object:
	var tooltip := preload("res://core/ui/source/settings/components/tooltip.tscn").instantiate()
	tooltip.text = for_text
	return tooltip
