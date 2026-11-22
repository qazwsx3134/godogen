shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 0.05) = 0.0;

void fragment() {
	vec2 ray = SCREEN_UV - vec2(0.5);
	vec4 original = texture(screen_texture, SCREEN_UV);
	vec4 sum = original;
	for (int i = 1; i <= 4; i++) {
		sum += texture(screen_texture, clamp(SCREEN_UV - ray * strength * float(i) * 0.25, vec2(0.0), vec2(1.0)));
	}
	float edge = smoothstep(0.15, 0.54, length(ray));
	COLOR = mix(original, sum / 5.0, edge);
}
