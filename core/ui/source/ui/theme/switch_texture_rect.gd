@tool
extends TextureRect
## The texture is a live switch frame; store only the scene-authored geometry.
func _validate_property(property: Dictionary) -> void:
	if property.name == "texture": property.usage &= ~PROPERTY_USAGE_STORAGE
