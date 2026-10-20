shader_type spatial;
// Glowing effects in one MultiMesh: chakra sparks, impact flashes, swing glints.
// Each instance: transform (position, size), COLOR (tint), INSTANCE_CUSTOM.x = shape, .y = progress 0..1.
// The same shader with blend_mix (fx_dust.gdshader) draws dust and debris.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/fx_shapes.gdshaderinc"
