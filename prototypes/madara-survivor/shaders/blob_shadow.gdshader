shader_type spatial;
// Soft oval shadow on the ground under a sprite. The mesh is a flat 1x1 plane (XZ) at the feet, scaled by the node
// or MultiMesh instance basis, so a horde's shadows share the sprites' instance buffer. It stays on the ground when
// the body is in the air (a launched ninja) and shrinks with the height.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.32, 0.18, 0.1, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.38;
// Shadow size relative to the sprite size; flattened front to back so it reads as an oval.
uniform vec2 size = vec2(0.55, 0.33);

void vertex() {
	float s = length(MODEL_MATRIX[2].xyz);
	vec4 origin = MODEL_MATRIX[3];
	float shrink = 1.0 / (1.0 + max(origin.y, 0.0) * 0.35);
	origin.y = 0.03;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), origin);
	VERTEX = vec3(VERTEX.x * s * size.x * shrink, 0.0, VERTEX.z * s * size.y * shrink);
}

void fragment() {
	float d = length((UV - 0.5) * 2.0);
	ALBEDO = color.rgb;
	ALPHA = smoothstep(1.0, 0.3, d) * strength;
}
