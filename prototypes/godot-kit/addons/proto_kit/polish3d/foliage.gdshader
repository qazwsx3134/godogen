// 樹葉：法線改成「從樹冠中心往外」，整團葉子像一顆被光照的球，不會一片一片亂亮；加輕微搖擺。
// canopy_center 是模型空間的樹冠中心。葉片用 alpha 貼圖時設 leaf_texture，否則純色。
shader_type spatial;
render_mode cull_disabled;

uniform vec3 canopy_center = vec3(0.0, 2.0, 0.0);
uniform vec4 leaf_color : source_color = vec4(0.32, 0.5, 0.2, 1.0);
uniform sampler2D leaf_texture : source_color, filter_linear_mipmap, hint_default_white;
uniform float alpha_cut = 0.4;
uniform float sway_amount = 0.06;
uniform float sway_speed = 1.3;

void vertex() {
	NORMAL = normalize(VERTEX - canopy_center);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(VERTEX.y - canopy_center.y * 0.5, 0.0);  // 越高擺越多，樹幹附近不動
	float t = TIME * sway_speed + world.x * 0.35 + world.z * 0.27;
	VERTEX.x += sin(t) * sway_amount * h;
	VERTEX.z += cos(t * 0.83) * sway_amount * 0.6 * h;
}

void fragment() {
	vec4 tex = texture(leaf_texture, UV);
	ALBEDO = leaf_color.rgb * tex.rgb * mix(0.85, 1.1, COLOR.r);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.85;
	BACKLIGHT = vec3(0.25, 0.3, 0.1);  // 逆光時葉子透一點黃綠
}
