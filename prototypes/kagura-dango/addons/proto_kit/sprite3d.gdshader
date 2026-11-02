shader_type spatial;
// A 2D atlas sprite standing in the 3D world: feet on the ground, facing the camera, opaque with an alpha cut (no
// sorting), nearest texels. Spec: skill sprite-actors-3d. Shared pieces: sprite3d.gdshaderinc.
//
// One material serves a single node and a MultiMesh crowd:
//   node       frame / facing / phase / flash / dissolve / outline come from the uniforms (sprite3d_actor.gd sets them)
//   MultiMesh  use_instance_custom: INSTANCE_CUSTOM = (frame, flash, facing * (1 + dissolve), walk phase)
//              use_instance_color:  COLOR.rgb = tint, COLOR.a = outline role (sprite3d_sheet.gd instance_color())
// Which direction row to show is chosen on the CPU (sprite3d_sheet.gd): `frame` is already the absolute cell, and a
// mirrored row comes in as facing -1.
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

#include "res://addons/proto_kit/sprite3d.gdshaderinc"

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
// Atlas grid: columns, rows.
uniform vec2 frames = vec2(4.0, 6.0);
uniform bool use_instance_custom = false;
uniform bool use_instance_color = false;
// 0: upright, turns only around Y (trees, rocks). 0.35: pokebonk.com actors (art drawn level). 1: faces the camera
// fully (art already drawn from above; leaning back would squash it).
uniform float lean : hint_range(0.0, 1.0) = 1.0;
// Transparent strip under the feet in each cell (fraction of the cell), cut off so the feet touch the ground.
uniform float foot_gutter = 0.047;
uniform float frame = 0.0;
uniform float facing = 1.0;
uniform float phase = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
// Walk squash and stretch, a fraction of the height. 0 = no bob (sprites with a real walk cycle).
uniform float bob = 0.05;
// How far a hit (flash 1) squashes the sprite: width x(1 + 0.35 s), height x(1 - 0.3 s).
uniform float hit_squash = 0.6;
uniform float alpha_cut = 0.5;
uniform vec4 tint : source_color = vec4(1.0);
// Manual light: the sprite does not take scene lights (a lit flat card reads as cardboard). pokebonk.com uses
// 0.85 + 0.15 x the scene brightness.
uniform float light = 1.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// One-texel outline around a node's sprite. Alpha 0 = none.
uniform vec4 outline : source_color = vec4(1.0, 1.0, 1.0, 0.0);
// Outline colours by role for instances (COLOR.a, see sprite3d_sheet.gd ROLE_*): 0 none, 1..7 these.
// (Separate uniforms: Godot does not take default values for uniform arrays.)
uniform vec4 outline_player : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 outline_elite : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform vec4 outline_boss : source_color = vec4(1.0, 0.25, 0.2, 1.0);
uniform vec4 outline_ally : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform vec4 outline_role_5 : source_color = vec4(0.75, 0.4, 1.0, 1.0);
uniform vec4 outline_role_6 : source_color = vec4(0.4, 1.0, 0.45, 1.0);
uniform vec4 outline_role_7 : source_color = vec4(0.05, 0.05, 0.08, 1.0);
// The dissolve's leading edge (fraction of the noise range) glows in this colour.
uniform vec4 dissolve_color : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform float dissolve_edge = 0.12;
// Props between the camera and `focus` (the player, set every frame) are cut away with a 4x4 screen-door
// pattern, up to `see_through` of their pixels, so the player is never hidden and nothing needs sorting.
uniform bool see_through_enabled = false;
uniform vec3 focus = vec3(0.0);
uniform float focus_height = 1.0;
uniform float see_through : hint_range(0.0, 1.0) = 0.75;
// Radius of the cut-away window around the player, as a fraction of the view's depth (tan of the angle).
uniform float see_radius = 0.22;

varying flat float v_frame;
varying float v_flash;
varying float v_dissolve;
varying vec3 v_tint;
varying vec4 v_outline;

void vertex() {
	float fr = frame;
	float fl = flash;
	float face = facing;
	float ph = phase;
	float dis = dissolve;
	if (use_instance_custom) {
		fr = INSTANCE_CUSTOM.x;
		fl = INSTANCE_CUSTOM.y;
		face = sign(INSTANCE_CUSTOM.z);
		dis = clamp(abs(INSTANCE_CUSTOM.z) - 1.0, 0.0, 1.0);
		ph = INSTANCE_CUSTOM.w;
	}
	v_frame = fr;
	v_flash = fl;
	v_dissolve = dis;
	v_tint = tint.rgb * light;
	v_outline = outline;
	if (use_instance_color) {
		v_tint *= COLOR.rgb;
		int role = int(round((1.0 - COLOR.a) * 8.0));
		v_outline = role == 1 ? outline_player : role == 2 ? outline_elite : role == 3 ? outline_boss
				: role == 4 ? outline_ally : role == 5 ? outline_role_5 : role == 6 ? outline_role_6
				: role == 7 ? outline_role_7 : vec4(0.0);
	}

	vec3 local = sprite3d_local(VERTEX, foot_gutter, face);
	float b = sin(ph) * bob;
	float sq = fl * hit_squash;
	local.y *= (1.0 + b) * (1.0 - 0.3 * sq);
	local.x *= (1.0 - 0.6 * b) * (1.0 + 0.35 * sq);
	local = sprite3d_spin(local, MODEL_MATRIX);
	MODELVIEW_MATRIX = sprite3d_modelview(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, lean, 0.0);
	VERTEX = local * sprite3d_scale(MODEL_MATRIX);
}

void fragment() {
	if (see_through_enabled) {
		vec3 f = (VIEW_MATRIX * vec4(focus + vec3(0.0, focus_height, 0.0), 1.0)).xyz;
		if (VERTEX.z > f.z + 0.8) {
			float d = length(VERTEX.xy / -VERTEX.z - f.xy / -f.z);
			float amount = see_through * (1.0 - smoothstep(see_radius * 0.6, see_radius, d));
			if (sprite3d_bayer4(FRAGCOORD.xy) < amount) {
				discard;
			}
		}
	}
	vec2 cell = sprite3d_cell(v_frame, frames);
	vec2 uv = (cell + UV) / frames;
	vec4 c = texture(atlas, uv);
	if (v_dissolve > 0.0 && sprite3d_texel_hash(uv, atlas) < v_dissolve) {
		discard;
	}
	if (c.a < alpha_cut) {
		if (v_outline.a <= 0.0 || sprite3d_neighbour_alpha(atlas, uv, cell, frames) < alpha_cut) {
			discard;
		}
		ALBEDO = v_outline.rgb;
	} else {
		ALBEDO = mix(c.rgb * v_tint, flash_color.rgb, v_flash);
		if (v_dissolve > 0.0 && sprite3d_texel_hash(uv, atlas) < v_dissolve + dissolve_edge) {
			ALBEDO = dissolve_color.rgb;
		}
	}
}
