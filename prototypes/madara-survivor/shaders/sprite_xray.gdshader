shader_type spatial;
// The player's silhouette where something stands in front of it: drawn only where the depth test FAILS
// (depth_test_inverted), so a crowd or a tree never hides where you are. Same billboard as sprite_billboard.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_inverted, blend_mix, shadows_disabled;

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 frames = vec2(4.0, 6.0);
uniform float lean : hint_range(0.0, 1.0) = 1.0;
uniform float frame = 0.0;
uniform float facing = 1.0;
uniform float foot_gutter = 0.047;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.55);

void vertex() {
	vec3 local = VERTEX;
	local.y -= foot_gutter;
	local.x *= facing < 0.0 ? -1.0 : 1.0;
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 up = normalize(mix(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[1].xyz, lean));
	vec3 back = normalize(cross(right, up));
	// Nudged toward the camera so the body's own depth hides the silhouette; only something truly in front shows it.
	vec4 origin = MODEL_MATRIX[3];
	origin.xyz += normalize(INV_VIEW_MATRIX[3].xyz - origin.xyz) * 0.35;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(back, 0.0), origin);
	VERTEX = local * scale;
}

void fragment() {
	vec2 cell = vec2(mod(frame, frames.x), floor(frame / frames.x));
	if (texture(atlas, (cell + UV) / frames).a < 0.5) {
		discard;
	}
	// Horizontal pixel stripes read as "behind something" without hiding the crowd.
	float stripe = mod(floor(FRAGCOORD.y / 3.0), 2.0);
	ALBEDO = color.rgb;
	ALPHA = color.a * (0.6 + 0.4 * stripe);
}
