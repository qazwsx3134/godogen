shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

void fragment() {
	vec2 uv = (UV - 0.5) * vec2(2.1, 2.1) + vec2(0.5, 0.53);
	vec2 pixel = floor(uv * vec2(560.0, 245.0)) / vec2(560.0, 245.0);
	float glow = max(0.0, 1.0 - length((pixel - vec2(0.46, 0.0)) * vec2(1.55, 0.95)));
	float beam = pow(max(0.0, sin((pixel.x * 1.9 - pixel.y * 0.47) * 18.0)), 3.0);
	float depth = floor((glow * 0.91 + beam * clamp(1.0 - pixel.y, 0.0, 1.0) * 0.19) * 24.0) / 24.0;
	ALBEDO = mix(vec3(0.025, 0.14, 0.17), vec3(0.16, 0.44, 0.43), depth);
}
