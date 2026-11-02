@tool
extends RefCounted
## Shared classic iOS switch geometry. Design size is 102 × 62 (51:31),
## with a 4px inset circular thumb. No glass, shine, labels, or baked assets.
const DESIGN_SIZE := Vector2i(102, 62)

static func texture(slide: float, size: Vector2i, off: Color, on: Color, thumb: Color, border: Color, opacity: float = 1.0, mirrored: bool = false) -> ImageTexture:
	return ImageTexture.create_from_image(image(slide, size, off, on, thumb, border, opacity, mirrored))

static func image(slide: float, size: Vector2i, off: Color, on: Color, thumb: Color, border: Color, opacity: float = 1.0, mirrored: bool = false) -> Image:
	var width := maxi(size.x, 2)
	var height := maxi(size.y, 2)
	var pixels := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var radius := minf(width, height) * 0.5
	var scale := radius / 31.0
	var inset := 4.0 * scale
	var thumb_radius := radius - inset
	var amount := clampf(slide, 0.0, 1.0)
	var position := 1.0 - amount if mirrored else amount
	var center := Vector2(lerpf(radius, width - radius, position), height * 0.5)
	var track := off.lerp(on, amount)
	var alpha := clampf(opacity, 0.0, 1.0)
	for y in height:
		for x in width:
			var point := Vector2(x + 0.5, y + 0.5)
			var track_center := Vector2(clampf(point.x, radius, width - radius), height * 0.5)
			var distance := point.distance_to(track_center)
			var coverage := clampf(radius + 0.5 - distance, 0.0, 1.0)
			if coverage <= 0.0: continue
			var pixel := track
			# A fine optional outline follows the track's own RGBA, including alpha.
			var outline := border
			outline.a *= clampf(distance - (radius - scale - 0.5), 0.0, 1.0)
			pixel = pixel.blend(outline)
			# Small matte contact shadow makes the round thumb legible on gray.
			var shadow_coverage := clampf(thumb_radius + scale * 1.5 - point.distance_to(center + Vector2(0, scale)), 0.0, 1.0)
			pixel = pixel.blend(Color(0.0, 0.0, 0.0, 0.12 * shadow_coverage * thumb.a))
			var thumb_pixel := thumb
			thumb_pixel.a *= clampf(thumb_radius + 0.5 - point.distance_to(center), 0.0, 1.0)
			pixel = pixel.blend(thumb_pixel)
			pixel.a *= coverage * alpha
			pixels.set_pixel(x, y, pixel)
	return pixels
