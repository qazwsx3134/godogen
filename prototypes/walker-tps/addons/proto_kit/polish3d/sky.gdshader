// 天空：上下漸層＋太陽圓盤（取第一盞 DirectionalLight）＋ noise 雲。也當環境光來源。
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.33, 0.55, 0.85);
uniform vec3 horizon_color : source_color = vec3(0.78, 0.84, 0.9);
uniform vec3 ground_color : source_color = vec3(0.35, 0.36, 0.33);
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_speed = 0.004;
uniform float sun_size = 0.02;

void sky() {
	float y = EYEDIR.y;
	vec3 col = y > 0.0 ? mix(horizon_color, top_color, pow(y, 0.5)) : mix(horizon_color, ground_color, pow(-y, 0.4));
	if (LIGHT0_ENABLED) {
		float d = distance(EYEDIR, LIGHT0_DIRECTION);
		col += LIGHT0_COLOR * LIGHT0_ENERGY * (smoothstep(sun_size, sun_size * 0.6, d) * 4.0 + exp(-d * 6.0) * 0.25);
	}
	if (y > 0.0) {
		vec2 uv = EYEDIR.xz / (y + 0.15) * 0.25 + TIME * cloud_speed;
		float c = texture(cloud_noise, uv).r * 0.65 + texture(cloud_noise, uv * 2.7).r * 0.35;
		c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.3, c) * smoothstep(0.0, 0.2, y);
		col = mix(col, vec3(1.0, 0.98, 0.95), c * 0.85);
	}
	COLOR = col;
}
