shader_type canvas_item;
// Shared by every enemy sprite. A modulate above 1 on all three channels turns the sprite white instead of
// brighter: Color(2, 2, 2) is a full white flash. Ordinary tints (each channel 1 or below) pass through.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float flash = clamp(min(tint.r, min(tint.g, tint.b)) - 1.0, 0.0, 1.0);
	COLOR = vec4(mix(tex.rgb * min(tint.rgb, vec3(1.0)), vec3(1.0), flash), tex.a * tint.a);
}
