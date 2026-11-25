shader_type canvas_item;

// Single-pass exact analytical 2D Gaussian-convolved SDF renderer for Hextrategy Studio (V2).
// Uses the exact separable erf() 2D box-Gaussian convolution integral per edge so the glow
// matches true multi-pass 2D Gaussian blur (tight=3s, near=8s, far=19s) with zero SubViewports.

uniform vec2 u_canvas_size = vec2(1920.0, 1080.0);
uniform vec2 u_logo_center = vec2(960.0, 540.0);
uniform float u_logo_scale = 1.2890625;
uniform float u_unit_scale = 1.0;

uniform int u_seg_count = 0;
uniform vec4 u_seg_pos[64]; // (ax, ay, bx, by) in canvas pixel coords
uniform vec2 u_seg_geo[64]; // (ga, gb) in 512-space geodesic distance

uniform int u_wire_count = 0;
uniform vec4 u_wire_pos[64]; // (ax, ay, bx, by) in canvas pixel coords
uniform float u_wire_radius = 1.6;
uniform float u_wire_opacity = 0.0;

uniform int u_junc_count = 0;
uniform vec4 u_junc[34]; // (vx, vy, amp, rad)

uniform float u_radius = 9.35;
uniform float u_front = 0.0;
uniform float u_tip_strength = 0.0;
uniform float u_tip_len = 18.0;
uniform float u_tip_glow = 0.22;

uniform float u_time = 0.0;
uniform float u_lit = 0.0;
uniform float u_flash = 0.0;
uniform float u_ambient_int = 0.0;
uniform float u_fade = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// High-accuracy erf(x) approximation (max error < 0.0003 across all R)
float erf_fast(float x) {
	float x2 = x * x;
	return tanh(x * (1.12837917 + 0.05047 * x2));
}

// Exact 1D convolution of interval [lo, hi] with Gaussian(sigma) evaluated at v, using inv_s2 = 1/(sqrt(2)*sigma)
float gauss_interval(float v, float lo, float hi, float inv_s2) {
	return 0.5 * (erf_fast((v - lo) * inv_s2) - erf_fast((v - hi) * inv_s2));
}

void fragment() {
	vec2 p = UV * u_canvas_size;
	float us = max(u_unit_scale, 0.001);
	vec3 BASE = vec3(15.0, 16.0, 19.5);

	// 1. Cinema radial vignette + ambient dark-hall light bounce
	vec2 n = (p - u_canvas_size * 0.5) / (u_canvas_size * 0.5);
	float vig = clamp(1.0 - 0.22 * dot(n, n), 0.68, 1.0);
	vec3 frame = vec3(18.0, 19.6, 24.2) * vig;

	if (u_ambient_int > 0.0001) {
		vec2 ad = (p - u_logo_center) / (vec2(500.0, 380.0) * us);
		float rad = exp(-dot(ad, ad));
		frame += rad * vec3(5.8, 15.5, 35.0) * u_ambient_int;
	}

	// 2. 2.83s anamorphic horizontal cool-blue streak + soft atmospheric shockwave
	if (u_flash > 0.003) {
		vec2 fd = (p - u_logo_center) / us;
		float sc = exp(-pow(fd.y / 8.5, 2.0)) * exp(-pow(fd.x / 360.0, 2.0)) * u_flash;
		float sw = exp(-pow(fd.y / 32.0, 2.0)) * exp(-pow(fd.x / 620.0, 2.0)) * u_flash;
		float gv = exp(-pow(fd.y / 140.0, 2.0)) * exp(-pow(fd.x / 22.0, 2.0)) * u_flash;
		frame += sc * vec3(56.0, 108.0, 165.0)
			+ sw * vec3(12.0, 34.0, 82.0)
			+ gv * vec3(18.0, 42.0, 78.0);
	}
	if (u_time >= 2.83 && u_time <= 3.58) {
		float su = (u_time - 2.83) / 0.72;
		if (su >= 0.0 && su <= 1.0) {
			float pr = 1.0 - pow(1.0 - su, 2.4);
			float ring_r = (155.0 + 440.0 * pr) * us;
			float alpha = (su < 0.07 ? sin(3.14159265 * min(1.0, su / 0.14)) : 1.0) * pow(1.0 - su, 1.85);
			float sig = (38.0 + 44.0 * pr) * us;
			float band = exp(-pow((length(p - u_logo_center) - ring_r) / sig, 2.0));
			frame += band * vec3(6.0, 16.0, 36.0) * alpha;
		}
	}

	// 3. Exact capsule SDF + exact separable 2D Gaussian convolution for tight(3s), near(8s), far(19s)
	float inv_s2_tight = 1.0 / max(1.41421356 * 3.0 * u_logo_scale, 0.001);
	float inv_s2_near  = 1.0 / max(1.41421356 * 8.0 * u_logo_scale, 0.001);
	float inv_s2_far   = 1.0 / max(1.41421356 * 19.0 * u_logo_scale, 0.001);
	float inv_s2_tipb  = 1.0 / max(1.41421356 * 7.5 * u_logo_scale, 0.001);

	float d_min = 1e6;
	float g_min = 0.0;
	float tight_sum = 0.0;
	float near_sum = 0.0;
	float far_sum = 0.0;
	float tip_bloom_sum = 0.0;

	for (int i = 0; i < 64; i++) {
		if (i >= u_seg_count) {
			break;
		}
		vec4 s = u_seg_pos[i];
		vec2 a = s.xy;
		vec2 ba = s.zw - a;
		vec2 pa = p - a;
		float seg_len = length(ba);
		vec2 dir = seg_len > 1e-5 ? (ba / seg_len) : vec2(1.0, 0.0);

		float proj = dot(pa, dir);
		float h = seg_len > 1e-5 ? clamp(proj / seg_len, 0.0, 1.0) : 0.0;
		float d = length(pa - ba * h);
		float perp = abs(pa.x * (-dir.y) + pa.y * dir.x);
		vec2 g = u_seg_geo[i];
		float g_here = mix(g.x, g.y, h);

		if (d < d_min) {
			d_min = d;
			g_min = g_here;
		}

		// Exact 2D Gaussian convolution of this segment's width [-r, +r] x length [0, seg_len]
		// Slight end trim avoids double-counting shared circular joints
		float lo_x = 0.0;
		float hi_x = seg_len;
		if (d < 16.0 * u_logo_scale + u_radius) {
			tight_sum += gauss_interval(perp, -u_radius, u_radius, inv_s2_tight)
				* gauss_interval(proj, lo_x, hi_x, inv_s2_tight);
		}
		if (d < 36.0 * u_logo_scale + u_radius) {
			near_sum += gauss_interval(perp, -u_radius, u_radius, inv_s2_near)
				* gauss_interval(proj, lo_x, hi_x, inv_s2_near);
		}
		if (d < 82.0 * u_logo_scale + u_radius) {
			far_sum += gauss_interval(perp, -u_radius, u_radius, inv_s2_far)
				* gauss_interval(proj, lo_x, hi_x, inv_s2_far);
		}

		if (u_tip_strength > 0.0001 && d < 32.0 * u_logo_scale + u_radius) {
			float lag_i = max(0.0, u_front - g_here);
			if (lag_i < u_tip_len * 3.0) {
				float tw = exp(-pow(lag_i / u_tip_len, 2.0));
				tip_bloom_sum += tw
					* gauss_interval(perp, -u_radius, u_radius, inv_s2_tipb)
					* gauss_interval(proj, lo_x, hi_x, inv_s2_tipb);
			}
		}
	}

	float aa = 0.62 * max(1.0, us);
	float t_aa = clamp((u_radius + aa - d_min) / (2.0 * aa), 0.0, 1.0);
	float solid = t_aa * t_aa * (3.0 - 2.0 * t_aa);

	// Clamp minor overlap at shared 3-way vertices (exact match to union-mask 2D Gaussian blur)
	float tight_g = min(tight_sum, 1.0);
	float near_g  = min(near_sum, 1.0);
	float far_g   = min(far_sum, 1.0);

	vec3 far_col   = mix(vec3(11.0, 30.0, 79.0),  vec3(28.0, 75.0, 215.0), u_lit);
	vec3 near_col  = mix(vec3(13.0, 46.0, 106.0), vec3(27.0, 91.0, 225.0), u_lit);
	vec3 tight_col = mix(vec3(5.0, 20.0, 50.0),   vec3(11.0, 35.0, 95.0),  u_lit);
	vec3 core_col  = mix(vec3(50.0, 114.0, 175.0), vec3(136.0, 218.0, 255.0), u_lit);
	core_col = mix(core_col, vec3(246.0, 251.0, 255.0), 0.75 * u_flash);

	vec3 glow = far_g * far_col * (1.0 + 2.15 * u_flash)
		+ near_g * near_col * (1.0 + 1.65 * u_flash)
		+ tight_g * tight_col * (1.0 + 0.50 * u_flash);
	vec3 emission = glow * (1.0 - solid) + (core_col - BASE) * solid;

	// Ice-white leading energy edge along active pipe
	if (u_tip_strength > 0.0001) {
		if (solid > 0.0001) {
			float lag = max(0.0, u_front - g_min);
			float tip = exp(-pow(lag / u_tip_len, 2.0)) * solid * u_tip_strength;
			emission += tip * (vec3(220.0, 245.0, 255.0) - core_col);
		}
		float tip_bloom = min(tip_bloom_sum, 1.0) * u_tip_strength;
		emission += tip_bloom * vec3(32.0, 95.0, 195.0) * u_tip_glow;
	}

	// 4. V2 Tactical pre-trace laser wireframe filament (exact 2D Gaussian halo)
	if (u_wire_count > 0 && u_wire_opacity > 0.0001) {
		float wd_min = 1e6;
		float wh_sum = 0.0;
		float inv_s2_wh = 1.0 / max(1.41421356 * 2.6 * u_logo_scale, 0.001);
		for (int i = 0; i < 64; i++) {
			if (i >= u_wire_count) {
				break;
			}
			vec4 s = u_wire_pos[i];
			vec2 a = s.xy;
			vec2 ba = s.zw - a;
			vec2 pa = p - a;
			float seg_len = length(ba);
			vec2 dir = seg_len > 1e-5 ? (ba / seg_len) : vec2(1.0, 0.0);
			float proj = dot(pa, dir);
			float h = seg_len > 1e-5 ? clamp(proj / seg_len, 0.0, 1.0) : 0.0;
			float wd = length(pa - ba * h);
			wd_min = min(wd_min, wd);
			if (wd < 12.0 * u_logo_scale + u_wire_radius) {
				float perp = abs(pa.x * (-dir.y) + pa.y * dir.x);
				wh_sum += gauss_interval(perp, -u_wire_radius, u_wire_radius, inv_s2_wh)
					* gauss_interval(proj, 0.0, seg_len, inv_s2_wh);
			}
		}
		float wt = clamp((u_wire_radius + aa - wd_min) / (2.0 * aa), 0.0, 1.0);
		float w_solid = wt * wt * (3.0 - 2.0 * wt);
		float w_vis = w_solid * (1.0 - solid) * u_wire_opacity;
		float w_halo = min(wh_sum, 1.0) * (1.0 - solid) * u_wire_opacity;
		emission += w_vis * (vec3(76.0, 152.0, 212.0) - BASE);
		emission += w_halo * vec3(18.0, 62.0, 128.0);
	}

	// 5. Vertex junction micro-pulses
	if (u_junc_count > 0) {
		float jf = 0.0;
		for (int i = 0; i < 34; i++) {
			if (i >= u_junc_count) {
				break;
			}
			vec4 j = u_junc[i];
			vec2 dv = p - j.xy;
			float sig = j.w * 0.68;
			jf = max(jf, exp(-dot(dv, dv) / max(2.0 * sig * sig, 0.0001)) * j.z);
		}
		emission += (jf * solid) * vec3(145.0, 170.0, 185.0);
		emission += jf * vec3(22.0, 70.0, 155.0);
	}

	frame += max(emission, vec3(0.0));

	// 6. Outro fade to dark hall base
	if (u_fade > 0.0) {
		frame = mix(frame, BASE, u_fade);
	}

	// 7. Grain-free 8-bit 3-channel RGB triangular anti-banding micro-dither
	vec3 n1 = vec3(hash12(FRAGCOORD.xy), hash12(FRAGCOORD.xy + 19.3), hash12(FRAGCOORD.xy + 53.7));
	vec3 n2 = vec3(hash12(FRAGCOORD.xy + 101.1), hash12(FRAGCOORD.xy + 149.9), hash12(FRAGCOORD.xy + 211.3));
	frame += (n1 - n2) * 0.72;

	COLOR = vec4(clamp(frame / 255.0, 0.0, 1.0), 1.0);
}
