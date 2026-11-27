shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;

varying vec3 surface_position;

void vertex() {
	surface_position = VERTEX;
}

void fragment() {
	// Small mineral flecks on several faces of the same stone.
	vec3 direction = normalize(surface_position);
	float fleck = max(
		dot(direction, normalize(vec3(0.7, 0.67, 0.42))),
		dot(direction, normalize(vec3(-0.82, 0.38, 0.63)))
	);
	fleck = max(fleck, dot(direction, normalize(vec3(0.12, 0.7, -0.62))));
	float pulse = pow(max(0.0, sin(TIME * 1.7 + MODEL_MATRIX[3].x)), 6.0);
	ALBEDO = vec3(0.66, 0.71, 0.94);
	ALPHA = smoothstep(0.994, 0.999, fleck) * pulse * 0.54;
}
