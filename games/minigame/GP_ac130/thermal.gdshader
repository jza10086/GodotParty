shader_type canvas_item;
uniform sampler2D frame : hint_screen_texture, repeat_disable, filter_linear;
void fragment() {
	vec2 uv = SCREEN_UV;
	float value = dot(texture(frame, uv).rgb, vec3(0.299, 0.587, 0.114));
	float noise = fract(sin(dot(mod(FRAGCOORD.xy, 211.0) + floor(TIME * 18.0), vec2(12.9898, 78.233))) * 43758.5453);
	value += (noise - 0.5) * 0.035 - 0.035 * length(uv - 0.5);
	COLOR = vec4(vec3(value), 1.0);
}
