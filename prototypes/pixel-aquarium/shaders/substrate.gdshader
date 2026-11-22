shader_type spatial;
render_mode unshaded;

varying float world_depth;

void vertex() {
	world_depth = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

float grain(vec2 cell) {
	return fract(sin(dot(mod(cell, 113.0), vec2(19.728, 84.195))) * 24815.17);
}

void fragment() {
	vec2 cell = floor(UV * vec2(740.0, 620.0));
	float tone = floor(grain(cell) * 4.0) / 3.0;
	float caustic = sin(UV.x * 108.0 + sin(UV.y * 58.0) * 1.3) *
		cos(UV.y * 87.0 + sin(UV.x * 172.0));
	vec3 sand = mix(vec3(0.16, 0.20, 0.19), vec3(0.39, 0.37, 0.27), tone * 0.36);
	sand += step(0.7, caustic) * vec3(0.047, 0.064, 0.045);
	float near_bed = smoothstep(-6.0, -1.9, world_depth);
	ALBEDO = mix(vec3(0.055, 0.207, 0.227), sand, near_bed);
}
