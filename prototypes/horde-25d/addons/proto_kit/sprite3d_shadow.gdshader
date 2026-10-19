shader_type spatial;
// Soft oval shadow on the ground under a sprite (sprites cast no real shadows). The mesh is a flat 1x1 plane (XZ),
// scaled by the node or MultiMesh instance basis. Two ways to place it:
//   flat ground (default)  the shadow shares the body's instances (one ArrayMesh: shadow surface + sprite surface);
//                          it stays at `ground_y` when the body is in the air and shrinks with the height.
//   height field           `ground_from_instance`: a separate MultiMesh (or node) whose instances sit on the ground
//                          under each body; the shadow stays where it is put. Pass the body's height above the
//                          ground in INSTANCE_CUSTOM.x (MultiMesh, use_custom_data) or `air_height` to shrink it.
// Spec: skill sprite-actors-3d.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.32, 0.18, 0.1, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.38;
// Shadow size relative to the sprite size; flattened front to back so it reads as an oval.
uniform vec2 size = vec2(0.55, 0.33);
uniform float ground_y = 0.0;
uniform bool ground_from_instance = false;
uniform bool use_instance_custom = false;
uniform float air_height = 0.0;
// Lifted this far above the ground against z-fighting.
uniform float lift = 0.03;
// Two hard steps (full, then 55%) instead of the smooth falloff, for chunkier pixel art.
uniform bool stepped = false;

void vertex() {
	float s = length(MODEL_MATRIX[2].xyz);
	vec4 origin = MODEL_MATRIX[3];
	float air = max(origin.y - ground_y, 0.0);
	if (ground_from_instance) {
		air = use_instance_custom ? INSTANCE_CUSTOM.x : air_height;
	} else {
		origin.y = ground_y;
	}
	origin.y += lift;
	float shrink = 1.0 / (1.0 + max(air, 0.0) * 0.35);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), origin);
	VERTEX = vec3(VERTEX.x * s * size.x * shrink, 0.0, VERTEX.z * s * size.y * shrink);
}

void fragment() {
	float d = length((UV - 0.5) * 2.0);
	ALBEDO = color.rgb;
	float a = stepped ? (d < 0.7 ? 1.0 : (d < 1.0 ? 0.55 : 0.0)) : smoothstep(1.0, 0.3, d);
	ALPHA = a * strength;
}
