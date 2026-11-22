instance uniform float swim_curve = 0.0;
instance uniform float tail_mount = -0.36;

void bend_swimming_body(inout vec3 vertex, inout vec3 normal) {
	float span = 0.14 - tail_mount;
	float weight = clamp((0.14 - vertex.x) / span, 0.0, 1.0);
	vertex.z += swim_curve * weight * weight;
	normal.x += normal.z * swim_curve * (2.0 * weight / span);
	normal = normalize(normal);
}
