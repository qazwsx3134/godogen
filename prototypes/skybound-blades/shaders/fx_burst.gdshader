shader_type spatial;
// Hit burst: a bright core and four-to-eight spikes that flare and fade. Billboard quad.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float progress = 0.0;
uniform float spikes = 6.0;

void vertex() {
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), 1.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s.x, INV_VIEW_MATRIX[1] * s.y, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float grow = 0.35 + progress * 0.75;
	float fade = 1.0 - smoothstep(0.35, 1.0, progress);
	float star = pow(abs(cos(a * spikes * 0.5)), 18.0) * (1.0 - smoothstep(0.0, grow, r));
	float core = 1.0 - smoothstep(0.0, 0.32 * (1.0 - progress * 0.6), r);
	float ring = smoothstep(0.08, 0.0, abs(r - grow * 0.8)) * 0.6;
	float v = (star + core + ring) * fade;
	ALBEDO = mix(tint.rgb, vec3(1.0), core * 0.7) * v;
	ALPHA = clamp(v, 0.0, 1.0);
}
