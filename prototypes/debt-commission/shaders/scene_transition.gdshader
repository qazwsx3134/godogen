shader_type canvas_item;
// Scene change drawn on the old background's ghost (scripts/stage_motion.gd), which lies over the new
// background: `progress` 0 shows the old picture whole, 1 shows the new one exactly. The new picture is
// read from the screen under the ghost, so both pictures take part. Patterns are laid out in screen
// space, so landscape and portrait sweep the same.
// style 0 = 筆刷: a dry ink brush drags left to right — bristle streaks, 飛白 gaps, an inked rim, spatter.
// style 1 = 墨暈: drops of ink bloom with feathered edges until the screen is ink, hold, then the
//           ink clears in other blots and the new scene comes through still wet.
// style 2 = 故障: a broken signal — stuttering slices, RGB split, moshed blocks, scanlines, static;
//           the two pictures swap block by block.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int style = 0;
uniform vec4 ink : source_color = vec4(0.07, 0.06, 0.1, 1.0);
// Width of the brush's loaded tip, as a share of the sweep (its drying tail is about twice that).
uniform float rim = 0.07;
// Varies the drops, slices and blocks from one transition to the next.
uniform float seed = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;


float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += amp * noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		amp *= 0.5;
	}
	return sum;
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// The old picture at a screen position (its texture is laid out however the frame crops it).
vec3 old_at(vec2 screen, vec2 uv, vec2 screen_uv, vec2 uv_per_screen, sampler2D tex) {
	return texture(tex, uv + (screen - screen_uv) * uv_per_screen).rgb;
}

// Nearest of five drops that land one after another and spread as `a` runs 0→1 (below 1 = inked),
// with warped, ragged edges.
float blots(vec2 p, float aspect, float s, float a) {
	vec2 warp = vec2(fbm(p * 2.2 + s), fbm(p * 2.2 + s + 31.7)) - 0.5;
	vec2 q = p + warp * 0.4;
	float d = 9.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i) + s * 7.0;
		vec2 c = vec2(0.1 + 0.8 * hash(vec2(fi, 1.3)), 0.1 + 0.8 * hash(vec2(fi, 7.9))) * vec2(aspect, 1.0);
		float delay = float(i) * 0.09;
		float grown = clamp((a - delay) / (1.0 - delay), 0.0, 1.0);
		// Soaking in: quick at first, then slower.
		// Sized to the screen's diagonal (2.04 in landscape), so portrait takes as long to cover.
		float r = (0.5 + 0.5 * hash(vec2(fi, 4.1))) * 2.4 * length(vec2(aspect, 1.0)) / 2.04
			* (1.0 - (1.0 - grown) * (1.0 - grown));
		float di = length(q - c) / max(r, 1e-4);
		// Smooth union, so neighbouring drops merge like wet ink instead of meeting on a seam.
		float h = clamp(0.5 + 0.5 * (di - d) / 0.3, 0.0, 1.0);
		d = mix(di, d, h) - 0.3 * h * (1.0 - h);
	}
	return d + (fbm(p * 12.0 + s) - 0.5) * 0.1;
}

vec4 brush(vec2 s, vec3 old_color, vec3 new_color) {
	// Bristles: rows run unevenly, with a slow wobble down the stroke.
	float bristle = noise(vec2(s.y * 90.0, seed));
	float streak = noise(vec2(s.y * 46.0, seed)) * 0.55 + noise(vec2(s.y * 8.0, seed + 3.0)) * 0.45;
	float edge = s.x * 0.8 + (streak - 0.5) * 0.2 + (fbm(s * vec2(3.0, 14.0) + seed) - 0.5) * 0.06;
	float front = progress * (1.0 + 4.0 * rim + 0.4) - rim - 0.2;
	float into = (edge - front) / rim;  // >1 ahead of the brush, 0..1 its loaded tip, <0 the drying tail
	if (into > 1.0) {
		// Spatter flung just ahead of the brush.
		float spot = step(0.993, hash(floor(s * vec2(260.0, 146.0)) + seed)) * step(into, 1.0 + 0.8 * hash(vec2(floor(s.y * 60.0), seed)));
		return vec4(mix(old_color, ink.rgb, spot), 1.0);
	}
	// The ink itself: dense, with bristle streaks of lighter and darker black.
	vec3 tone = ink.rgb * (0.7 + 0.6 * bristle) + vec3(0.05) * fbm(s * vec2(6.0, 60.0) + seed);
	// 飛白: further back the brush runs dry and the new scene shows through more and more bristle gaps.
	float dry = clamp(-into / 2.2, 0.0, 1.0);
	float gap = noise(vec2(s.y * 140.0, seed + 9.0)) * 0.7 + noise(vec2(s.x * 30.0, s.y * 300.0)) * 0.3;
	if (gap < dry * 1.15 - 0.05) {
		return vec4(new_color, 1.0);
	}
	return vec4(tone, 1.0);
}

vec4 ink_wash(vec2 s, float aspect, vec3 old_color, vec3 new_color) {
	vec2 p = s * vec2(aspect, 1.0);
	float a = smoothstep(0.0, 0.56, progress);  // spreading
	float b = smoothstep(0.62, 1.0, progress);  // clearing, from other drops

	// Sumi tones: grey washes and dark pools, drifting slowly while the ink covers the screen.
	vec2 drift = vec2(progress * 0.3, -progress * 0.18);
	float grain = fbm(p * 4.0 + drift + seed);
	float fibres = noise(vec2(p.x * 70.0 + p.y * 11.0, p.y * 20.0) + seed);
	vec3 tone = mix(ink.rgb, vec3(0.36, 0.34, 0.38), smoothstep(0.35, 0.8, grain) * 0.75);
	tone *= 0.92 + 0.16 * fibres;

	float m = blots(p, aspect, seed, a);
	float body = smoothstep(1.03, 0.97, m);
	// Ink pools at the wet front, and feathers out along the paper fibres just beyond it.
	float pool = smoothstep(0.7, 0.98, m) * body;
	float feather = smoothstep(1.18, 1.0, m) * (1.0 - body) * step(0.55, fibres) * 0.55;
	float wash = mix(0.78, 0.95, grain);  // a thin wash lets the picture show through a little
	float density = clamp(body * wash + pool * 0.3 + feather, 0.0, 1.0);
	density = mix(density, 1.0, smoothstep(0.8, 1.0, a));  // nothing of the old scene left at the peak
	tone *= 1.0 - 0.5 * pool;

	if (progress < 0.6) {
		return vec4(mix(old_color, tone, density), 1.0);
	}
	float m2 = blots(p, aspect, seed + 5.3, b);
	float remains = smoothstep(0.96, 1.04, m2);  // 1 where the ink has not cleared yet
	float rim_ink = smoothstep(0.8, 1.0, m2) * (1.0 - remains);  // a dark tide line where it is clearing
	float residue = step(0.8, fibres) * smoothstep(1.3, 1.0, m2) * (1.0 - b);
	float wet = smoothstep(0.45, 1.0, m2) * (1.0 - b);
	// The new scene comes through wet: dark and grey near the ink, its colour returning as it dries.
	vec3 damp = mix(new_color, vec3(luma(new_color)) * 0.75, wet * 0.7);
	float left = clamp(remains + rim_ink * 0.45 + residue * 0.4, 0.0, 1.0) * (1.0 - smoothstep(0.95, 1.0, progress));
	return vec4(mix(damp, tone, left), 1.0);
}

vec4 glitch(vec2 s, vec2 uv, vec2 uv_per_screen, sampler2D tex, vec2 pixel) {
	float amp = pow(max(sin(PI * progress), 0.0), 0.6);  // max: sin(PI) is a hair below 0
	float t = floor(progress * 22.0) + seed * 13.0;  // the picture stutters in steps, not smoothly
	// Torn slices of varying height; only some of them slide.
	float rows = mix(8.0, 40.0, hash(vec2(t, 1.0)));
	float row = floor(s.y * rows);
	float row_hash = hash(vec2(row, t));
	float shift = (row_hash > 0.6 ? hash(vec2(row, t + 7.0)) - 0.5 : 0.0) * 0.3 * amp;
	// Moshed blocks: a few copy their content from elsewhere.
	vec2 grid = vec2(mix(5.0, 18.0, hash(vec2(t, 3.0))), mix(3.0, 11.0, hash(vec2(t, 4.0))));
	vec2 cell = floor(s * grid);
	float cell_hash = hash(cell + t * 1.7);
	vec2 mosh = cell_hash > 0.86 ? (vec2(hash(cell + 11.0), hash(cell + 23.0)) - 0.5) * 0.28 * amp : vec2(0.0);
	float roll = hash(vec2(t, 9.0)) > 0.86 ? (hash(vec2(t, 10.0)) - 0.5) * 0.08 * amp : 0.0;
	vec2 at = s + vec2(shift, roll) + mosh;
	// Which picture: blocks and slices change over as the transition runs, all new at the end.
	float pick = hash(cell * 1.3 + floor(t / 3.0)) * 0.6 + row_hash * 0.4;
	bool fresh = pick < smoothstep(0.1, 0.9, progress);
	float dir = hash(vec2(t, 5.0)) > 0.5 ? 1.0 : -1.0;
	vec2 split = vec2((0.006 + 0.03 * hash(vec2(t, 6.0))) * dir, 0.0) * amp;
	vec3 color;
	if (fresh) {
		color = vec3(texture(screen_tex, at + split).r, texture(screen_tex, at).g, texture(screen_tex, at - split).b);
	} else {
		color = vec3(old_at(at + split, uv, s, uv_per_screen, tex).r, old_at(at, uv, s, uv_per_screen, tex).g,
			old_at(at - split, uv, s, uv_per_screen, tex).b);
	}
	// Signal damage: crushed colour at the worst moments, inverted and tinted blocks, static bands.
	if (amp * hash(vec2(t, 8.0)) > 0.75) {
		color = floor(color * 5.0 + 0.5) / 5.0;
	}
	if (cell_hash > 0.985 && amp > 0.5) {
		color = vec3(1.0) - color;
	} else if (cell_hash > 0.955 && amp > 0.3) {
		color *= hash(cell + 3.0) > 0.5 ? vec3(0.4, 1.15, 1.2) : vec3(1.2, 0.45, 1.15);
	}
	float snow = hash(floor(s / pixel * 0.5) + t);
	color = mix(color, vec3(snow), step(0.97, row_hash) * amp * 0.8);
	// Scanlines every third pixel row, and a faint grain all over.
	color *= 1.0 - 0.2 * amp * step(0.66, fract(s.y / pixel.y / 3.0));
	color += (snow - 0.5) * 0.08 * amp;
	return vec4(color, 1.0);
}

void fragment() {
	vec2 s = SCREEN_UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	// How far the old picture's UV moves per screen width/height (the frame may crop or overhang it).
	vec2 uv_per_screen = vec2(dFdx(UV.x), dFdy(UV.y)) / vec2(dFdx(SCREEN_UV.x), dFdy(SCREEN_UV.y));
	vec3 old_color = texture(TEXTURE, UV).rgb;
	vec3 new_color = texture(screen_tex, s).rgb;
	vec4 result;
	if (style == 2) {
		result = glitch(s, UV, uv_per_screen, TEXTURE, SCREEN_PIXEL_SIZE);
	} else if (style == 1) {
		result = ink_wash(s, aspect, old_color, new_color);
	} else {
		result = brush(s, old_color, new_color);
	}
	COLOR = vec4(result.rgb, 1.0);
}
