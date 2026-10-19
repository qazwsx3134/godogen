shader_type spatial;
// Experience gems: a bobbing pixel diamond, colored by tier (INSTANCE_CUSTOM.x: 0 small .. 3 huge).
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform float pixels = 10.0;
uniform vec4 outline : source_color = vec4(0.1, 0.08, 0.15, 1.0);
uniform vec4 tier0 : source_color = vec4(0.35, 0.75, 1.0, 1.0);
uniform vec4 tier1 : source_color = vec4(0.4, 0.95, 0.5, 1.0);
uniform vec4 tier2 : source_color = vec4(1.0, 0.4, 0.45, 1.0);
uniform vec4 tier3 : source_color = vec4(1.0, 0.85, 0.3, 1.0);

varying flat float v_tier;

void vertex() {
	v_tier = INSTANCE_CUSTOM.x;
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec4 origin = MODEL_MATRIX[3];
	origin.y += 0.25 + 0.12 * sin(TIME * 4.0 + origin.x * 1.3 + origin.z * 0.7);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], origin);
	VERTEX = VERTEX * scale;
}

void fragment() {
	vec2 p = (floor(UV * pixels) + 0.5) / pixels * 2.0 - 1.0;
	float d = abs(p.x) * 1.4 + abs(p.y);
	if (d > 1.0) {
		discard;
	}
	vec3 c = v_tier < 0.5 ? tier0.rgb : (v_tier < 1.5 ? tier1.rgb : (v_tier < 2.5 ? tier2.rgb : tier3.rgb));
	if (d > 0.72) {
		c = outline.rgb;
	} else if (p.x < 0.0 && p.y < 0.0) {
		c = mix(c, vec3(1.0), 0.45);
	}
	ALBEDO = c;
}
