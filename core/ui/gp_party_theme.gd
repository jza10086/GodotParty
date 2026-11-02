## Shared Ambient Reveal resources used by framework screens.
class_name GPPartyTheme
extends RefCounted

const Background: PackedScene = preload("res://core/ui/ambient_reveal/components/background.tscn")

static func create() -> Theme:
	return preload("res://core/ui/ambient_reveal/ambient_theme.tres")
