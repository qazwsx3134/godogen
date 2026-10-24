shader_type spatial;
// Wind-garden meadow: value-noise grass patches, a winding dirt path with worn stone, tiny flowers.
render_mode cull_disabled;

uniform vec3 grass_dark : source_color = vec3(0.24, 0.42, 0.18);
uniform vec3 grass_light : source_color = vec3(0.47, 0.64, 0.26);
uniform vec3 dirt : source_color = vec3(0.56, 0.45, 0.30);
uniform vec3 stone : source_color = vec3(0.62, 0.58, 0.50);
uniform vec3 flower_a : source_color = vec3(0.98, 0.93, 0.70);
uniform vec3 flower_b : source_color = vec3(0.70, 0.78, 0.98);
varying vec3 world;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int k = 0; k < 4; k++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = world.xz;
	float n = fbm(p * 0.22);
	vec3 grass = mix(grass_dark, grass_light, smoothstep(0.3, 0.75, n));
	grass *= 0.92 + 0.16 * noise(p * 3.1);
	// Path: a gentle S-curve across the field, its edge broken by noise.
	float center = sin(p.x * 0.17) * 2.2 + sin(p.x * 0.05 + 1.0) * 1.5;
	float d = abs(p.y - center) + (fbm(p * 0.9) - 0.5) * 1.1;
	float path = 1.0 - smoothstep(1.0, 1.6, d);
	vec2 cell = floor(p * 1.1);
	float slab = step(0.55, hash(cell)) * (1.0 - smoothstep(0.38, 0.5, max(abs(fract(p.x * 1.1) - 0.5), abs(fract(p.y * 1.1) - 0.5))));
	vec3 ground = mix(dirt * (0.9 + 0.2 * noise(p * 4.0)), stone * (0.9 + 0.15 * hash(cell)), slab * 0.85);
	vec3 col = mix(grass, ground, path);
	// Flowers: sparse dots on the grass only.
	vec2 fc = floor(p * 2.6);
	float f = step(0.965, hash(fc + 7.0)) * (1.0 - smoothstep(0.08, 0.16, length(fract(p * 2.6) - 0.5)));
	col = mix(col, mix(flower_a, flower_b, step(0.5, hash(fc + 3.0))), f * (1.0 - path));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
