shader_type spatial;
render_mode unshaded;

uniform sampler2D scales : source_color, filter_nearest, repeat_disable;
uniform sampler2D silver_mask : filter_nearest, repeat_disable;
uniform bool silver = false;

instance uniform float silver_strength = 1.0;

#include "res://shaders/swim_bend.gdshaderinc"

void vertex() {
	bend_swimming_body(VERTEX, NORMAL);
}

void fragment() {
	float light = dot(NORMAL, normalize(vec3(-0.26, 0.68, 0.8)));
	float shade = 0.66 + 0.34 * floor(clamp(light * 0.65 + 0.35, 0.0, 1.0) * 4.0) / 4.0;
	vec3 base = texture(scales, UV).rgb * shade;
	if (silver) {
		float mask = texture(silver_mask, UV).r;
		float flash = smoothstep(0.87, 0.98, dot(NORMAL, normalize(vec3(0.6, 0.24, 0.77))));
		base = mix(base, vec3(0.54, 0.89, 0.89) + 0.29 * flash, mask * silver_strength);
	}
	ALBEDO = base;
}
