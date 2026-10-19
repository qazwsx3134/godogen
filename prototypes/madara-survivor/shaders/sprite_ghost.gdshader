shader_type spatial;
// A Sharingan afterimage: the player's sprite, tinted and fading out, left where the dodged hit was going to land.
// Same billboard as sprite_billboard; alpha-blended, no depth write. `fade` 1 -> 0 over its life.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 frames = vec2(4.0, 6.0);
uniform float lean : hint_range(0.0, 1.0) = 1.0;
uniform float foot_gutter = 0.047;
uniform float frame = 0.0;
uniform float facing = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform vec4 color : source_color = vec4(1.0, 0.25, 0.25, 1.0);

void vertex() {
	vec3 local = VERTEX;
	local.y -= foot_gutter;
	local.x *= facing < 0.0 ? -1.0 : 1.0;
	// Grows a little as it fades, like an image left behind.
	local.xy *= 1.0 + (1.0 - fade) * 0.25;
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 up = normalize(mix(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[1].xyz, lean));
	vec3 back = normalize(cross(right, up));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(back, 0.0), MODEL_MATRIX[3]);
	VERTEX = local * scale;
}

void fragment() {
	vec2 cell = vec2(mod(frame, frames.x), floor(frame / frames.x));
	vec4 c = texture(atlas, (cell + UV) / frames);
	if (c.a < 0.5) {
		discard;
	}
	float stripe = 0.75 + 0.25 * mod(floor(FRAGCOORD.y / 2.0), 2.0);
	ALBEDO = mix(c.rgb, color.rgb, 0.65);
	ALPHA = fade * 0.7 * stripe;
}
