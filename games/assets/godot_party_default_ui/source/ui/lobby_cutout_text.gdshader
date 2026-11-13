shader_type canvas_item;
render_mode unshaded;
// The scene captures the lobby before drawing the action button.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
void fragment() {
	COLOR = vec4(textureLod(screen_texture, SCREEN_UV, 0.0).rgb, COLOR.a);
}
