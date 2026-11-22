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
uniform float charge : hint_range(0.0, 1.0) = 0.0;

varying float seed;

void vertex() {
	seed = INSTANCE_CUSTOM.x;
	float bend = UV.y * UV.y;
	VERTEX.x += sin(TIME * 1.7 + seed * 6.28 + UV.y * 2.5) * sway * bend;
	VERTEX.z += cos(TIME * 1.3 + seed * 4.1 + UV.y * 2.0) * sway * 0.6 * bend;
}

void fragment() {
	vec4 t = texture(fiber_tex, UV);
	float pulse = 0.5 + 0.5 * sin(UV.y * 18.0 - TIME * flow_speed * 18.0 + seed * 9.0);
	float gather = 0.5 + 0.5 * sin(UV.y * 19.0 + TIME * flow_speed * 27.0);
	vec3 base = mix(color.rgb, vec3(1.0, 0.34, 0.08), charge);
	vec3 core = mix(core_color.rgb, vec3(1.0, 0.89, 0.56), charge);
	float wave = mix(pulse, gather, charge);
	ALBEDO = mix(base, core, clamp(t.r * 0.45 + wave * 0.3, 0.0, 1.0));
	ALPHA = t.a * opacity * (0.75 + 0.25 * wave) * smoothstep(0.0, 0.06, UV.y);
}
