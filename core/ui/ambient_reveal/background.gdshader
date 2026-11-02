shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 blue = (UV - vec2(0.08, 0.08)) * vec2(1.9, 2.2);
	vec2 right_glow = (UV - vec2(0.98, 0.78)) * vec2(2.2, 2.0);
	vec2 lower_glow = (UV - vec2(0.45, 1.15)) * vec2(2.0, 2.5);
	vec3 color = vec3(0.035, 0.052, 0.080);
	color += vec3(0.10, 0.17, 0.29) * exp(-dot(blue, blue)) * 0.55;
	color += vec3(0.08, 0.19, 0.31) * exp(-dot(right_glow, right_glow)) * 0.40;
	color += vec3(0.10, 0.14, 0.22) * exp(-dot(lower_glow, lower_glow)) * 0.25;
	float dither = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))) - 0.5;
	COLOR = vec4(color + dither / 255.0, 1.0);
}
