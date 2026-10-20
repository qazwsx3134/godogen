shader_type spatial;
// Endless desert sand in world space (the plane follows the player; the pattern stays put).
// Broad dune shading from value noise, wind ripples running across it, darker hard-packed patches and pebbles.
render_mode unshaded, cull_back, shadows_disabled;

uniform vec4 sand_light : source_color = vec4(0.93, 0.79, 0.6, 1.0);
uniform vec4 sand_mid : source_color = vec4(0.86, 0.69, 0.5, 1.0);
uniform vec4 sand_dark : source_color = vec4(0.74, 0.56, 0.4, 1.0);
uniform vec4 packed_earth : source_color = vec4(0.7, 0.5, 0.36, 1.0);
// Meters between ripple crests, and the wind direction they run across.
uniform float ripple_spacing = 0.55;
uniform vec2 wind = vec2(0.86, 0.5);
uniform float dune_size = 22.0;

varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	float dune = noise(p / dune_size) * 0.65 + noise(p / (dune_size * 0.35)) * 0.35;
	vec3 c = mix(sand_dark.rgb, sand_light.rgb, smoothstep(0.2, 0.85, dune));
	// Ripples: a sine across the wind, bent by noise so the lines wander, faded where the dunes are dark.
	float along = dot(p, normalize(wind)) + noise(p * 0.18) * 2.4;
	float ripple = sin(along / ripple_spacing * 6.2832);
	c = mix(c, sand_mid.rgb, smoothstep(0.55, 1.0, ripple) * 0.45 * smoothstep(0.25, 0.6, dune));
	// Hard-packed earth patches.
	float patch = noise(p / 9.0 + 31.0);
	c = mix(c, packed_earth.rgb, smoothstep(0.68, 0.78, patch) * 0.55);
	// Sparse pebbles.
	vec2 cell = floor(p * 3.0);
	if (hash(cell) > 0.985 && length(fract(p * 3.0) - 0.5) < 0.18) {
		c *= 0.78;
	}
	ALBEDO = c;
}
