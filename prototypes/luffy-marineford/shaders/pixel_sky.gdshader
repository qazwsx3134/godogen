shader_type sky;
// pokebonk.com's pixel sky: a vertical gradient cut into `bands` color steps, the steps dithered with a 4x4 Bayer
// pattern on a `block`-pixel screen grid (chunky texels at any resolution), a pixel sun and blocky cloud bands.

uniform vec4 zenith : source_color = vec4(0.27, 0.45, 0.78, 1.0);
uniform vec4 horizon : source_color = vec4(0.72, 0.84, 0.95, 1.0);
uniform vec4 below : source_color = vec4(0.62, 0.72, 0.84, 1.0);
uniform float bands = 7.0;
uniform float block = 4.0;
uniform vec3 sun_dir = vec3(-0.45, 0.35, -0.82);
uniform vec4 sun_color : source_color = vec4(1.0, 0.96, 0.82, 1.0);
uniform float sun_size = 0.035;
uniform vec4 cloud_color : source_color = vec4(0.96, 0.97, 1.0, 1.0);
uniform float cloud_cover = 0.42;

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i.y * 4 + i.x]) + 0.5) / 16.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void sky() {
	vec2 cell = floor(FRAGCOORD.xy / block);
	float threshold = bayer4(cell);
	float up = EYEDIR.y;
	vec3 c;
	if (up < 0.0) {
		c = below.rgb;
	} else {
		float t = pow(clamp(up / 0.6, 0.0, 1.0), 0.7);
		float stepped = floor(t * bands + threshold) / bands;
		c = mix(horizon.rgb, zenith.rgb, stepped);
		// Clouds: noise on the dome's projected plane, thresholded with the same dither.
		vec2 plane = EYEDIR.xz / max(up, 0.06) * 2.0;
		float n = noise(plane * 0.8) * 0.65 + noise(plane * 2.1) * 0.35;
		float cloud = step(1.0 - cloud_cover + (threshold - 0.5) * 0.12, n) * smoothstep(0.02, 0.12, up);
		c = mix(c, cloud_color.rgb, cloud * 0.85);
		float sun = step(1.0 - sun_size * sun_size, dot(EYEDIR, normalize(sun_dir)));
		c = mix(c, sun_color.rgb, sun);
	}
	COLOR = c;
}
