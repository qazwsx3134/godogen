shader_type spatial;
// Susanoo placeholder: Madara's own sprite blown up behind him as a translucent violet chakra giant, with flowing
// bands and a bright rim. `fade` 0..1 brings it in and out; the node's scale is its stage (bigger each level).
// Replace with real Susanoo art (ribcage -> half body -> armoured -> perfect) in the atlas when it exists.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 frames = vec2(4.0, 6.0);
uniform float frame = 0.0;
uniform float facing = 1.0;
uniform float foot_gutter = 0.047;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform vec4 color : source_color = vec4(0.5, 0.22, 0.9, 1.0);

varying vec2 v_local;

void vertex() {
	vec3 local = VERTEX;
	local.y -= foot_gutter;
	local.x *= facing < 0.0 ? -1.0 : 1.0;
	v_local = local.xy;
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 back = normalize(cross(right, up));
	// Pushed back from the camera so Madara stands in front of his Susanoo.
	vec4 origin = MODEL_MATRIX[3];
	origin.xyz -= normalize(INV_VIEW_MATRIX[3].xyz - origin.xyz) * 1.5;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(back, 0.0), origin);
	VERTEX = local * scale;
}

void fragment() {
	vec2 cell = vec2(mod(frame, frames.x), floor(frame / frames.x));
	vec4 c = texture(atlas, (cell + UV) / frames);
	if (c.a < 0.4) {
		discard;
	}
	float luma = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	float bands = 0.65 + 0.35 * sin(v_local.y * 18.0 - TIME * 5.0 + v_local.x * 4.0);
	ALBEDO = mix(color.rgb, vec3(0.85, 0.7, 1.0), luma * 0.6) * bands;
	ALPHA = fade * 0.62;
}
