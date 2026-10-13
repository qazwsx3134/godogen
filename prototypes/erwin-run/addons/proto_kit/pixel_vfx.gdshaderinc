// Shared by PixelVfx shader effects (pixel_vfx.gd sets every uniform here). An effect is a canvas_item shader:
//   #include "res://addons/proto_kit/pixel_vfx.gdshaderinc"
//   float density(vec2 p) { ... }   // >= 0.5 inside the shape; p in pv_p() space
//   float heat(vec2 p) { ... }      // 0 → dark tone, 1 → white
//   #include "res://addons/proto_kit/pixel_vfx_shade.gdshaderinc"
//   void fragment() { COLOR = pv_shade(UV); }
// See pixel_vfx_smoke.gdshader. Read `progress` (0 → 1 over the effect's life) and `seed` inside density/heat.
//
// Look rules: one art pixel per `pixel` rect px, hard edges (no dithering, no alpha blending), four fill tones
// plus a one-pixel outline in tone_0. Fading out is the shape breaking up, not transparency.

uniform float progress : hint_range(0.0, 1.0) = 0.3; // 0 start, 1 gone; driven by PixelVfx
uniform float seed = 0.0;
uniform vec2 rect_size = vec2(96.0);
uniform float pixel = 2.0;                          // rect px per art pixel
uniform bool outline = true;
uniform vec4 tone_0 : source_color = vec4(0.12, 0.1, 0.15, 1.0); // outline
uniform vec4 tone_1 : source_color = vec4(0.3, 0.28, 0.35, 1.0); // dark
uniform vec4 tone_2 : source_color = vec4(0.5, 0.48, 0.56, 1.0); // mid
uniform vec4 tone_3 : source_color = vec4(0.72, 0.7, 0.78, 1.0); // light
uniform vec4 tone_4 : source_color = vec4(1.0);                   // white

float pv_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float pv_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(pv_hash(i), pv_hash(i + vec2(1.0, 0.0)), u.x),
			mix(pv_hash(i + vec2(0.0, 1.0)), pv_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 0..1 fractal noise, three octaves.
float pv_fbm(vec2 p) {
	return pv_noise(p) * 0.55 + pv_noise(p * 2.1 + 7.3) * 0.3 + pv_noise(p * 4.3 + 1.7) * 0.15;
}

// Shape space: -1..1 across the rect height, x stretched by the aspect so circles stay round.
vec2 pv_p(vec2 uv) {
	vec2 p = uv * 2.0 - 1.0;
	p.x *= rect_size.x / rect_size.y;
	return p;
}

// One art pixel in shape units.
float pv_px() {
	return 2.0 * pixel / rect_size.y;
}

// Centre of the art pixel that `uv` falls in.
vec2 pv_cell(vec2 uv) {
	vec2 cells = max(floor(rect_size / pixel), vec2(1.0));
	return (floor(uv * cells) + 0.5) / cells;
}

vec4 pv_tone(float h) {
	return h > 0.85 ? tone_4 : h > 0.6 ? tone_3 : h > 0.3 ? tone_2 : tone_1;
}
