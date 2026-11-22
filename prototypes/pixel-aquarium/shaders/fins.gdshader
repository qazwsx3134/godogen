shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 root_color : source_color = vec4(0.32, 0.18, 0.4, 1.0);
uniform vec4 main_color : source_color = vec4(0.81, 0.29, 0.35, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.65, 0.44, 1.0);

void fragment() {
	vec2 pixel = floor(UV * vec2(32.0, 24.0)) / vec2(32.0, 24.0);
	float rib = step(0.66, fract(pixel.y * 11.0 + pixel.x * 0.3));
	vec3 color = mix(root_color.rgb, main_color.rgb, smoothstep(0.1, 0.86, pixel.x));
	color *= mix(0.73, 1.06, rib);
	if (pixel.x > 0.79 + 0.08 * sin(pixel.y * 19.0)) {
		color = mix(color, edge_color.rgb, 0.52 + 0.27 * rib);
	}
	ALBEDO = color;
}
