// A 區 (zone) on the ground: faint fill and border; white border when selected or hovered; a red fill that grows
// from the centre over the telegraph (warn 0 -> 1) with a solid red rim. Flat, unshaded, drawn under the heroes.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 0.1);
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.45);
uniform float border = 0.05;
uniform float highlight = 0.0;
uniform vec4 warn_color : source_color = vec4(1.0, 0.18, 0.12, 0.55);
// 0 = no telegraph; otherwise how far the countdown has run, 0..1.
uniform float warn = 0.0;
uniform float pulse = 0.0;

void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float edge = max(d.x, d.y);
	vec4 c = fill_color;
	vec4 rim = mix(border_color, vec4(1.0, 1.0, 1.0, 0.95), highlight);
	if (edge > 1.0 - border * (1.0 + highlight)) {
		c = rim;
	}
	if (warn > 0.0) {
		if (edge < warn) {
			c = vec4(warn_color.rgb, warn_color.a * (0.75 + 0.25 * pulse));
		}
		if (edge > 1.0 - border * 1.6) {
			c = vec4(warn_color.rgb, 1.0);
		}
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
