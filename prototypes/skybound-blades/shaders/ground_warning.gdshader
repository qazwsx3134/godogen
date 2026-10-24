shader_type spatial;
// Boss warning on the ground: a red disc that fills from the centre as the blow approaches,
// with a bright pulsing rim. progress 0 → 1 over the warning time. Flat quad.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.25, 0.15, 1.0);
uniform float progress = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float inside = 1.0 - smoothstep(0.97, 1.0, r);
	float rim = smoothstep(0.08, 0.0, abs(r - 0.95)) * (0.7 + 0.3 * sin(TIME * 18.0));
	float fill = (1.0 - smoothstep(progress - 0.02, progress, r)) * 0.35;
	float base = 0.08;
	float v = (rim + fill + base) * inside;
	ALBEDO = tint.rgb * v * 1.6;
	ALPHA = clamp(v, 0.0, 1.0);
}
