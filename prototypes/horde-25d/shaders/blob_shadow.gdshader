shader_type spatial;
// Soft oval shadow on the ground under a sprite. The mesh is a flat 1x1 plane (XZ) at the feet,
// scaled by the node or MultiMesh instance basis, so a horde's shadows share the sprites' instance buffer.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.08, 0.07, 0.14, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.38;
// Shadow size relative to the sprite width; flattened front to back so it reads as an oval.
uniform vec2 size = vec2(0.8, 0.48);

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), 1.0, length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), MODEL_MATRIX[3]);
	VERTEX = vec3(VERTEX.x * scale.x * size.x, 0.03, VERTEX.z * scale.z * size.y);
}

void fragment() {
	float d = length((UV - 0.5) * 2.0);
	// Two hard steps instead of a smooth falloff, to match the pixel look.
	float a = d < 0.7 ? 1.0 : (d < 1.0 ? 0.55 : 0.0);
	ALBEDO = color.rgb;
	ALPHA = a * strength;
}
