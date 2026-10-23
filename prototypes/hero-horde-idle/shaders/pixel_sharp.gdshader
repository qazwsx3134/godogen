// Pixel art drawn at a non-integer scale (the UI is 720 wide, an iPhone 15 is 1179: x1.64) with even-width pixels:
// "sharp bilinear". Nearest sampling makes art pixels alternately 3 and 4 screen pixels wide, which shimmers when a
// list scrolls; plain bilinear blurs them. This blends neighbouring texels only across the one screen pixel where
// they meet. It does the filtering itself from four texel-centre samples, so the node keeps the project's nearest
// filter (and a node that sets its own material, like the hero portraits, is untouched). Premultiplied, so a frame's
// transparent edge does not fringe dark. scripts/pixel_ui.gd puts it on the UI's framed and textured nodes.
shader_type canvas_item;

// The vertex colour with modulate: in fragment() COLOR already holds the texture's colour multiplied in.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 texel = UV * size - 0.5;
	vec2 base = floor(texel);
	vec2 f = texel - base;
	// Texels per screen pixel: the blend band is one screen pixel wide whatever the scale.
	vec2 band = max(fwidth(texel), vec2(1e-4));
	f = clamp((f - 0.5) / band + 0.5, 0.0, 1.0);
	vec2 step = 1.0 / size;
	vec2 at = (base + 0.5) * step;
	vec4 a = texture(TEXTURE, at);
	vec4 b = texture(TEXTURE, at + vec2(step.x, 0.0));
	vec4 c = texture(TEXTURE, at + vec2(0.0, step.y));
	vec4 d = texture(TEXTURE, at + step);
	a.rgb *= a.a;
	b.rgb *= b.a;
	c.rgb *= c.a;
	d.rgb *= d.a;
	vec4 m = mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
	m.rgb /= max(m.a, 1e-4);
	COLOR = m * tint;
}
