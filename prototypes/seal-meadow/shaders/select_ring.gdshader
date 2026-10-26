shader_type spatial;
// Ground ring under a selected unit or a move destination: dashed, slowly turning. Flat quad.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.45, 0.35, 1.0);
uniform float dashes = 10.0;
uniform float speed = 0.6;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) + TIME * speed;
	float dash = step(0.35, fract(a / 6.28318 * dashes));
	float ring = smoothstep(0.1, 0.0, abs(r - 0.82)) * mix(0.55, 1.0, dash);
	float glow = smoothstep(0.9, 0.3, r) * 0.12;
	float v = ring + glow;
	ALBEDO = tint.rgb * v;
	ALPHA = clamp(v, 0.0, 1.0);
}
