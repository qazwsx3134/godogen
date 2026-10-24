shader_type spatial;
// Ground ring that expands and fades (skill, heal, taunt). Flat quad on the ground.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float progress = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float edge = 0.25 + progress * 0.7;
	float ring = smoothstep(0.1, 0.0, abs(r - edge));
	float fill = (1.0 - smoothstep(0.0, edge, r)) * 0.18;
	float v = (ring + fill) * (1.0 - progress);
	ALBEDO = tint.rgb * v * 1.5;
	ALPHA = clamp(v, 0.0, 1.0);
}
