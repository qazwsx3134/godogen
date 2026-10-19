// Shared by fx_glow.gdshader (additive) and fx_dust.gdshader (alpha blend). Camera-facing quads; shapes:
//   0 soft dot   1 expanding ring   2 four-point spark   3 dust puff (grows and fades)
uniform float intensity = 1.0;
// Effects are drawn in blocks of 1/pixels of their size, to sit with the pixel sprites (0 = smooth).
uniform float pixels = 10.0;

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
	vec2 uv = pixels > 0.0 ? (floor(UV * pixels) + 0.5) / pixels : UV;
	vec2 p = uv * 2.0 - 1.0;
	float d = length(p);
	float t = v_custom.y;
	float a = 0.0;
	if (v_custom.x < 0.5) {
		a = (pow(clamp(1.0 - d, 0.0, 1.0), 1.5) + smoothstep(0.35, 0.0, d) * 0.6) * (1.0 - t * t);
	} else if (v_custom.x < 1.5) {
		float r = mix(0.2, 0.92, t);
		a = smoothstep(0.12, 0.0, abs(d - r)) * (1.0 - t);
	} else if (v_custom.x < 2.5) {
		float arm = (1.0 - t);
		float w = 0.12 * arm + 0.02;
		a = max(smoothstep(w, 0.0, abs(p.x)) * smoothstep(arm, 0.0, abs(p.y)), smoothstep(w, 0.0, abs(p.y)) * smoothstep(arm, 0.0, abs(p.x)));
	} else {
		float r = mix(0.45, 1.0, t);
		a = smoothstep(r, r * 0.3, d) * (1.0 - t) * 0.8;
	}
	if (a <= 0.01) {
		discard;
	}
	ALBEDO = v_color.rgb * intensity;
	ALPHA = clamp(a, 0.0, 1.0) * v_color.a;
}
