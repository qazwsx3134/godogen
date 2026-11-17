shader_type spatial;
// Optical-fibre strands for the Boss's second-form wings and fibre attacks.
// Crossed planes along +Y (UV.y = 0 root .. 1 tip) with a strand texture; light flows
// toward the tip and the strand sways more toward its tip. Unshaded, alpha-blended
// (additive vanishes against the pale sky without glow). INSTANCE_CUSTOM.x de-syncs
// MultiMesh instances; plain MeshInstance3D strands use 0.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform sampler2D fiber_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 color : source_color = vec4(0.2, 0.85, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.7, 1.0, 1.0, 1.0);
uniform float opacity = 1.0;
uniform float sway = 0.6;
uniform float flow_speed = 1.6;

varying float seed;

void vertex() {
	seed = INSTANCE_CUSTOM.x;
	float bend = UV.y * UV.y;
	VERTEX.x += sin(TIME * 1.7 + seed * 6.28 + UV.y * 2.5) * sway * bend;
	VERTEX.z += cos(TIME * 1.3 + seed * 4.1 + UV.y * 2.0) * sway * 0.6 * bend;
}

void fragment() {
	vec4 t = texture(fiber_tex, UV);
	float pulse = 0.5 + 0.5 * sin((UV.y - TIME * flow_speed) * 18.0 + seed * 9.0);
	ALBEDO = mix(color.rgb, core_color.rgb, clamp(t.r * 0.45 + pulse * 0.3, 0.0, 1.0));
	ALPHA = t.a * opacity * (0.75 + 0.25 * pulse) * smoothstep(0.0, 0.06, UV.y);
}
