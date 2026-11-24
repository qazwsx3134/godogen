shader_type spatial;
// The player's silhouette where something stands in front of it: drawn only where the depth test FAILS
// (depth_test_inverted), so a crowd or a tree never hides where you are. Same billboard as sprite3d.gdshader;
// give it a higher render_priority than the sprite. It does not follow the body's bob, hit squash or tumble (meant
// for a player that does not tumble). Spec: skill sprite-actors-3d.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_inverted, blend_mix, shadows_disabled;

#include "res://addons/proto_kit/sprite3d.gdshaderinc"

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 frames = vec2(4.0, 6.0);
uniform float lean : hint_range(0.0, 1.0) = 1.0;
uniform float frame = 0.0;
uniform float facing = 1.0;
uniform float foot_gutter = 0.047;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.55);
// Moved this far toward the camera so the body's own depth hides the silhouette; only something truly in front shows it.
uniform float toward_camera = 0.35;

void vertex() {
	vec3 local = sprite3d_local(VERTEX, foot_gutter, facing);
	MODELVIEW_MATRIX = sprite3d_modelview(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, lean, toward_camera);
	VERTEX = local * sprite3d_scale(MODEL_MATRIX);
}

void fragment() {
	vec2 cell = sprite3d_cell(frame, frames);
	if (texture(atlas, (cell + UV) / frames).a < 0.5) {
		discard;
	}
	// Horizontal pixel stripes read as "behind something" without hiding the crowd.
	float stripe = mod(floor(FRAGCOORD.y / 3.0), 2.0);
	ALBEDO = color.rgb;
	ALPHA = color.a * (0.6 + 0.4 * stripe);
}
