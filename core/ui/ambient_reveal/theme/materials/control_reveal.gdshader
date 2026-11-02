shader_type canvas_item;
render_mode unshaded;

uniform bool input_surface = false;
uniform float radius = 12.0;
uniform float hover_amount = 0.0;
uniform float focus_amount = 0.0;
varying vec2 local_position;

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	// Recover the rectangle's local size even when the editor canvas is zoomed.
	vec2 rect_size = fwidth(local_position) / max(fwidth(UV), vec2(0.0000001));
	vec2 p = UV * rect_size;
	float r = min(radius, min(rect_size.x, rect_size.y) * 0.5);
	float d = rounded_box(p - rect_size * 0.5, rect_size * 0.5, r);
	float outer = 1.0 - smoothstep(-0.5, 0.5, d);
	float inner = 1.0 - smoothstep(-0.5, 0.5, d + 1.0);
	float reveal = max(hover_amount, focus_amount);
	float fill = input_surface ? 0.025 + reveal * 0.025 : reveal * 0.085;
	float rim = input_surface ? 0.075 + reveal * 0.23 : reveal * 0.22;
	COLOR = vec4(vec3(0.58, 0.78, 0.93), fill * inner + rim * (outer - inner));
}
