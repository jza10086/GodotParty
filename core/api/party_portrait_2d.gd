## A portrait scene whose exported image can be replaced by a bounded profile snapshot.
## The content package owns layout, color and rendering.
class_name PartyPortrait2D
extends Node2D

const SIZE: int = 32
const BYTE_COUNT: int = SIZE * SIZE * 4
@export var portrait: Texture2D

## JSON-safe, fixed-size RGBA8. Validate before allocating any texture from a network profile.
static func valid_pixels(encoded: Variant) -> bool:
	if not encoded is String or encoded.length() != 5464:
		return false
	var pixels: PackedByteArray = Marshalls.base64_to_raw(encoded)
	return pixels.size() == BYTE_COUNT and Marshalls.raw_to_base64(pixels) == encoded

static func with_pixels(template: Resource, encoded: Variant) -> PackedScene:
	if not template is PackedScene or not valid_pixels(encoded):
		push_error("Invalid portrait template or RGBA8 snapshot")
		return null
	var visual: Node = template.instantiate()
	if not visual is PartyPortrait2D:
		visual.free()
		push_error("Portrait snapshot requires a PartyPortrait2D scene")
		return null
	var image: Image = Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, Marshalls.base64_to_raw(encoded))
	visual.portrait = ImageTexture.create_from_image(image)
	var scene: PackedScene = PackedScene.new()
	var error: Error = scene.pack(visual)
	visual.free()
	if error != OK:
		push_error("Cannot pack portrait: " + error_string(error))
		return null
	return scene
