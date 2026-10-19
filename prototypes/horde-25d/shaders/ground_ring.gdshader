shader_type spatial;
// A flat pixel ring on the ground: the aura's reach, a nova wave, a danger zone.
// The mesh is a flat 1x1 plane (XZ); the node's scale sets the diameter. `progress` 0..1 drives a nova.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform float pixels = 48.0;
uniform float thickness = 0.08;
uniform float fill = 0.12;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float fade_with_progress = 0.0;

void fragment() {
	vec2 p = (floor(UV * pixels) + 0.5) / pixels * 2.0 - 1.0;
	float d = length(p);
	if (d > 1.0) {
		discard;
	}
	float ring = d > 1.0 - thickness ? 1.0 : 0.0;
	// Inner fill pulses outward in pixel bands.
	float bands = step(0.5, fract(d * 4.0 - TIME * 1.5));
	float a = max(ring, fill * bands);
	a *= 1.0 - progress * fade_with_progress;
	if (a <= 0.0) {
		discard;
	}
	ALBEDO = color.rgb;
	ALPHA = a * color.a;
}
