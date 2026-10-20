shader_type spatial;
// pokebonk.com's PixelOutline as a full-screen quad: darken a pixel when one of its four neighbors is farther by more
// than threshold + threshold_per_m2 x distance^2 (meters). The ground's own depth step per pixel grows with the square
// of the distance (about d^2 x pixel angle / camera height), so a square term keeps far ground clean while a high
// camera still outlines a character's sides, not only the head (pokebonk.com's low camera uses 1 + 0.12 x d).
// camera_rig.gd sets threshold_per_m2 from the render height and the view; the value here is only a fallback. It reads the opaque color and depth of this viewport, so it draws first in the
// transparent queue (the material's render_priority is the lowest) and everything transparent lands on top of it.
// Characters write depth too, so the common crowd gets its outline here; the shader outline on the player, elites
// and bosses only adds the role color.
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D depth : hint_depth_texture, filter_nearest;
uniform vec4 outline_color : source_color = vec4(0.08, 0.09, 0.16, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.85;
uniform float threshold = 0.5;
uniform float threshold_per_m2 = 0.0004;
// Neighbor distance in render pixels (2 on a high-DPI phone keeps the line visible).
uniform float thickness = 1.0;
// Past this distance the depth is too coarse to trust; the outline fades out.
uniform float fade_from = 160.0;
uniform float fade_to = 260.0;

void vertex() {
	// Clip-space quad: z 0 is inside both depth conventions (OpenGL -1..1 and reverse-Z 0..1).
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_projection) {
	float d = textureLod(depth, uv, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, d) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 view = inv_projection * vec4(ndc, 1.0);
	return -view.z / view.w;
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;
	float center = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float farther = 0.0;
	farther = max(farther, linear_depth(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX) - center);
	farther = max(farther, linear_depth(SCREEN_UV - vec2(px.x, 0.0), INV_PROJECTION_MATRIX) - center);
	farther = max(farther, linear_depth(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX) - center);
	farther = max(farther, linear_depth(SCREEN_UV - vec2(0.0, px.y), INV_PROJECTION_MATRIX) - center);
	float edge = step(threshold + threshold_per_m2 * center * center, farther) * (1.0 - smoothstep(fade_from, fade_to, center));
	vec3 color = textureLod(screen, SCREEN_UV, 0.0).rgb;
	ALBEDO = mix(color, outline_color.rgb, edge * strength);
}
