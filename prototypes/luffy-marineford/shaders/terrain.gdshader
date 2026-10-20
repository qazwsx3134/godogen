shader_type spatial;
// pokebonk.com-style toon terrain, pixel-quantized in world space at `px_per_m` (the sprites' density).
// Surfaces by slope and height: plaza slabs on the floor, layered rock on the cliffs, frost on the terraces,
// sea ice in the quake trench. Lighting is a hand-made toon diffuse (bands, cool shadow, warm light), so it does
// not depend on lights the Compatibility renderer lacks. Fog comes from the Environment.
render_mode unshaded, cull_back, shadows_disabled;

uniform float px_per_m = 40.0;
uniform vec3 sun_dir = vec3(-0.45, 0.8, 0.35);
uniform vec4 light_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.55, 0.62, 0.82, 1.0);
uniform float bands = 3.0;
uniform vec4 slab_light : source_color = vec4(0.78, 0.8, 0.82, 1.0);
uniform vec4 slab_dark : source_color = vec4(0.62, 0.65, 0.7, 1.0);
uniform vec4 grout : source_color = vec4(0.45, 0.47, 0.53, 1.0);
uniform float slab_size = 2.0;
uniform vec4 rock_light : source_color = vec4(0.56, 0.55, 0.6, 1.0);
uniform vec4 rock_dark : source_color = vec4(0.36, 0.36, 0.43, 1.0);
uniform float strata = 0.55;
uniform vec4 frost : source_color = vec4(0.86, 0.9, 0.95, 1.0);
uniform vec4 ice : source_color = vec4(0.62, 0.8, 0.92, 1.0);
uniform vec4 ice_crack : source_color = vec4(0.88, 0.96, 1.0, 1.0);
// Below this height the floor is the trench's ice.
uniform float ice_below = -2.0;
// Above this height a flat floor is a terrace (frost) rather than the plaza.
uniform float terrace_above = 2.0;

varying vec3 world;
varying vec3 world_normal;

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
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 slabs(vec2 p) {
	// Staggered 2 m slabs with 1 px grout, each slab its own tone, a few chipped texels.
	vec2 q = p / slab_size;
	q.x += step(1.0, mod(floor(q.y), 2.0)) * 0.5;
	vec2 id = floor(q);
	vec2 f = fract(q);
	float edge = 1.0 / (slab_size * px_per_m);
	if (f.x < edge || f.y < edge) {
		return grout.rgb;
	}
	vec3 c = mix(slab_dark.rgb, slab_light.rgb, 0.35 + 0.65 * hash(id));
	if (hash(floor(p * px_per_m * 0.25)) > 0.96) {
		c *= 0.88;
	}
	return c;
}

vec3 rock(vec3 w) {
	// Horizontal strata, broken into blocks, darker toward the cliff foot.
	float layer = floor(w.y / strata);
	float along = (w.x + w.z) * 0.5;
	float block = floor(along / (1.2 + hash(vec2(layer, 3.0)) * 1.6) + hash(vec2(layer, 7.0)) * 5.0);
	vec3 c = mix(rock_dark.rgb, rock_light.rgb, hash(vec2(layer, block)) * 0.7 + 0.15);
	if (fract(w.y / strata) < 1.0 / (strata * px_per_m)) {
		c *= 0.7;
	}
	return c;
}

vec3 sea_ice(vec2 p) {
	vec3 c = mix(ice.rgb * 0.9, ice.rgb, noise(p * 0.3));
	float crack = abs(noise(p * 0.6) - 0.5);
	return crack < 0.02 ? ice_crack.rgb : c;
}

void fragment() {
	// Snap the world position to the pixel grid so every surface reads as texels of one size.
	vec3 w = (floor(world * px_per_m) + 0.5) / px_per_m;
	vec3 n = normalize(world_normal);
	float slope = 1.0 - n.y;
	vec3 base;
	if (slope > 0.35) {
		base = rock(w);
	} else if (w.y < ice_below) {
		base = sea_ice(w.xz);
	} else if (w.y > terrace_above) {
		base = mix(frost.rgb * 0.92, frost.rgb, noise(w.xz * 0.5));
	} else {
		base = slabs(w.xz);
	}
	float lambert = clamp(dot(n, normalize(sun_dir)), 0.0, 1.0);
	float banded = floor(lambert * bands + 0.5) / bands;
	vec3 lit = base * mix(shadow_color.rgb, light_color.rgb, 0.35 + 0.65 * banded);
	ALBEDO = lit;
}
