shader_type spatial;
// An afterimage of a sprite (a dodge, a dash trail): tinted, striped, fading out and growing a little.
// Alpha-blended, no depth write. `fade` 1 -> 0 over its life. Same billboard as sprite3d.gdshader.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

#include "res://addons/proto_kit/sprite3d.gdshaderinc"

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 frames = vec2(4.0, 6.0);
uniform float lean : hint_range(0.0, 1.0) = 1.0;
uniform float foot_gutter = 0.047;
uniform float frame = 0.0;
uniform float facing = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform vec4 color : source_color = vec4(1.0, 0.25, 0.25, 1.0);

void vertex() {
	vec3 local = sprite3d_local(VERTEX, foot_gutter, facing);
	local.xy *= 1.0 + (1.0 - fade) * 0.25;
	MODELVIEW_MATRIX = sprite3d_modelview(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, lean, 0.0);
	VERTEX = local * sprite3d_scale(MODEL_MATRIX);
}

void fragment() {
	vec2 cell = sprite3d_cell(frame, frames);
	vec4 c = texture(atlas, (cell + UV) / frames);
	if (c.a < 0.5) {
		discard;
	}
	float stripe = 0.75 + 0.25 * mod(floor(FRAGCOORD.y / 2.0), 2.0);
	ALBEDO = mix(c.rgb, color.rgb, 0.65);
	ALPHA = fade * 0.7 * stripe;
}
