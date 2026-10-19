shader_type spatial;
// A pixel sprite standing in the 3D world. The mesh is a 1x1 quad whose bottom edge is at y = 0 (feet),
// scaled by the node or MultiMesh instance basis. Opaque with a hard alpha cut: no sorting, nearest texels.
//
// One material serves both a single node (player, editor previews) and a MultiMesh horde:
//   node      frame / facing / phase / flash come from the uniforms below (the node's script sets them)
//   MultiMesh use_instance_custom = true, and INSTANCE_CUSTOM carries (frame, flash, facing, phase)
// Reference (docs/pokebonk-com/codex-bundle-analysis.md section 1): right = camera right, up = world up leaned
// toward the camera's up by `lean`; alpha < 0.5 discarded; a hit squashes the sprite wide and short.
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 frames = vec2(4.0, 2.0);
uniform bool use_instance_custom = false;
// 0: stands upright and turns only around Y (props). 1: faces the camera fully. Actors use 0.35.
uniform float lean : hint_range(0.0, 1.0) = 0.35;
uniform float frame = 0.0;
uniform float facing = 1.0;
uniform float phase = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// Walk squash and stretch, a fraction of the height. 0 = the sprite does not bob.
uniform float bob = 0.06;
// How far a hit (flash 1) squashes the sprite: width x(1 + 0.35 s), height x(1 - 0.3 s).
uniform float hit_squash = 0.6;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Role outline one atlas texel outside the sprite (player white, elite gold). Alpha 0 = none.
uniform vec4 outline : source_color = vec4(1.0, 1.0, 1.0, 0.0);
// Props between the camera and `focus` (the player, set every frame) are cut away with a 4x4 screen-door
// pattern, up to `see_through` of their pixels, so the player is never hidden and nothing needs sorting.
uniform bool see_through_enabled = false;
uniform vec3 focus = vec3(0.0);
uniform float see_through : hint_range(0.0, 1.0) = 0.75;
// Radius of the cut-away window around the player, as a fraction of the view's depth (tan of the angle).
uniform float see_radius = 0.22;

varying flat float v_frame;
varying float v_flash;

void vertex() {
	float fr = frame;
	float fl = flash;
	float face = facing;
	float ph = phase;
	if (use_instance_custom) {
		fr = INSTANCE_CUSTOM.x;
		fl = INSTANCE_CUSTOM.y;
		face = INSTANCE_CUSTOM.z;
		ph = INSTANCE_CUSTOM.w;
	}
	v_frame = fr;
	v_flash = fl;

	vec3 local = VERTEX;
	float s = sin(ph) * bob;
	float sq = fl * hit_squash;
	local.y *= (1.0 + s) * (1.0 - 0.3 * sq);
	local.x *= (1.0 - 0.6 * s) * (1.0 + 0.35 * sq) * (face < 0.0 ? -1.0 : 1.0);

	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 up = normalize(mix(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[1].xyz, lean));
	vec3 back = normalize(cross(right, up));
	mat4 billboard = mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(back, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
	VERTEX = local * scale;
}

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int index = i.x + i.y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[index]) + 0.5) / 16.0;
}

void fragment() {
	if (see_through_enabled) {
		vec3 f = (VIEW_MATRIX * vec4(focus + vec3(0.0, 1.2, 0.0), 1.0)).xyz;
		if (VERTEX.z > f.z + 0.8) {
			float d = length(VERTEX.xy / -VERTEX.z - f.xy / -f.z);
			float amount = see_through * (1.0 - smoothstep(see_radius * 0.6, see_radius, d));
			if (bayer4(FRAGCOORD.xy) < amount) {
				discard;
			}
		}
	}
	vec2 cell = vec2(mod(v_frame, frames.x), floor(v_frame / frames.x));
	vec2 uv = (cell + UV) / frames;
	vec4 c = texture(atlas, uv);
	if (c.a < 0.5) {
		if (outline.a <= 0.0) {
			discard;
		}
		// One texel out, clamped to this frame's rectangle so a neighbour frame never bleeds in.
		vec2 texel = 1.0 / vec2(textureSize(atlas, 0));
		vec2 lo = cell / frames + texel * 0.5;
		vec2 hi = (cell + 1.0) / frames - texel * 0.5;
		float n = max(max(texture(atlas, clamp(uv + vec2(texel.x, 0.0), lo, hi)).a, texture(atlas, clamp(uv - vec2(texel.x, 0.0), lo, hi)).a),
				max(texture(atlas, clamp(uv + vec2(0.0, texel.y), lo, hi)).a, texture(atlas, clamp(uv - vec2(0.0, texel.y), lo, hi)).a));
		if (n < 0.5) {
			discard;
		}
		ALBEDO = outline.rgb;
	} else {
		ALBEDO = mix(c.rgb * tint.rgb, flash_color.rgb, v_flash);
	}
}
