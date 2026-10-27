// A pixel shockwave on the ground (impact_fx.gd ring()): a flash disc at the very start, then a ring that races out
// and thins, and in its last 40% breaks into pieces instead of fading (pixel-vfx rule: hard edges, no alpha fades).
// Snapped to `texels` cells across the quad so it shares the sprites' pixel grid; 4 shades plus a dark outline.
// Per ring: instance uniforms (one shared material for the pool). The material's render_priority is below the zone
// tiles', so a red telegraph always draws over a ring. The shader is godot-kit pixel_vfx3d_ring.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://addons/proto_kit/pixel_vfx3d_ring.gdshaderinc"
