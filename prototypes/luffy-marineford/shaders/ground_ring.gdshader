shader_type spatial;
// A flat ring on the ground: the dash shockwave, danger zones. The mesh is a flat 1x1 plane (XZ); the node's
// scale sets the diameter. `progress` 0..1 fades it when fade_with_progress is 1.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.7, 0.4, 1.0);
uniform float thickness = 0.08;
uniform float fill = 0.0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float fade_with_progress = 1.0;
// Danger warning: a disc fills outward with `progress` until it reaches the ring (then the attack lands).
uniform bool fill_with_progress = false;

void fragment() {
	float d = length((UV - 0.5) * 2.0);
	if (d > 1.0) {
		discard;
	}
	float ring = smoothstep(1.0 - thickness * 2.0, 1.0 - thickness, d) * smoothstep(1.0, 1.0 - thickness * 0.5, d);
	float a = max(ring, fill * smoothstep(1.0, 0.0, d));
	if (fill_with_progress) {
		a = max(ring, step(d, progress) * 0.45);
	} else {
		a *= 1.0 - progress * fade_with_progress;
	}
	ALBEDO = color.rgb;
	ALPHA = a * color.a;
}
