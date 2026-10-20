shader_type spatial;
// Dust, debris and smoke: the fx_glow shapes, alpha-blended instead of added, so they read on bright sand.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/fx_shapes.gdshaderinc"
