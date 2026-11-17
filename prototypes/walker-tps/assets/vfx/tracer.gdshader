shader_type spatial;
// Tracer streak: a unit quad (x across, y along) stretched along the node's local +Z
// (scale.z = length) and turned around that axis to face the camera, so it reads as a
// glowing line from any side. Hot core, orange edge, fading toward the back end.
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;

uniform float width = 0.16;
uniform vec4 core : source_color = vec4(1.0, 0.97, 0.85, 1.0);
uniform vec4 edge : source_color = vec4(1.0, 0.5, 0.12, 1.0);

void vertex() {
	vec3 axis = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz;
	vec3 center = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 side = normalize(cross(normalize(axis), center));
	vec3 p = center + axis * VERTEX.y + side * VERTEX.x * width;
	POSITION = PROJECTION_MATRIX * vec4(p, 1.0);
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);   // 1 on the centre line
	float along = 1.0 - UV.y;                      // 1 at the front (+Z), 0 at the back
	float hot = smoothstep(0.55, 1.0, across);
	ALBEDO = mix(edge.rgb, core.rgb, hot);
	ALPHA = smoothstep(0.0, 0.6, across) * along * along;
}
