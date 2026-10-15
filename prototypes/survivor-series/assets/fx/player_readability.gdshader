shader_type canvas_item;
// A restrained inner silhouette above crowded projectiles. The base art remains depth-sorted.
uniform vec4 outline_color : source_color = vec4(1.0, 0.9, 0.55, 0.95);
void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float inner = min(min(texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0)).a,
		texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0)).a),
		min(texture(TEXTURE, UV + vec2(0, TEXTURE_PIXEL_SIZE.y)).a,
		texture(TEXTURE, UV - vec2(0, TEXTURE_PIXEL_SIZE.y)).a));
	float edge = art.a * (1.0 - inner);
	vec3 fill = mix(art.rgb, outline_color.rgb, edge);
	COLOR = vec4(fill, art.a * mix(0.65, outline_color.a, edge));
}
