shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D backdrop : source_color, repeat_disable, filter_linear_mipmap;
uniform bool use_backdrop = false;
uniform vec2 backdrop_origin = vec2(0.0);
uniform vec2 backdrop_extent = vec2(1100.0, 760.0);
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec3 blurred;
	if (use_backdrop) {
		blurred = textureLod(backdrop, (backdrop_origin + local_position) / backdrop_extent, 5.0).rgb;
	} else {
		blurred = textureLod(screen_texture, SCREEN_UV, 5.0).rgb;
	}
	// StyleBoxFlat supplies the rounded mesh, its antialiasing and the state colors.
	COLOR.rgb = mix(blurred, COLOR.rgb, COLOR.a);
}
