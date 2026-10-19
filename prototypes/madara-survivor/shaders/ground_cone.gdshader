shader_type spatial;
// The Gunbai swing on the ground: a fan sector that sweeps open from one edge to the other, with a bright leading
// edge, then fades. The mesh is a flat 1x1 plane (XZ) centered on the player; the node's scale sets the radius x2,
// its Y rotation the facing. `progress` 0..1 runs the swing; `half_angle` is half the cone (radians).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.55, 0.35, 1.0);
uniform float half_angle = 1.047;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Plane UV: x right, y toward +Z. The cone points along -Z (the node's forward).
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	if (d > 1.0 || d < 0.12) {
		discard;
	}
	float angle = atan(p.x, -p.y);
	if (abs(angle) > half_angle) {
		discard;
	}
	float sweep = mix(-half_angle, half_angle, smoothstep(0.0, 0.45, progress));
	float behind = sweep - angle;
	if (behind < 0.0) {
		discard;
	}
	float edge = smoothstep(0.5, 0.0, behind) * 0.9;
	float fill = 0.22 * smoothstep(1.0, 0.6, d);
	float rim = smoothstep(0.86, 1.0, d) * 0.6;
	float fade = 1.0 - smoothstep(0.45, 1.0, progress);
	ALBEDO = color.rgb;
	ALPHA = clamp(edge + fill + rim, 0.0, 1.0) * fade * color.a;
}
