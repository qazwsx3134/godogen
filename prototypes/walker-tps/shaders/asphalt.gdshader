shader_type spatial;
// War-torn asphalt, all procedural in world XZ (no textures, Compatibility-safe):
// repaired patches, a crack network, and scorched craters scattered on an 18 m grid.
uniform vec3 base_color : source_color = vec3(0.21, 0.195, 0.175);
uniform vec3 patch_color : source_color = vec3(0.24, 0.235, 0.225);
uniform float crater_chance : hint_range(0.0, 1.0) = 0.35;
uniform float crater_cell = 18.0;
varying vec3 world;

float hash(vec2 q) { return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 q) {
	vec2 i = floor(q), f = fract(q); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 q = world.xz;
	vec3 color = base_color * (0.85 + 0.3 * noise(q * 0.35));
	// Rectangular repairs: a 7 m grid, a third of the cells patched.
	vec2 pc = floor(q / 7.0);
	vec2 pf = fract(q / 7.0);
	float patch = step(0.66, hash(pc)) * step(0.15, pf.x) * step(pf.x, 0.8) * step(0.2, pf.y) * step(pf.y, 0.7);
	color = mix(color, patch_color, patch * 0.8);
	// Cracks: thin ridges of warped noise, masked so they do not cover the whole road.
	float c = abs(noise(q * 0.22 + noise(q * 0.9) * 1.5) - 0.5);
	float broken = smoothstep(0.45, 0.6, noise(q * 0.07 + 5.0));  // cracks come and go
	color *= mix(1.0, mix(0.5, 1.0, smoothstep(0.0, 0.012, c)), broken);
	// Craters: dark scorched centre, a lighter churned rim, soot fading out.
	vec2 cc = floor(q / crater_cell);
	float d = 1e3;
	float radius = 1.0;
	for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) {
		vec2 cell = cc + vec2(float(x), float(y));
		if (hash(cell + 3.1) > crater_chance) continue;
		vec2 at = (cell + vec2(hash(cell + 7.7), hash(cell + 1.3)) * 0.8 + 0.1) * crater_cell;
		float r = 1.5 + 2.5 * hash(cell + 5.2);
		float k = length(q - at) / r;
		if (k < d) { d = k; radius = r; }
	}
	float soot = 1.0 - smoothstep(0.6, 2.2 + noise(q * 0.8), d);
	color *= 1.0 - 0.7 * soot;
	color *= mix(0.25, 1.0, smoothstep(0.0, 0.7, d));
	ALBEDO = color;
	ROUGHNESS = 0.92;
}
