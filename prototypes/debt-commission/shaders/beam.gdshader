shader_type canvas_item;
uniform float pulse_speed = 5.0;
uniform float edge_softness : hint_range(0.01, 0.4) = 0.12;
void fragment() {
	float center = 0.5 + 0.012 * sin(UV.x * 18.0 - TIME * pulse_speed);
	float width = mix(0.12, 0.40, smoothstep(0.0, 0.42, UV.x));
	float envelope = 1.0 - smoothstep(width - edge_softness, width, abs(UV.y - center));
	float origin = smoothstep(0.0, 0.06, UV.x);
	COLOR.a *= envelope * origin;
}
