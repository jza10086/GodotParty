@tool
extends Node2D
## Shared hollow cursor artwork for native pointers and multiplayer visuals.
## Both themes are drawn from white outlines; only the border receives player color.
const HOTSPOT: Vector2 = Vector2(4, 4)
const SHAPES: Dictionary[String, String] = {
	"LighTech": "M4 4 L4 34 L13 25 L26 25 Z",
	"Concept 3": "M4 4 Q2.8 3.3 3.2 5.8 L7.2 30 Q7.7 33.2 9.7 30.6 L15.1 23 L24 23 Q27 23 24.8 20.8 L6 4.8 Q4.8 4 4 4 Z"
}
static var _textures: Dictionary[String, ImageTexture] = {}

@export_enum("LighTech", "Concept 3") var cursor_theme: String = "LighTech":
	set(value):
		if cursor_theme != value:
			cursor_theme = value
			queue_redraw()

@export var color: Color = Color.WHITE:
	set(value):
		if color != value:
			color = value
			queue_redraw()

## Changes only this instance; the middle stays fully transparent.
func apply_color(value: Color) -> void:
	color = value

## Cache the same small transparent image used by the OS cursor and the scene.
## Neutral hairlines preserve contrast for the protocol's black and white colors.
static func texture_for(theme_name: String, tint: Color) -> ImageTexture:
	var key: String = theme_name + ":" + tint.to_html()
	if not _textures.has(key):
		var path: String = SHAPES[theme_name]
		var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="36" height="42" viewBox="0 0 36 42"><g fill="none" stroke-linejoin="round"><path d="%s" stroke="#f5f5f5" stroke-width="5"/><path d="%s" stroke="#141820" stroke-width="4"/><path d="%s" stroke="#%s" stroke-width="2.7"/></g></svg>' % [path, path, path, tint.to_html(false)]
		var image: Image = Image.new()
		var error: Error = image.load_svg_from_string(svg)
		if error != OK:
			push_error("Cannot render cursor theme: " + error_string(error))
			return null
		_textures[key] = ImageTexture.create_from_image(image)
	return _textures[key]

func _draw() -> void:
	draw_texture(texture_for(cursor_theme, color), -HOTSPOT)
