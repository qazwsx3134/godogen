// 草：頂點色 R = 高度（根 0、尖 1）。根暗尖亮；根固定、尖端隨移動的 noise 彎。
// 給 MultiMeshInstance3D 用；MultiMesh 開 use_custom_data，INSTANCE_CUSTOM.rgb = 每根草（同 chunk 一樣）的色調。
// 不用 instance uniform：幾百個 chunk 會塞爆全域 instance 參數緩衝（4096）。
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform vec4 root_color : source_color = vec4(0.12, 0.22, 0.07, 1.0);
uniform vec4 tip_color : source_color = vec4(0.55, 0.72, 0.3, 1.0);
uniform sampler2D wind_noise : filter_linear_mipmap, repeat_enable;
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform float wind_speed = 0.08;
uniform float wind_scale = 0.06;
uniform float bend = 0.35;

varying float v_tip;
varying vec3 v_tint;

void vertex() {
	v_tip = COLOR.r;
	v_tint = INSTANCE_CUSTOM.a > 0.0 ? INSTANCE_CUSTOM.rgb : vec3(1.0);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = texture(wind_noise, world.xz * wind_scale + wind_dir * TIME * wind_speed).r;
	float k = v_tip * v_tip * bend * (n * 1.6 - 0.3);  // 平方：根部幾乎不動
	// 在世界方向彎，再換回模型空間（每根草的旋轉不影響風向）
	vec3 off = vec3(wind_dir.x, -0.35, wind_dir.y) * k;
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * off);
}

void fragment() {
	ALBEDO = mix(root_color.rgb, tip_color.rgb, v_tip) * v_tint;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.2, 0.25, 0.08) * v_tip;
}
