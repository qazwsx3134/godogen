shader_type spatial;
render_mode unshaded, cull_disabled;
// 洞口的旋轉光環：依角度與時間流動的條紋
uniform vec4 color_a : source_color = vec4(0.10, 0.05, 0.20, 1.0);
uniform vec4 color_b : source_color = vec4(0.55, 0.25, 1.0, 1.0);
uniform float stripes = 12.0;
uniform float speed = 1.5;
varying vec3 local_pos;
void vertex() { local_pos = VERTEX; }
void fragment() {
	float a = atan(local_pos.z, local_pos.x);
	float s = 0.5 + 0.5 * sin(a * stripes + TIME * speed * 6.2831);
	ALBEDO = mix(color_a.rgb, color_b.rgb, smoothstep(0.3, 0.7, s));
}
