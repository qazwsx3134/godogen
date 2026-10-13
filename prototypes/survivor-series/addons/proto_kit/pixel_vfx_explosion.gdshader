shader_type canvas_item;
// PixelVfx "explosion": a fireball that bursts out, cools from white to the dark tone and breaks into chunks.
// Fills about two thirds of its rect at its widest.
#include "res://addons/proto_kit/pixel_vfx.gdshaderinc"

float radius() {
	return mix(0.3, 0.68, 1.0 - pow(1.0 - progress, 3.0));
}

float density(vec2 p) {
	float r = radius();
	float n = pv_fbm(p * 3.2 + seed);
	float edge = length(p) + (n - 0.5) * 0.5 * r;
	float inside = step(edge, r);
	// Late in its life it breaks up: noise above a rising threshold survives, in whole art pixels.
	float eaten = step(progress * progress * 1.7 - 0.25, pv_fbm(p * 3.0 + seed * 1.7 + progress));
	return inside * eaten;
}

float heat(vec2 p) {
	float r = radius();
	float core = 1.0 - length(p) / r;
	return core * 1.6 * (1.0 - progress) + pv_noise(p * 6.0 + seed) * 0.25 - progress * 0.35 + step(progress, 0.12) * 0.6;
}

#include "res://addons/proto_kit/pixel_vfx_shade.gdshaderinc"

void fragment() {
	COLOR = pv_shade(UV);
}
