// Screen vignette and grade over the 3D view, under the HUD: darker cool corners, a faint warm wash from the top
// (the low sun), so the eye lands on the middle of the field.
shader_type canvas_item;

uniform vec4 corner_color : source_color = vec4(0.08, 0.06, 0.16, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.55;
// Inner radius (fraction of the half diagonal) where darkening starts, and how soft it is.
uniform float radius = 0.55;
uniform float softness = 0.55;
uniform vec4 sun_wash : source_color = vec4(1.0, 0.72, 0.45, 1.0);
uniform float sun_wash_strength : hint_range(0.0, 1.0) = 0.12;

void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.0, 1.25);
	float d = length(p) / 0.707;
	float v = smoothstep(radius, radius + softness, d) * strength;
	float wash = (1.0 - UV.y) * (1.0 - UV.y) * sun_wash_strength;
	COLOR = vec4(mix(corner_color.rgb, sun_wash.rgb, wash / max(v + wash, 0.0001)), clamp(v + wash, 0.0, 1.0));
}
