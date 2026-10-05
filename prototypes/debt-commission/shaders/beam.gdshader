shader_type canvas_item;
uniform float pulse_speed = 14.0;
uniform float edge_softness : hint_range(0.01, 0.4) = 0.12;
void fragment() {
	float center = 0.5 + 0.04 * sin(UV.x * 32.0 - TIME * pulse_speed);
	float width = 0.38 + 0.06 * sin(UV.x * 55.0 + TIME * 9.0);
	float envelope = 1.0 - smoothstep(width - edge_softness, width, abs(UV.y - center));
	float streak = 0.72 + 0.28 * sin(UV.x * 80.0 - TIME * pulse_speed);
	COLOR.a *= envelope * streak;
}
