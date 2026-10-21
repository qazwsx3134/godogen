// A mark on the ground, drawn on the stage's pixel grid: a circle (shape 0) or a rectangle (shape 1) filling its
// quad, with a solid rim. Telegraphs fill from the centre outward as the countdown runs (fill 0 -> 1, pulsing);
// flag rings are rim only. Per-mark values are instance uniforms, so every mark shares one material. Flat, unshaded,
// outside the fog and under the heroes, so a warning reads the same at every distance.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

instance uniform float shape = 0.0;
instance uniform vec4 color : source_color = vec4(1.0, 0.18, 0.12, 1.0);
// How far the filled area reaches, 0..1 of the way to the rim.
instance uniform float fill = 0.0;
instance uniform float fill_alpha = 0.5;
instance uniform float inner_alpha = 0.1;
instance uniform float pulse = 0.0;
// Texels across the quad (x, z), so the edges land on the pixel grid whatever the mark's size.
instance uniform vec2 texels = vec2(40.0, 40.0);
uniform float rim_texels = 2.0;

void fragment() {
	vec2 q = (floor(UV * texels) + 0.5) / texels;
	vec2 p = abs(q - 0.5) * 2.0;
	float d = shape < 0.5 ? length(p) : max(p.x, p.y);
	if (d > 1.0) {
		discard;
	}
	// Distance to the rim in texels (along the nearer axis for rectangles).
	vec2 rim_d = (1.0 - p) * texels * 0.5;
	float to_rim = shape < 0.5 ? (1.0 - d) * min(texels.x, texels.y) * 0.5 : min(rim_d.x, rim_d.y);
	float a = inner_alpha;
	if (d < fill) {
		a = fill_alpha * (0.8 + 0.2 * pulse);
	}
	if (to_rim < rim_texels) {
		a = 1.0;
	}
	ALBEDO = color.rgb;
	ALPHA = a * color.a;
}
