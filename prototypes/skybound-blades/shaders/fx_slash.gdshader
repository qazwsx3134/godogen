shader_type spatial;
// Sword swing: a crescent that sweeps across the quad and thins out. Billboard quad.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float progress = 0.0;

void vertex() {
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), 1.0);
	float flip = sign(determinant(mat3(MODEL_MATRIX[0].xyz, MODEL_MATRIX[1].xyz, MODEL_MATRIX[2].xyz)));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s.x * flip, INV_VIEW_MATRIX[1] * s.y, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(-p.y, p.x); // -pi..pi, sweep from upper-left to lower-right
	float head = mix(2.4, -1.2, progress);
	float behind = clamp((a - head) / 1.6, 0.0, 1.0);
	float band = smoothstep(0.16, 0.0, abs(r - 0.72)) * (a > head ? 1.0 : 0.0);
	float v = band * (1.0 - behind) * (1.0 - smoothstep(0.6, 1.0, progress));
	ALBEDO = mix(tint.rgb, vec3(1.0), 0.5) * v * 1.4;
	ALPHA = clamp(v, 0.0, 1.0);
}
