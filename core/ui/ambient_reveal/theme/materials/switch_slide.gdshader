shader_type canvas_item;
render_mode unshaded;

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform bool mirrored = false;
uniform vec4 thumb_off : source_color = vec4(0.714, 0.745, 0.788, 1.0);
uniform vec4 thumb_on : source_color = vec4(0.584, 0.78, 0.925, 1.0);
uniform vec4 tint : source_color = vec4(0.278, 0.549, 0.749, 0.58);

void fragment() {
	vec2 p = UV * vec2(48.0, 28.0);
	vec2 q = abs(p - vec2(24.0,14.0)) - vec2(11.0,0.0);
	float track = length(max(q, vec2(0.0))) - 11.0;
	float x = mix(14.0, 34.0, mirrored ? 1.0 - amount : amount);
	float circle = length(p - vec2(x, 14.0)) - 8.0;
	float knob = 1.0 - smoothstep(-0.5, 0.5, circle);
	float fill = (1.0 - smoothstep(-0.5, 0.5, track)) * tint.a * amount;
	vec3 thumb = mix(thumb_off.rgb, thumb_on.rgb, amount);
	float alpha = knob + fill * (1.0 - knob);
	COLOR = vec4((thumb * knob + tint.rgb * fill * (1.0 - knob)) / max(alpha, 0.0001), alpha);
}
