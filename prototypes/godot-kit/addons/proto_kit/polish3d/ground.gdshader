// 地面：兩種綠用 noise 混，mask 貼圖 R = 踩禿的泥土，G = 樹下（暗、偏乾）。mask 用地面網格的 UV。
shader_type spatial;

uniform vec4 green_a : source_color = vec4(0.25, 0.42, 0.14, 1.0);
uniform vec4 green_b : source_color = vec4(0.36, 0.5, 0.18, 1.0);
uniform vec4 dirt : source_color = vec4(0.42, 0.33, 0.22, 1.0);
uniform vec4 under_tree : source_color = vec4(0.2, 0.26, 0.12, 1.0);
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D mask : filter_linear, hint_default_black;
uniform float noise_scale = 0.08;

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = texture(noise, world.xz * noise_scale).r;
	float fine = texture(noise, world.xz * noise_scale * 7.0).r;
	vec3 col = mix(green_a.rgb, green_b.rgb, smoothstep(0.3, 0.7, n));
	vec4 m = texture(mask, UV);
	col = mix(col, under_tree.rgb, m.g);
	col = mix(col, dirt.rgb * mix(0.85, 1.1, fine), smoothstep(0.2, 0.8, m.r + (fine - 0.5) * 0.3));
	ALBEDO = col * mix(0.92, 1.05, fine);
	ROUGHNESS = 0.95;
}
