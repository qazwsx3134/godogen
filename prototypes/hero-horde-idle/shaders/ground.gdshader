// The battlefield floor: grass everywhere, a trampled arena (dirt and broken flagstones) where the zones and the
// boss stand. The arena edge is an ellipse broken up by blocky noise snapped to the texel grid, so the border reads
// as hand-placed pixels. Lit, so the sun's shadows and the telegraph lights land on it.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D grass : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D arena : source_color, filter_nearest_mipmap, repeat_enable;
// World metres per texture repeat.
uniform float grass_tile_m = 2.4;
uniform float arena_tile_m = 2.4;
// Arena ellipse on the ground (x, z) and its half extents (m).
uniform vec2 arena_center = vec2(0.9, 0.0);
uniform vec2 arena_half = vec2(6.2, 5.0);
// How ragged the border is (m) and the size of one border block (m).
uniform float edge_noise_m = 0.9;
uniform float edge_block_m = 0.3;
uniform vec4 grass_tint : source_color = vec4(1.0);
uniform vec4 arena_tint : source_color = vec4(1.0);

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float block_hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.37, 289.11))) * 43758.5453);
}

float block_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = block_hash(i);
	float b = block_hash(i + vec2(1.0, 0.0));
	float c = block_hash(i + vec2(0.0, 1.0));
	float d = block_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 p = world.xz;
	vec2 snapped = floor(p / edge_block_m) * edge_block_m;
	float n = block_noise(snapped * 0.9) * 0.65 + block_noise(snapped * 2.3) * 0.35;
	float r = length((snapped - arena_center) / arena_half);
	float inside = step(r + (n - 0.5) * edge_noise_m / min(arena_half.x, arena_half.y), 1.0);
	vec3 g = texture(grass, p / grass_tile_m).rgb * grass_tint.rgb;
	vec3 a = texture(arena, p / arena_tile_m).rgb * arena_tint.rgb;
	ALBEDO = mix(g, a, inside);
}
