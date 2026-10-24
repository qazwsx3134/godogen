shader_type spatial;
// Billboarded HP bar drawn in one quad: frame, background, damage trail and fill.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float ratio : hint_range(0.0, 1.0) = 1.0;
uniform float trail : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.52, 0.86, 0.42, 1.0);
uniform vec4 low_color : source_color = vec4(0.95, 0.36, 0.28, 1.0);
uniform vec4 trail_color : source_color = vec4(1.0, 0.94, 0.78, 1.0);
uniform vec4 back_color : source_color = vec4(0.06, 0.07, 0.09, 0.82);
uniform vec4 frame_color : source_color = vec4(0.02, 0.02, 0.03, 0.95);
uniform float border = 0.16;

void vertex() {
	// Face the camera, keep the node's scale.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	mat4 bill = mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y, INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * bill;
}

void fragment() {
	vec2 px = fwidth(UV);
	// Same border thickness in pixels on all sides: the bar is wider than tall on screen.
	vec2 edge = vec2(border * px.x / max(px.y, 1e-6), border);
	bool inside = UV.x > edge.x && UV.x < 1.0 - edge.x && UV.y > edge.y && UV.y < 1.0 - edge.y;
	float x = (UV.x - edge.x) / (1.0 - 2.0 * edge.x);
	vec4 c = frame_color;
	if (inside) {
		c = back_color;
		if (x < trail) c = trail_color;
		if (x < ratio) c = mix(low_color, fill_color, smoothstep(0.2, 0.45, ratio));
		c.rgb *= mix(1.15, 0.85, UV.y);
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
