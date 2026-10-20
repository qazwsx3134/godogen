shader_type spatial;
// Landmarks (execution platform, HQ, siege walls, warships, the bridge): one color, the terrain's toon diffuse,
// and optional block courses (sides) and slabs (tops) in world space at the sprites' pixel density.
render_mode unshaded, cull_back, shadows_disabled;

uniform vec4 albedo : source_color = vec4(0.7, 0.7, 0.75, 1.0);
uniform float px_per_m = 40.0;
uniform vec3 sun_dir = vec3(-0.45, 0.8, 0.35);
uniform vec4 light_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.55, 0.62, 0.82, 1.0);
uniform float bands = 3.0;
// Block courses: height and length in meters; 0 = plain.
uniform vec2 courses = vec2(0.0, 0.0);

varying vec3 world;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = (floor(world * px_per_m) + 0.5) / px_per_m;
	vec3 n = normalize(world_normal);
	vec3 base = albedo.rgb;
	if (courses.x > 0.0 && abs(n.y) < 0.5) {
		float row = floor(w.y / courses.x);
		float along = abs(n.x) > abs(n.z) ? w.z : w.x;
		float col = floor(along / courses.y + 0.5 * mod(row, 2.0));
		base *= 0.9 + 0.12 * hash(vec2(row, col));
		float line = 1.0 / px_per_m;
		if (fract(w.y / courses.x) * courses.x < line || fract(along / courses.y + 0.5 * mod(row, 2.0)) * courses.y < line) {
			base *= 0.72;
		}
	}
	if (courses.y > 0.0 && n.y > 0.5) {
		// Top faces: square slabs `courses.y` wide, staggered every other row.
		vec2 q = w.xz / courses.y;
		q.x += 0.5 * mod(floor(q.y), 2.0);
		base *= 0.9 + 0.12 * hash(floor(q));
		if (min(fract(q.x), fract(q.y)) * courses.y < 1.0 / px_per_m) {
			base *= 0.72;
		}
	}
	float lambert = clamp(dot(n, normalize(sun_dir)), 0.0, 1.0);
	float banded = floor(lambert * bands + 0.5) / bands;
	ALBEDO = base * mix(shadow_color.rgb, light_color.rgb, 0.35 + 0.65 * banded);
}
