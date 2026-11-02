extends HSlider


func _ready() -> void:
	_mirror_fill()


func _notification(what: int) -> void:
	if what == NOTIFICATION_LAYOUT_DIRECTION_CHANGED and is_node_ready():
		_mirror_fill()


func _mirror_fill() -> void:
	# The fill inset follows the leading edge, while the track is inset on both ends.
	if theme_type_variation in [&"AmbientHSlider", &"AmbientHSliderRTL"]:
		theme_type_variation = &"AmbientHSliderRTL" if is_layout_rtl() else &"AmbientHSlider"
