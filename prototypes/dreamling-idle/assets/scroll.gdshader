shader_type canvas_item;
uniform float scroll = 0.0;
void fragment() {
	COLOR = texture(TEXTURE, vec2(fract(UV.x + scroll), UV.y)) * COLOR;
}
