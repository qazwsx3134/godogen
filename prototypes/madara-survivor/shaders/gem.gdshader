shader_type spatial;
// Chakra orbs (experience): a bobbing glowing ball, colored by tier (INSTANCE_CUSTOM.x: 0 small .. 3 huge).
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform vec4 tier0 : source_color = vec4(0.35, 0.7, 1.0, 1.0);
uniform vec4 tier1 : source_color = vec4(0.4, 1.0, 0.75, 1.0);
uniform vec4 tier2 : source_color = vec4(0.75, 0.45, 1.0, 1.0);
uniform vec4 tier3 : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform vec4 rim : source_color = vec4(0.08, 0.1, 0.25, 1.0);

varying flat float v_tier;

void vertex() {
	v_tier = INSTANCE_CUSTOM.x;
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec4 origin = MODEL_MATRIX[3];
	origin.y += 0.35 + 0.12 * sin(TIME * 4.0 + origin.x * 1.3 + origin.z * 0.7);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], origin);
	VERTEX = VERTEX * scale;
}

uniform float pixels = 9.0;

void fragment() {
	vec2 p = (floor(UV * pixels) + 0.5) / pixels * 2.0 - 1.0;
	float d = length(p);
	if (d > 1.0) {
		discard;
	}
	vec3 c = v_tier < 0.5 ? tier0.rgb : (v_tier < 1.5 ? tier1.rgb : (v_tier < 2.5 ? tier2.rgb : tier3.rgb));
	c = mix(c, vec3(1.0), smoothstep(0.45, 0.0, length(p - vec2(-0.3, -0.3))) * 0.8);
	c = mix(c, rim.rgb, smoothstep(0.78, 0.95, d));
	ALBEDO = c * 1.15;
}
