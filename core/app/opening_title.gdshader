shader_type canvas_item;

// Pure GPU floating-point sub-pixel transform & soft luma wipe for MSDF typography.
// Completely bypasses GUI snap_controls_to_pixels integer quantization -> zero text jitter!

uniform vec2 u_pivot_local = vec2(200.0, 80.0); // Screen center expressed in this Label's local coords
uniform float u_glide_x = 0.0;                  // Smooth floating-point horizontal glide (px)
uniform float u_stretch_x = 1.0;                // Subtle continuous horizontal tracking-in (1.028 -> 1.000)
uniform float u_zoom = 1.0;                     // Continuous micro camera drift zoom about screen center
uniform float u_wipe_edge = 4000.0;             // Soft left-to-right reveal edge in local x
uniform float u_wipe_width = 250.0;
uniform float u_alpha = 1.0;

varying float v_local_x;

void vertex() {
	v_local_x = VERTEX.x;
	// Smooth continuous tracking-in anchored at left edge (x = 0), then float glide, then float zoom about center
	vec2 pos = VERTEX;
	pos.x = pos.x * u_stretch_x + u_glide_x;
	pos = u_pivot_local + (pos - u_pivot_local) * u_zoom;
	VERTEX = pos;
}

void fragment() {
	// Keep Godot's built-in MSDF glyph decoding intact in COLOR; only modulate alpha
	float w = clamp((u_wipe_edge - v_local_x) / max(u_wipe_width, 1.0), 0.0, 1.0);
	w = w * w * (3.0 - 2.0 * w);
	COLOR.a *= w * u_alpha;
}
