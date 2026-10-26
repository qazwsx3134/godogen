// Faceted low-poly look: one normal per triangle from screen derivatives, so meshes need no flat normals.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform float rim_strength = 0.08;

void fragment() {
	vec3 c = albedo.rgb;
	if (use_vertex_color) {
		c *= pow(COLOR.rgb, vec3(2.2));  // vertex colors arrive as sRGB
	}
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) {  // derivative sign differs per renderer; a visible face always faces the camera
		n = -n;
	}
	NORMAL = n;
	ALBEDO = c;
	ROUGHNESS = 1.0;
	EMISSION = c * pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 3.0) * rim_strength;
}
