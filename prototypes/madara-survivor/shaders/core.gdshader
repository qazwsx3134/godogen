shader_type spatial;
// Chibaku Tensei's core: a black sphere with a violet rim that brightens toward the edge.
render_mode unshaded, cull_back, shadows_disabled;

uniform vec4 core_color : source_color = vec4(0.04, 0.02, 0.07, 1.0);
uniform vec4 rim_color : source_color = vec4(0.72, 0.42, 1.0, 1.0);
uniform float rim_power = 2.4;
uniform float rim_boost = 1.8;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	ALBEDO = mix(core_color.rgb, rim_color.rgb * rim_boost, f);
}
