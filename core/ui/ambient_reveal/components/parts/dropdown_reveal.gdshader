shader_type canvas_item;
render_mode unshaded, blend_mul;

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform bool upwards = false;

void fragment() {
	float distance_from_button = upwards ? 1.0 - UV.y : UV.y;
	float feather = max(fwidth(UV.y), 0.001);
	float reveal = smoothstep(-feather, 0.0, progress - distance_from_button);
	// Scale the popup's existing color and alpha together, including its transparent corners.
	COLOR = vec4(reveal * smoothstep(0.0, 0.55, progress));
}
