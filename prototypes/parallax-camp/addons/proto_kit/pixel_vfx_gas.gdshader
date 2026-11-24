shader_type canvas_item;
// Low, separated lobes: gas drifts across the ground and never flashes like fire.
#include "res://addons/proto_kit/pixel_vfx.gdshaderinc"
void fragment() {
	vec2 p = pv_p(pv_cell(UV));
	float grow = mix(0.25, 0.86, 1.0 - pow(1.0 - progress, 2.0));
	float d = -1.0;
	for (int i = 0; i < 5; i++) {
		float a = float(i) * 2.399 + seed;
		vec2 center = vec2(cos(a) * 0.42, sin(a) * 0.23) * grow;
		vec2 q = (p - center) / vec2(1.0, 0.62);
		d = max(d, 1.0 - length(q) / (grow * 0.38));
	}
	float n = pv_noise(p * 7.0 + seed + progress * 0.9);
	float inside = step(0.08 + smoothstep(0.45, 1.0, progress) * 0.8, d + (n - 0.5) * 0.3);
	vec4 color = n > 0.6 ? tone_3 : tone_2;
	color.a = inside * (1.0 - smoothstep(0.65, 1.0, progress)) * 0.56;
	COLOR = color;
}
