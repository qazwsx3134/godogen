shader_type canvas_item;

void fragment() {
	float distance_from_center = length(UV - vec2(0.5));
	float halo = 1.0 - smoothstep(0.12, 0.5, distance_from_center);
	float core = 1.0 - smoothstep(0.02, 0.18, distance_from_center);
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), core);
	COLOR.a *= halo;
}
