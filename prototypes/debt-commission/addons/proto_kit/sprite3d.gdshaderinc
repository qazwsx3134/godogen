// Shared pieces of the sprite3d shaders: a 2D atlas sprite standing in a 3D world (pokebonk.com / Ragnarok style).
// Spec: skill sprite-actors-3d (godot-kit/skills/sprite-actors-3d/SKILL.md).
//
// Mesh: a 1x1 quad with its bottom edge at y = 0 (QuadMesh center_offset (0, 0.5, 0)), so the node origin is the feet.
// The node or MultiMesh instance basis carries the size (column lengths) and a tumble (its rotation around Z).
// Built-ins are not visible inside functions, so the stage functions pass them in.

// The billboard: right = camera right flattened onto the ground, up = world up leaned toward the camera up by `lean`
// (0 = upright, turns only around Y; 1 = faces the camera fully). `toward_camera` moves the origin that far (m) toward
// the camera, for an overlay that must sit just in front of the body.
mat4 sprite3d_modelview(mat4 model, mat4 view, mat4 inv_view, float lean, float toward_camera) {
	vec3 right = normalize(vec3(inv_view[0].x, 0.0, inv_view[0].z));
	vec3 up = normalize(mix(vec3(0.0, 1.0, 0.0), inv_view[1].xyz, lean));
	vec3 back = normalize(cross(right, up));
	vec4 origin = model[3];
	if (toward_camera != 0.0) {
		origin.xyz += normalize(inv_view[3].xyz - origin.xyz) * toward_camera;
	}
	return view * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(back, 0.0), origin);
}

vec3 sprite3d_scale(mat4 model) {
	return vec3(length(model[0].xyz), length(model[1].xyz), length(model[2].xyz));
}

// The quad's local vertex: feet on the ground (the cell's transparent foot strip cut off), mirrored when facing < 0.
vec3 sprite3d_local(vec3 v, float foot_gutter, float facing) {
	v.y -= foot_gutter;
	v.x *= facing < 0.0 ? -1.0 : 1.0;
	return v;
}

// A launched body tumbling: the basis' rotation around Z, applied around the body's middle. Apply it last, after any
// squash or bob (rotation and a non-uniform scale do not commute; this is the order madara-survivor was tuned with).
vec3 sprite3d_spin(vec3 v, mat4 model) {
	float spin = atan(model[0].y, model[0].x);
	if (abs(spin) > 0.001) {
		vec2 c = vec2(0.0, 0.5);
		vec2 p = v.xy - c;
		v.xy = c + vec2(p.x * cos(spin) - p.y * sin(spin), p.x * sin(spin) + p.y * cos(spin));
	}
	return v;
}

// Cell `frame` of a `frames.x` x `frames.y` grid, counted left to right, top to bottom.
vec2 sprite3d_cell(float frame, vec2 frames) {
	return vec2(mod(frame, frames.x), floor(frame / frames.x));
}

// Largest alpha of the four neighbouring atlas texels, clamped to this cell so a neighbour cell never bleeds in.
// Cells keep at least one transparent texel on every side, so the outline has room inside the cell.
float sprite3d_neighbour_alpha(sampler2D atlas, vec2 uv, vec2 cell, vec2 frames) {
	vec2 texel = 1.0 / vec2(textureSize(atlas, 0));
	vec2 lo = cell / frames + texel * 0.5;
	vec2 hi = (cell + 1.0) / frames - texel * 0.5;
	return max(
		max(texture(atlas, clamp(uv + vec2(texel.x, 0.0), lo, hi)).a, texture(atlas, clamp(uv - vec2(texel.x, 0.0), lo, hi)).a),
		max(texture(atlas, clamp(uv + vec2(0.0, texel.y), lo, hi)).a, texture(atlas, clamp(uv - vec2(0.0, texel.y), lo, hi)).a));
}

float sprite3d_bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int index = i.x + i.y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[index]) + 0.5) / 16.0;
}

// Stable 0..1 noise per atlas texel, so a dissolve eats whole pixels and the same pixels every time.
float sprite3d_texel_hash(vec2 uv, sampler2D atlas) {
	vec2 t = floor(uv * vec2(textureSize(atlas, 0)));
	return fract(sin(dot(t, vec2(12.9898, 78.233))) * 43758.5453);
}
