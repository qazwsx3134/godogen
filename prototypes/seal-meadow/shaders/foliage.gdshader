// Grass tufts and flowers: vertex colors, both sides, a soft sway that grows with height.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, shadows_disabled;

uniform float sway = 0.12;

void vertex() {
	float h = max(VERTEX.y, 0.0);
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = TIME * 1.7 + world.x * 0.31 + world.z * 0.23;
	VERTEX.x += sin(t) * sway * h;
	VERTEX.z += cos(t * 0.8) * sway * 0.5 * h;
}

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2));  // vertex colors arrive as sRGB
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 1.0;
}
