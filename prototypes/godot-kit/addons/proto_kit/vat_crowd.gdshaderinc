// Bind lossless floating-point textures; each column matches one mesh vertex.
uniform sampler2D vat_positions : filter_nearest, repeat_disable;
uniform sampler2D vat_normals : filter_nearest, repeat_disable;
varying float vat_hit;

void vat_pose(int id, vec4 actor, float cycles, inout vec3 position, inout vec3 normal) {
	float frame = fract(cycles + actor.x) * actor.z;
	int count = max(1, int(actor.z));
	int a = int(frame) % count;
	int b = (a + 1) % count;
	ivec2 pa = ivec2(id, int(actor.y) + a);
	ivec2 pb = ivec2(id, int(actor.y) + b);
	position = mix(texelFetch(vat_positions, pa, 0).xyz, texelFetch(vat_positions, pb, 0).xyz, fract(frame));
	normal = normalize(mix(texelFetch(vat_normals, pa, 0).xyz, texelFetch(vat_normals, pb, 0).xyz, fract(frame)));
}
