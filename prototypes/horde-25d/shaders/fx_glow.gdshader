shader_type spatial;
// Additive pixel effects in one MultiMesh: projectiles, orbs, hit sparks, death puffs.
// Each instance: transform (position, size), COLOR (tint), INSTANCE_CUSTOM.x = shape, .y = progress 0..1.
// UVs are snapped to `pixels` steps so effects share the sprites' blocky look.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float pixels = 12.0;
uniform float intensity = 1.6;

varying vec4 v_custom;
varying vec4 v_color;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	v_color = COLOR;
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX = VERTEX * scale;
}

void fragment() {
	vec2 p = (floor(UV * pixels) + 0.5) / pixels * 2.0 - 1.0;
	float d = length(p);
	float t = v_custom.y;
	float a = 0.0;
	if (v_custom.x < 0.5) {
		// 0: glowing dot (projectile, orb): bright core, dimmer rim
		a = d < 0.45 ? 1.0 : (d < 0.85 ? 0.45 : 0.0);
	} else if (v_custom.x < 1.5) {
		// 1: expanding ring (death puff), thins and fades as it grows
		float r = mix(0.25, 0.9, t);
		a = abs(d - r) < mix(0.3, 0.1, t) ? 1.0 - t : 0.0;
	} else {
		// 2: four-point spark (hit), shrinks over its life
		float arm = (1.0 - t) * 0.95;
		a = ((abs(p.x) < 0.17 && abs(p.y) < arm) || (abs(p.y) < 0.17 && abs(p.x) < arm)) ? 1.0 : 0.0;
	}
	if (a <= 0.0) {
		discard;
	}
	ALBEDO = v_color.rgb * intensity;
	ALPHA = a * v_color.a;
}
