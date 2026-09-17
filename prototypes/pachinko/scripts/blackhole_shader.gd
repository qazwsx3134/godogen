extends RefCounted
class_name BlackHoleShader

## 黑洞的兩種畫法，差別只在**要不要讀螢幕**。
##
## 參考實作（vgpu.sh 的 optimized black hole）用 WGSL、G-buffer 多 pass、逐像素測地線
## 光線追蹤。視覺語言值得抄——透鏡化的吸積盤、被彎曲的星場、光子環——但那條技術路徑在
## 這裡跑不了：Compatibility renderer 只有 WebGL2，而多 pass raymarching 正是最貴的一類。
##
## 所以兩種都用**解析式**近似取代測地線積分：位移量 ∝ 1/r²，直接推取樣座標。
## 差別在取樣的對象：
##   LENSED  讀 backbuffer，真的把背後畫面拉彎 → iPhone 的 TBDR GPU 要做一次全螢幕
##           resolve，這是最可能殺幀數的地方
##   PROCEDURAL 星場自己程序生成，不碰 backbuffer → 沒有 resolve

const _COMMON := """
uniform vec2 bh_center = vec2(0.5, 0.5);
uniform float bh_radius = 0.09;
uniform float lens_strength = 0.010;
uniform float t = 0.0;
uniform float aspect = 1.0;

vec3 disk(vec2 d, float r) {
	float ang = atan(d.y, d.x);
	float inner = bh_radius * 1.12;
	float outer = bh_radius * 3.2;
	float band = smoothstep(inner, inner * 1.22, r) * (1.0 - smoothstep(outer * 0.62, outer, r));
	float swirl = 0.5 + 0.5 * sin(ang * 3.0 + t * 2.2 - r * 42.0);
	// 都卜勒增亮：轉向我們的那一側比較亮，這是黑洞辨識度最高的特徵之一
	float doppler = 0.35 + 0.65 * smoothstep(-1.0, 1.0, sin(ang + 1.5707));
	vec3 c = band * swirl * doppler * vec3(1.35, 0.66, 0.24);
	// 光子環：視界外緣一圈細亮線
	float photon = smoothstep(bh_radius * 1.16, bh_radius * 1.03, r)
		* smoothstep(bh_radius * 0.99, bh_radius * 1.03, r);
	return c + photon * vec3(1.7, 1.35, 1.0);
}
"""

## 貴的版本：讀 backbuffer。
static func lensed() -> Shader:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
""" + _COMMON + """
void fragment() {
	vec2 d = UV - bh_center;
	d.x *= aspect;
	float r = max(length(d), 1e-4);
	float bend = lens_strength / (r * r + 0.0035);
	vec2 off = (d / r) * bend;
	off.x /= aspect;
	vec3 col = texture(screen_tex, SCREEN_UV + off * 0.5).rgb;
	col += disk(d, r);
	col *= smoothstep(bh_radius * 0.94, bh_radius * 1.02, r);
	COLOR = vec4(col, 1.0);
}
"""
	return sh

## 便宜的版本：星場程序生成，不碰 backbuffer。
static func procedural() -> Shader:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
""" + _COMMON + """
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec3 starfield(vec2 uv) {
	vec3 c = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		float s = float(i) + 1.0;
		vec2 g = uv * (52.0 * s);
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float h = hash21(id + s * 17.0);
		if (h > 0.955) {
			float b = smoothstep(0.34, 0.0, length(f)) * (h - 0.955) * 26.0;
			c += b * vec3(0.72, 0.80, 1.0) / s;
		}
	}
	return c;
}

void fragment() {
	vec2 d = UV - bh_center;
	d.x *= aspect;
	float r = max(length(d), 1e-4);
	float bend = lens_strength / (r * r + 0.0035);
	vec2 off = (d / r) * bend;
	off.x /= aspect;
	vec3 col = starfield(UV + off);
	col += disk(d, r);
	col *= smoothstep(bh_radius * 0.94, bh_radius * 1.02, r);
	COLOR = vec4(col, 1.0);
}
"""
	return sh
