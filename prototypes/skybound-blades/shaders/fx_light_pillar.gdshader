shader_type spatial;
// Level-up column: a soft vertical beam with rising streaks. Open cylinder mesh.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float progress = 0.0;

void fragment() {
	float h = UV.y; // 0 top, 1 bottom
	float streak = 0.5 + 0.5 * sin(UV.x * 37.7 + (h + progress * 2.0) * 18.0);
	float body = smoothstep(0.0, 0.5, h) * (0.55 + 0.45 * streak);
	float fade = sin(3.14159 * progress);
	float v = body * fade;
	ALBEDO = mix(tint.rgb, vec3(1.0), 0.3) * v;
	ALPHA = clamp(v, 0.0, 1.0);
}
