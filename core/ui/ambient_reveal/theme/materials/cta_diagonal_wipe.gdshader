shader_type canvas_item;
render_mode unshaded;

// 0.0 = completely empty, 1.0 = completely filled
uniform float fill_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 rect_size = vec2(200.0, 48.0);
// Horizontal diagonal offset in pixels across the button height (consistent angle at any width)
uniform float slant_px = 36.0;
uniform float edge_softness = 1.5;

varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

void fragment() {
	float h = max(rect_size.y, 1.0);
	float total_span = max(rect_size.x + slant_px, 1.0);
	// Forward slash angle: top leads slightly ahead of bottom as fill sweeps left -> right
	float diag_x = local_px.x + local_px.y * (slant_px / h);
	float cutoff = mix(-edge_softness, total_span + edge_softness, fill_progress);
	float mask = 1.0 - smoothstep(cutoff - edge_softness, cutoff + edge_softness, diag_x);
	COLOR.a *= mask;
}
