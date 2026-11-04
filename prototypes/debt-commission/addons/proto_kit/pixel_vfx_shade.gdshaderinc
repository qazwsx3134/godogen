// Second half of a PixelVfx shader effect, included after the effect's density() and heat(): the colour of
// the art pixel that `uv` falls in: a fill tone inside, tone_0 on the one-pixel rim outside, else transparent.
vec4 pv_shade(vec2 uv) {
	vec2 p = pv_p(pv_cell(uv));
	if (density(p) >= 0.5) {
		return pv_tone(heat(p));
	}
	if (outline) {
		float s = pv_px();
		if (max(max(density(p + vec2(s, 0.0)), density(p - vec2(s, 0.0))), max(density(p + vec2(0.0, s)), density(p - vec2(0.0, s)))) >= 0.5) {
			return tone_0;
		}
	}
	return vec4(0.0);
}
