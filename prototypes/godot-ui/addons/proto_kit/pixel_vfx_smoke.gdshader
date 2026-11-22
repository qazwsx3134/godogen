shader_type canvas_item;
// Thin pixel wisps over a separate, persistent gameplay footprint. No dark speech-bubble outline.
// Centered quad; progress is driven by the hazard's simulation clock, never shader TIME.
#include "res://addons/proto_kit/pixel_vfx.gdshaderinc"
void fragment() {
	vec2 p = pv_p(pv_cell(UV));
	float envelope = min(1.0, progress / 0.06) * (1.0 - smoothstep(0.82, 1.0, progress));
	float d = -1.0;
	for (int i = 0; i < 4; i++) {
		float phase = float(i) * 1.73 + seed;
		vec2 center = vec2(sin(phase + progress * 5.0) * 0.65,
			cos(phase) * 0.28 - progress * 0.18);
		vec2 q = (p - center) / vec2(1.0, 0.48);
		d = max(d, 1.0 - length(q) / (0.5 + sin(phase + progress * 9.0) * 0.04));
	}
	float n = pv_noise(p * 7.0 + vec2(seed, progress * 2.0));
	float inside = step(0.12, d + (n - 0.5) * 0.4);
	vec4 color = n > 0.6 ? tone_3 : tone_2;
	color.a = inside * envelope * (n > 0.6 ? 0.6 : 0.38);
	COLOR = color;
}
