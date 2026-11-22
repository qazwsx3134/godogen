// 後製：暗角＋底片顆粒。放在 CanvasLayer 裡全螢幕的 ColorRect 上，mouse_filter = IGNORE。
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float vignette = 0.3;
uniform float grain = 0.014;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * smoothstep(0.2, 0.8, dot(d, d) * 2.0);
	float g = fract(sin(dot(SCREEN_UV * 1000.0 + fract(TIME) * 37.0, vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(c + (g - 0.5) * grain * 2.0, 1.0);
}
