shader_type spatial;
// Endless pixel grass, drawn in world space so it never swims when the ground plane follows the player.
// Texels are snapped to `texels_per_meter`, the same density as the sprites, so ground and actors read as one
// piece of pixel art. Value noise picks between three greens, with sparse light specks for flowers.
render_mode unshaded, cull_back, shadows_disabled;

// 13.5 matches the sprites: one source pixel is 0.074 m (1 / 13.5), as in the reference game.
uniform float texels_per_meter = 13.5;
uniform vec4 dark : source_color = vec4(0.25, 0.55, 0.24, 1.0);
uniform vec4 mid : source_color = vec4(0.33, 0.66, 0.29, 1.0);
uniform vec4 light : source_color = vec4(0.42, 0.75, 0.33, 1.0);
uniform vec4 speck : source_color = vec4(0.95, 0.93, 0.75, 1.0);
// Size of the light/dark patches in meters.
uniform float patch_size = 3.5;

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
	vec2 texel = floor(world.xz * texels_per_meter);
	vec2 p = texel / texels_per_meter;
	float n = noise(p / patch_size) * 0.75 + noise(p / (patch_size * 0.3)) * 0.25;
	float grain = hash(texel) * 0.18;
	float v = n + grain;
	vec3 c = v < 0.45 ? dark.rgb : (v < 0.68 ? mid.rgb : light.rgb);
	if (hash(texel * 0.731 + 17.0) > 0.996) {
		c = speck.rgb;
	}
	ALBEDO = c;
}
