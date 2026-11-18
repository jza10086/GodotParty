shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen : hint_screen_texture, repeat_disable, filter_linear_mipmap;

void fragment() {
	vec3 blurred = textureLod(screen, SCREEN_UV, 3.3).rgb;
	COLOR = vec4(mix(blurred, vec3(0.016,0.024,0.043), 0.76), 1.0);
}
