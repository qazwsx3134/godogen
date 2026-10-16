shader_type canvas_item;

// A single pixel-quantized quad; every animation follows Smoke.step() progress.
#include "res://addons/proto_kit/pixel_vfx.gdshaderinc"

// x: depth inside the lobe; yz: local coordinates used for broad light bands.
vec3 lobe(vec2 p, vec2 center, vec2 radii) {
	vec2 q = (p - center) / radii;
	return vec3(1.0 - length(q), q);
}

void fragment() {
	vec2 p = (pv_cell(UV) - vec2(0.5)) * rect_size + vec2(0.0, -10.0);
	float roll = progress * 4.5 + seed * 0.07;
	vec2 drift = vec2(sin(roll) * 1.8, cos(roll * 0.8) * 1.4);
	vec3 cloud = lobe(p, vec2(-7.0, 13.0) + drift, vec2(29.0, 25.0));
	vec3 next = lobe(p, vec2(-25.0, -1.0) - drift * 0.6, vec2(17.0, 22.0));
	if (next.x > cloud.x) { cloud = next; }
	next = lobe(p, vec2(24.0, 4.0) + drift * 0.7, vec2(18.0, 23.0));
	if (next.x > cloud.x) { cloud = next; }
	next = lobe(p, vec2(-12.0, -17.0) + drift * 0.8, vec2(19.0, 21.0));
	if (next.x > cloud.x) { cloud = next; }
	next = lobe(p, vec2(12.0, -11.0) - drift * 0.8, vec2(21.0, 24.0));
	if (next.x > cloud.x) { cloud = next; }
	next = lobe(p, vec2(15.0, 22.0) - drift * 0.5, vec2(21.0, 17.0));
	if (next.x > cloud.x) { cloud = next; }

	// Noise only nudges the contours. The interior contains no random color samples.
	float edge = (pv_noise(p * 0.15 + vec2(seed, progress * 0.3)) - 0.5) * 0.035;
	float depth = cloud.x + edge;
	float alpha = depth > 0.20 ? 0.80 : depth > 0.02 ? 0.50 : depth > -0.12 ? 0.22 : 0.0;
	float light_band = cloud.z + abs(cloud.y) * 0.18;
	vec3 color = light_band < -0.25 ? tone_3.rgb : light_band < 0.44 ? tone_2.rgb : tone_1.rgb;
	if (p.y > 23.0) { color = tone_1.rgb; }

	// Two narrow ribbons rise from the upper lobes, thinning and fading as they lift.
	for (int i = 0; i < 2; i++) {
		float phase = fract(progress * 1.6 + float(i) * 0.47);
		float rise = phase * 24.0;
		float side = float(i) * 23.0 - 13.0;
		vec2 center = vec2(side + sin(roll + phase * 4.0 + float(i)) * 3.0, -35.5 - rise);
		vec2 ribbon_point = p - center;
		ribbon_point.x -= sin(ribbon_point.y * 0.20 + roll) * 1.8;
		vec2 q = ribbon_point / vec2(3.8 - phase * 1.8, 12.0 - phase * 3.0);
		float ribbon = 1.0 - length(q);
		float wisp_alpha = ribbon > 0.25 ? 0.45 : ribbon > -0.10 ? 0.22 : 0.0;
		wisp_alpha *= (1.0 - phase) * smoothstep(0.0, 0.10, phase);
		if (wisp_alpha > alpha) {
			color = tone_3.rgb;
			alpha = wisp_alpha;
		}
	}
	float envelope = smoothstep(0.0, 0.012, progress) * (1.0 - smoothstep(0.86, 1.0, progress));
	COLOR = vec4(color, alpha * envelope);
}
