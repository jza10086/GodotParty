// 独立诊断网格，金色边框标记 35×29 米棋盘；不参与玩法。
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(37.0, 31.0);
	vec2 distance_to_line = abs(fract(p) - 0.5);
	vec2 aa = max(fwidth(p), vec2(0.001));
	vec2 lines = 1.0 - smoothstep(vec2(0.008), vec2(0.008) + aa, distance_to_line);
	vec2 bounds = abs(p) - vec2(17.5, 14.5);
	float border = 1.0 - smoothstep(0.018, 0.018 + max(aa.x, aa.y), abs(max(bounds.x, bounds.y)));
	ALBEDO = mix(vec3(0.25, 0.65, 0.73), vec3(1.0, 0.68, 0.25), border);
	ALPHA = max(max(lines.x, lines.y) * 0.45, border * 0.9);
}
