// Recolour the blue tiles of the Kenney palette while retaining the roof trim.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D palette : source_color, filter_nearest_mipmap;
uniform vec4 tile_color : source_color = vec4(0.62, 0.23, 0.14, 1.0);

void fragment() {
	vec3 base = texture(palette, UV).rgb;
	float is_tile = smoothstep(0.02, 0.14, base.b - base.r) * smoothstep(-0.02, 0.08, base.b - base.g);
	ALBEDO = mix(base * 0.38, tile_color.rgb * (0.70 + 0.5 * base.b), is_tile);
	ROUGHNESS = 0.95;
}
