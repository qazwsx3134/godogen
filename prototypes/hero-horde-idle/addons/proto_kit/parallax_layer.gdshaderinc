// One scrolling layer of a side-scrolling view (march_strip.gd: far picture, ground): the texture `tex` repeated
// `tiles` times across the rect (and down it), moved left by `offset` (in tiles; the script advances it). `mirror`
// repeats a picture that does not tile back and forth so its seams match. depth_far / depth_near scroll the top and
// the bottom of the layer at different rates (a ground plane receding into the distance: bottom rows move faster),
// blended down the rect; equal values (the default 1) move the layer as one. Nearest filtering, for pixel art.
// Included by parallax_layer.gdshader.
uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform vec2 tiles = vec2(1.0, 1.0);
uniform float offset = 0.0;
uniform bool mirror = false;
uniform float depth_far = 1.0;
uniform float depth_near = 1.0;

void fragment() {
	float shift = offset;
	if (depth_far != depth_near) {
		shift *= mix(depth_far, depth_near, smoothstep(0.0, 1.0, UV.y));
	}
	vec2 uv = vec2(UV.x * tiles.x + shift, UV.y * tiles.y);
	if (mirror) {
		uv.x = 1.0 - abs(mod(uv.x, 2.0) - 1.0);
	}
	COLOR = texture(tex, fract(uv)) * COLOR;
}
