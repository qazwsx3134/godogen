shader_type canvas_item;
// Scene change on the old background's ghost (scripts/stage_motion.gd): `progress` 0 shows the old
// picture whole, 1 has it gone and the new one fully showing underneath.
// style 0 = 筆刷 (a ragged ink brush wipes left to right), 1 = 墨暈 (ink blooms from the middle),
// 2 = 故障 (rows tear sideways, colors split, blocks drop out).

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int style = 0;
uniform vec4 ink : source_color = vec4(0.08, 0.07, 0.12, 1.0);
// Width of the inked rim, as a share of the sweep.
uniform float rim = 0.06;
// The picture's width over its height, so the bloom stays round.
uniform float aspect = 1.777;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return 0.55 * noise(p) + 0.3 * noise(p * 2.3) + 0.15 * noise(p * 5.1);
}

void fragment() {
	vec2 uv = UV;
	float edge;
	if (style == 2) {
		// Tear: each band of rows slides sideways more as progress grows.
		float band = floor(uv.y * 24.0);
		float tear = (hash(vec2(band, floor(progress * 9.0))) - 0.5) * 0.18 * progress;
		uv.x += tear;
		float split = 0.012 * progress;
		vec4 base = texture(TEXTURE, uv);
		COLOR = vec4(texture(TEXTURE, uv + vec2(split, 0.0)).r, base.g,
			texture(TEXTURE, uv - vec2(split, 0.0)).b, base.a) * COLOR;
		COLOR.rgb *= 0.88 + 0.12 * step(0.5, fract(uv.y * 180.0));
		float block = hash(floor(UV * vec2(28.0, 16.0)));
		if (block < progress * 1.15 - 0.1 || uv.x < 0.0 || uv.x > 1.0) {
			discard;
		}
	} else {
		COLOR = texture(TEXTURE, uv) * COLOR;
		if (style == 1) {
			vec2 d = (uv - 0.5) * vec2(aspect, 1.0);
			edge = length(d) / (0.5 * length(vec2(aspect, 1.0)));
			edge += (fbm(uv * 6.0) - 0.5) * 0.35;
		} else {
			// Bristle streaks: rows advance unevenly, with a slow wobble down the stroke.
			float streak = noise(vec2(uv.y * 38.0, 0.0)) * 0.6 + noise(vec2(uv.y * 7.0, 3.0)) * 0.4;
			edge = uv.x * 0.8 + (streak - 0.5) * 0.25 + (fbm(uv * vec2(3.0, 12.0)) - 0.5) * 0.08;
		}
		// The sweep runs a little past both ends so 0 and 1 are clean.
		float front = progress * (1.0 + 2.0 * rim + 0.4) - rim - 0.2;
		if (edge < front) {
			discard;
		}
		float into = clamp((edge - front) / rim, 0.0, 1.0);
		COLOR.rgb = mix(ink.rgb, COLOR.rgb, smoothstep(0.0, 1.0, into));
	}
}
