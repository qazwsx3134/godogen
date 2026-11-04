shader_type canvas_item;
// Brief flash, then a broken radial crown. The center clears early to keep actors visible.
#include "res://addons/proto_kit/pixel_vfx.gdshaderinc"
float radius() {
	return mix(0.18, 0.72, 1.0 - pow(1.0 - progress, 3.0));
}
float density(vec2 p) {
	float r = radius();
	float n = pv_noise(p * 8.0 + seed);
	float rays = sin(atan(p.y, p.x) * 7.0 + seed) * 0.12;
	float outer = step(length(p), r + rays * r + (n - 0.5) * 0.12);
	float hollow = smoothstep(0.14, 0.4, progress) * r * 0.76;
	float inner = step(hollow, length(p));
	float fragments = step(smoothstep(0.45, 1.0, progress) * 0.95, n);
	return outer * inner * fragments * (1.0 - step(0.98, progress));
}
float heat(vec2 p) {
	return 0.5 + (1.0 - progress) * 0.4 + pv_noise(p * 8.0 + seed) * 0.22;
}
#include "res://addons/proto_kit/pixel_vfx_shade.gdshaderinc"
void fragment() {
	COLOR = pv_shade(UV);
}
