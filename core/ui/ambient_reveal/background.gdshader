shader_type canvas_item;
render_mode unshaded;
void fragment() {
	float t = dot(UV, vec2(0.76, 0.24));
	vec3 c = mix(vec3(0.024,0.035,0.067),vec3(0.043,0.067,0.125),1.0-abs(2.0*t-1.0));
	c += vec3(0.020,0.085,0.095)*(1.0-smoothstep(0.0,0.48,distance(UV,vec2(0.75,0.32))));
	c += vec3(0.065,0.038,0.008)*(1.0-smoothstep(0.0,0.43,distance(UV,vec2(0.2,0.8))));
	c *= 1.0-0.55*smoothstep(0.35,0.72,length(UV-0.5));
	c *= 0.97+0.03*cos(FRAGCOORD.y*1.57);
	COLOR = vec4(c,1.0);
}
