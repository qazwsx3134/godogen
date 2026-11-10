shader_type spatial;
// World-space grid so speed and turning read at a glance. Lines every `cell` m, bold ones every 5 cells.

uniform vec3 base_color : source_color = vec3(0.25, 0.24, 0.21);
uniform vec3 line_color : source_color = vec3(0.36, 0.34, 0.29);
uniform float cell = 2.0;
uniform float line_width = 0.04;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid(vec2 p, float size, float width) {
	vec2 d = abs(fract(p / size - 0.5) - 0.5) * size;  // metres to the nearest line
	float aa = length(fwidth(p)) + 0.001;
	return 1.0 - smoothstep(width, width + aa, min(d.x, d.y));
}

void fragment() {
	float minor = grid(world_pos.xz, cell, line_width) * 0.55;
	float major = grid(world_pos.xz, cell * 5.0, line_width * 2.0);
	ALBEDO = mix(base_color, line_color, max(minor, major));
	ROUGHNESS = 0.95;
}
