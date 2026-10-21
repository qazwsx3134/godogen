// A pixel shockwave on the ground (impact_fx.gd ring()): a flash disc at the very start, then a ring that races out
// and thins, and in its last 40% breaks into pieces instead of fading (pixel-vfx rule: hard edges, no alpha fades).
// Snapped to `texels` cells across the quad so it shares the sprites' pixel grid; 4 shades plus a dark outline.
// Per ring: instance uniforms (one shared material for the pool). The material's render_priority is below the zone
// tiles', so a red telegraph always draws over a ring.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

instance uniform float progress = 1.0;
instance uniform vec4 col_dark : source_color = vec4(0.35, 0.32, 0.3, 1.0);
instance uniform vec4 col_mid : source_color = vec4(0.55, 0.5, 0.45, 1.0);
instance uniform vec4 col_light : source_color = vec4(0.75, 0.7, 0.62, 1.0);
instance uniform vec4 col_white : source_color = vec4(0.95, 0.93, 0.88, 1.0);
// Pixel cells across the quad's diameter (set from the ring's size so one cell = one sprite texel).
instance uniform float texels = 64.0;
uniform vec4 outline : source_color = vec4(0.08, 0.06, 0.1, 1.0);

float cell_hash(vec2 c) {
	return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * texels);
	vec2 g = (cell + 0.5) / texels * 2.0 - 1.0;
	float r = length(g);
	float p = clamp(progress, 0.0, 1.0);
	float px = 2.0 / texels;
	vec4 c = vec4(0.0);
	// Impact flash: a filled disc for the first frames.
	if (p < 0.12 && r < 0.35 * (1.0 - p / 0.12) + 0.1) {
		c = r < 0.18 ? col_white : col_light;
	}
	float radius = (1.0 - pow(1.0 - p, 3.0)) * 0.92;
	float width = mix(0.11, 0.03, p) + px;
	float d = abs(r - radius);
	if (d < width) {
		float t = d / width;
		c = t < 0.3 ? (p < 0.3 ? col_white : col_light) : (t < 0.65 ? col_mid : col_dark);
	} else if (d < width + px) {
		c = outline;
	}
	// Break apart in chunks of 3 x 3 cells.
	if (c.a > 0.0 && p > 0.6 && cell_hash(floor(cell / 3.0)) < (p - 0.6) / 0.4) {
		c = vec4(0.0);
	}
	if (c.a <= 0.0) {
		discard;
	}
	ALBEDO = c.rgb;
	ALPHA = 1.0;
}
