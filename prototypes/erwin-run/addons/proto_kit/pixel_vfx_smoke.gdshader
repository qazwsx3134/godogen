shader_type canvas_item;
// PixelVfx "smoke": a cluster of round puffs that billows out in the first tenth of its life, drifts up and
// churns while it lingers, and breaks apart in the last fifth. Lit from above: light tops, dark undersides.
// Its rect's bottom middle is the ground point (use pivot (0.5, 1)); the cloud sits in the upper part.
#include "res://addons/proto_kit/pixel_vfx.gdshaderinc"

uniform int puffs : hint_range(1, 7) = 5;

float grow() {
	return min(progress / 0.1, 1.0);
}

float density(vec2 p) {
	float g = 0.55 + 0.45 * grow();
	float rise = progress * 0.25;
	float d = -1.0;
	for (int i = 0; i < 7; i++) {
		if (i >= puffs) {
			break;
		}
		float a = float(i) * 2.399 + seed;
		vec2 c = vec2(cos(a) * 0.42, sin(a) * 0.2 - 0.25 - rise) * g;
		float r = (0.3 + 0.12 * pv_hash(vec2(float(i), seed))) * g;
		// Puffs churn: each grows and shrinks a little out of step.
		r *= 1.0 + 0.08 * sin(progress * 18.0 + float(i) * 1.7);
		d = max(d, 1.0 - length(p - c) / r);
	}
	float n = pv_fbm(p * 4.0 + seed + vec2(0.0, progress * 2.0));
	float shape = d + (n - 0.5) * 0.35;
	float fade_edge = smoothstep(0.8, 1.0, progress) * 1.2;
	return step(0.0, shape) * step(fade_edge, n + shape * 0.6);
}

float heat(vec2 p) {
	float lit = 0.55 - p.y * 0.45;
	return lit + (pv_noise(p * 5.0 + seed) - 0.5) * 0.3;
}

#include "res://addons/proto_kit/pixel_vfx_shade.gdshaderinc"

void fragment() {
	COLOR = pv_shade(UV);
}
