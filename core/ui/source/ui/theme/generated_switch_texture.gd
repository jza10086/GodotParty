@tool
extends ImageTexture
## An ephemeral animation frame. CheckButton's synthetic theme override fields
## cannot opt out of storage; this small marker resource may save, but its raster
## never does. ios_check_button.gd recognizes it and builds fresh local frames.
func _validate_property(property: Dictionary) -> void:
	if property.name == "image": property.usage &= ~PROPERTY_USAGE_STORAGE
