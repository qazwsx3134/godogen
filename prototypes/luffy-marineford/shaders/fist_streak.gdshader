shader_type spatial;
// Gomu Gomu Pistol's afterimage: a stretched arm ending in a fist, see-through and fading, drawn in hard pixel steps.
// A transparent effect on purpose: it lands after the depth outline (which reads only the opaque pass), so it proves
// the outline does not paint over effects. The quad runs along UV.x from the shoulder (0) to the fist (1).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 skin : source_color = vec4(1.0, 0.8, 0.62, 1.0);
uniform vec4 edge : source_color = vec4(0.25, 0.12, 0.1, 1.0);
uniform vec4 speed : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// 0 just thrown -> 1 gone.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Texels along the arm and across it (the quad's world size at the game's pixel density).
uniform vec2 texels = vec2(140.0, 16.0);
uniform float opacity = 0.75;

void fragment() {
	vec2 uv = (floor(UV * texels) + 0.5) / texels;
	float across = abs(uv.y - 0.5) * 2.0;
	// The fist (radius 0.36 of the quad's width, rim to 0.46, inside the half width 0.5) sits so its rim plus one
	// texel ends at the quad's tip, whatever the arm's length: the end is never clipped flat.
	float aspect = texels.y / texels.x;
	float fist_x = 1.0 - 0.46 * aspect - 1.0 / texels.x;
	// Arm: thin near the shoulder, thicker toward the fist; the fist is a blob at the end.
	float arm = step(across, mix(0.25, 0.45, uv.x)) * step(uv.x, fist_x);
	vec2 fist_d = (uv - vec2(fist_x, 0.5)) * vec2(1.0 / aspect, 1.0);
	float fist = step(length(fist_d), 0.36);
	float body = max(arm, fist);
	float rim = max(step(across, mix(0.25, 0.45, uv.x) + 0.18) * step(uv.x, fist_x), step(length(fist_d), 0.46)) - body;
	// Speed lines trail behind the fist and fade first.
	float lines = step(0.94, fract(uv.y * 5.0 + 0.3)) * step(0.15, uv.x) * step(uv.x, 0.8) * (1.0 - step(0.4, progress));
	float fade = 1.0 - progress;
	// The arm retracts from the shoulder as it fades.
	float shown = step(progress * 0.8, uv.x);
	vec3 color = body > 0.5 ? skin.rgb : (rim > 0.5 ? edge.rgb : speed.rgb);
	float a = max(max(body, rim) * shown, lines * 0.6) * opacity * fade;
	ALBEDO = color;
	ALPHA = floor(a * 4.0 + 0.5) / 4.0;
}
