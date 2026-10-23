// A battle sprite in the UI (hero cards, the hero page): the pixel art tinted by the node's modulate (the hero's own
// tint, scripts/army.gd tint()), with the one-texel rarity outline the push draws around it (N/R dark, SR purple,
// SSR gold; one material per outline colour). Hard alpha, like the push.
shader_type canvas_item;

uniform vec4 outline : source_color = vec4(0.05, 0.05, 0.08, 1.0);
// The push lights its sprites with a warm key on top of their tint; the UI has no lights, so this stands in.
uniform float light = 1.15;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a >= 0.5) {
		COLOR = vec4(min(c.rgb * COLOR.rgb * light, vec3(1.0)), 1.0);
	} else {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		if (n < 0.5) {
			discard;
		}
		COLOR = outline;
	}
}
