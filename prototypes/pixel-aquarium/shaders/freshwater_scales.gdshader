shader_type spatial;
render_mode unshaded;

uniform int pattern : hint_enum("Cardinal", "Discus", "Pale chub male", "Pale chub female") = 0;
uniform vec4 base_color : source_color = vec4(0.35, 0.54, 0.55, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.28, 0.94, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.97, 0.19, 0.24, 1.0);

vec3 cardinal(vec2 pixel) {
	vec3 body = mix(base_color.rgb * 0.58, base_color.rgb, smoothstep(0.23, 0.48, pixel.y));
	if (pixel.x > 0.05 && pixel.x < 0.88) {
		float curve = 0.45 - 0.05 * sin(pixel.x * 3.1);
		if (pixel.y > curve && pixel.y < curve + 0.125) {
			body = mix(stripe_color.rgb, vec3(0.87, 1.0, 1.0), 0.24 * step(pixel.y, curve + 0.05));
		} else if (pixel.y > curve + 0.125 && pixel.y < 0.83) {
			body = accent_color.rgb * (1.02 - (pixel.y - 0.55) * 0.7);
		}
	}
	return body;
}

vec3 discus(vec2 pixel) {
	float bend = 0.9 * sin(pixel.x * 8.0) + 0.6 * sin(pixel.x * 16.0 + pixel.y * 5.0);
	float stripe = sin(pixel.y * 56.0 + bend);
	float runs = smoothstep(0.35, 0.8, stripe);
	float band = sin(pixel.x * 41.0 + (pixel.y - 0.48) * (pixel.y - 0.48) * 7.0);
	vec3 plate = mix(base_color.rgb, accent_color.rgb, smoothstep(0.1, 0.69, pixel.x) * 0.56);
	plate *= 1.0 - smoothstep(0.83, 1.0, band) * 0.21;
	return mix(plate, stripe_color.rgb, runs * 0.86);
}

vec3 chub(vec2 pixel) {
	vec3 top = base_color.rgb * 0.57;
	vec3 flank = mix(top, base_color.rgb, smoothstep(0.11, 0.54, pixel.y));
	if (pattern == 2) {
		float band = sin(pixel.x * 42.0 + sin(pixel.y * 5.0) * 0.87);
		float spot = smoothstep(0.37, 0.77, band) * smoothstep(0.17, 0.37, pixel.y);
		flank = mix(flank, accent_color.rgb, smoothstep(0.43, 0.77, pixel.y) * 0.77);
		return mix(flank, stripe_color.rgb, spot * (1.0 - smoothstep(0.68, 0.84, pixel.y)));
	}
	float lateral = abs(pixel.y - (0.5 - 0.035 * sin(pixel.x * 8.0)));
	flank = mix(flank, stripe_color.rgb, (1.0 - smoothstep(0.035, 0.09, lateral)) * 0.67);
	return mix(flank, accent_color.rgb, smoothstep(0.65, 0.88, pixel.y) * 0.46);
}

#include "res://shaders/swim_bend.gdshaderinc"

void vertex() {
	bend_swimming_body(VERTEX, NORMAL);
}

void fragment() {
	vec2 cell = floor(UV * vec2(60.0, 42.0));
	vec2 pixel = cell / vec2(60.0, 42.0);
	vec3 color = pattern == 0 ? cardinal(pixel) : (pattern == 1 ? discus(pixel) : chub(pixel));
	float glint = step(0.78, fract(sin(dot(cell, vec2(23.9, 71.7))) * 13215.5));
	float face = dot(NORMAL, normalize(vec3(-0.26, 0.68, 0.8)));
	float facet = floor(clamp(face * 0.66 + 0.35, 0.0, 1.0) * 5.0) / 5.0;
	ALBEDO = color * (0.67 + 0.33 * facet + 0.09 * glint);
}
