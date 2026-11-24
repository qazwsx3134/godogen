// A mark on the ground of an HD-2D diorama, drawn on the stage's pixel grid: a circle (shape 0) or a rectangle
// (shape 1) filling its quad (a 1 x 1 PlaneMesh; the node's scale sets the size), with a solid rim and a dark
// one-texel outline outside it so it reads on any floor. Warnings (inner_alpha > 0) are hatched with diagonal stripes,
// so they read by pattern as well as colour, and fill from the centre outward as a countdown runs (fill 0 -> 1, with
// pulse) behind a bright front line; rings for selection or squads are rim only (inner_alpha 0). Per-mark values are
// instance uniforms, so every mark shares one material; set `texels` to the quad's size / metres per texel so edges
// land on the pixel grid. Flat, unshaded, outside the fog and under the characters, so a warning reads the same at
// every distance. Included by ground_decal.gdshader, which sets the render mode.
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
uniform float stripe_texels = 6.0;
uniform float stripe_alpha = 0.18;
uniform vec4 outline_color : source_color = vec4(0.08, 0.03, 0.02, 1.0);

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
	vec3 rgb = color.rgb;
	float a = inner_alpha;
	if (inner_alpha > 0.0) {
		vec2 cell = floor(q * texels);
		if (mod(cell.x + cell.y, stripe_texels) < 2.0) {
			a += stripe_alpha;
		}
	}
	if (d < fill) {
		a = fill_alpha * (0.8 + 0.2 * pulse);
		// The countdown's front: one bright texel ring just inside where the fill has reached.
		float texel_d = 2.0 / min(texels.x, texels.y);
		if (fill < 0.98 && d > fill - texel_d * 1.5) {
			rgb = mix(color.rgb, vec3(1.0, 0.92, 0.75), 0.6);
			a = 1.0;
		}
	}
	if (to_rim < rim_texels + 1.0) {
		a = 1.0;
		rgb = to_rim < 1.0 ? outline_color.rgb : mix(color.rgb, vec3(1.0), 0.15 * pulse);
	}
	ALBEDO = rgb;
	ALPHA = a * color.a;
}
