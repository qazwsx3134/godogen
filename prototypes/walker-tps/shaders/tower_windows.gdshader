shader_type spatial;
// Distant towers: one box per bay; the window grid is painted here instead of modelled.
// Grid in object space so it lines up with the bays whatever the tower's placement.
uniform vec3 cell = vec3(3.6, 3.6, 4.0);    // bay x, storey, bay z
uniform vec3 origin = vec3(-9.0, 0.0, -10.0); // the tower's corner (bay boundaries start here)
uniform vec3 frame_color : source_color = vec3(0.52, 0.5, 0.46);
uniform vec3 glass_color : source_color = vec3(0.12, 0.17, 0.21);
varying vec3 p;
varying vec3 n;

float hash(vec2 q) { return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() { p = VERTEX - origin; n = NORMAL; }

void fragment() {
	vec3 an = abs(n);
	if (an.y > 0.5) {
		ALBEDO = frame_color * 0.75;
		ROUGHNESS = 0.95;
	} else {
		float u = an.x > an.z ? p.z / cell.z : p.x / cell.x;
		vec2 g = vec2(u, p.y / cell.y);
		vec2 id = floor(g) + (an.x > an.z ? vec2(31.0, 0.0) : vec2(0.0));
		vec2 f = fract(g);
		float win = step(0.1, f.x) * step(f.x, 0.9) * step(0.32, f.y) * step(f.y, 0.92);
		float r = hash(id + sign(n.xz) * 7.0);
		// Some panes blown out (black), some catching the sky; streaks of grime down the frame.
		vec3 pane = r < 0.25 ? vec3(0.02) : glass_color * (0.7 + 0.6 * r);
		float grime = 0.8 + 0.2 * hash(vec2(id.x, floor(p.y * 0.5)));
		ALBEDO = mix(frame_color * grime, pane, win);
		METALLIC = win * (r < 0.25 ? 0.0 : 0.6);
		ROUGHNESS = mix(0.9, r < 0.25 ? 1.0 : 0.2, win);
	}
}
