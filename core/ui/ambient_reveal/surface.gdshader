shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D backdrop : source_color, repeat_disable, filter_linear_mipmap;
uniform bool use_backdrop = false;
uniform vec2 backdrop_origin = vec2(0.0);
uniform vec2 backdrop_extent = vec2(1100.0, 760.0);
varying vec2 local_position;
uniform float radius = 20.0;
// 0: panel, 1: button, 2: input. Only panels keep a frosted surface at rest.
uniform int surface_role = 0;
uniform float hover_amount = 0.0;
uniform float focus_amount = 0.0;

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
	float mask = 1.0 - smoothstep(-1.0, 0.0, d);
	float border = (1.0 - smoothstep(0.5, 1.5, abs(d))) * mask;
	float reveal = max(hover_amount, focus_amount);
	float edge = 0.075 + reveal * 0.23;
	vec3 tint = vec3(0.58, 0.78, 0.93);
	vec3 color;
	float alpha;
	if (surface_role == 1) {
		// A 1-unit inset follows the same rounded contour on all four sides.
		float outer = 1.0 - smoothstep(-0.5, 0.5, d);
		float inner = 1.0 - smoothstep(-0.5, 0.5, d + 1.0);
		color = tint;
		alpha = reveal * (0.085 * inner + 0.22 * (outer - inner));
	} else if (surface_role == 2) {
		color = tint;
		alpha = mask * mix(0.025 + reveal * 0.025, edge, border);
	} else {
		vec2 coord = use_backdrop ? (backdrop_origin + p) / backdrop_extent : SCREEN_UV;
		vec3 blurred;
		if (use_backdrop) {
			blurred = textureLod(backdrop, coord, 5.0).rgb;
		} else {
			blurred = textureLod(screen_texture, coord, 5.0).rgb;
		}
		color = mix(blurred, vec3(0.67, 0.79, 0.90), 0.045);
		color = mix(color, tint, border * edge);
		alpha = mask;
	}
	float dither = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))) - 0.5;
	COLOR = vec4(color + dither / 255.0, alpha);
}
