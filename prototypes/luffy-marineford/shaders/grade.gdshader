shader_type canvas_item;
// Screen grade after the 3D (and its outline and glow), before the HUD: tint, pokebonk.com's ToonGrade (cool darks,
// warm lights, extra contrast) and a vignette. A full-screen ColorRect on a CanvasLayer under the HUD reads the
// rendered frame through the screen texture, so the 3D stays in the main viewport.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform vec4 tint : source_color = vec4(0.96, 0.99, 1.04, 1.0);
uniform vec4 shadow_tone : source_color = vec4(0.82, 0.9, 1.1, 1.0);
uniform vec4 light_tone : source_color = vec4(1.06, 1.01, 0.94, 1.0);
uniform float contrast = 0.22;
uniform float vignette_strength = 0.4;
uniform float vignette_size = 0.4;

void fragment() {
	vec3 c = textureLod(screen, SCREEN_UV, 0.0).rgb * tint.rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c *= mix(shadow_tone.rgb, light_tone.rgb, smoothstep(0.15, 0.85, luma));
	c = (c - 0.5) * (1.0 + contrast) + 0.5;
	vec2 d = SCREEN_UV - 0.5;
	float v = smoothstep(vignette_size, vignette_size + 0.6, length(d * vec2(1.0, 0.8)) * 1.4);
	c *= 1.0 - v * vignette_strength;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
