// A mark on the ground, drawn on the stage's pixel grid: a circle (shape 0) or a rectangle (shape 1) filling its
// quad, with a solid rim and a dark one-texel outline outside it (it reads on any floor). Telegraphs (inner_alpha >
// 0) are hatched with diagonal stripes, so they read by pattern as well as colour, and fill from the centre outward
// as the countdown runs (fill 0 -> 1, pulsing) behind a bright front line; flag rings are rim only. Per-mark values are instance uniforms, so every mark shares one material. Flat, unshaded,
// outside the fog and under the heroes, so a warning reads the same at every distance.
// The shader is godot-kit ground_decal.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://addons/proto_kit/ground_decal.gdshaderinc"
