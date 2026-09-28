shader_type canvas_item;
uniform vec4 region_uv = vec4(0.0,0.0,1.0,1.0);
uniform float region_width = 941.0;
uniform float travel_pixels = 0.0;
uniform float depth_near = 0.2;
uniform float depth_far = 0.2;
void fragment() {
	vec2 local_uv = (UV - region_uv.xy) / region_uv.zw;
	float depth = mix(depth_far, depth_near, smoothstep(0.0,1.0,local_uv.y));
	local_uv.x = fract(local_uv.x + travel_pixels * depth / max(region_width,1.0));
	COLOR = texture(TEXTURE, region_uv.xy + local_uv * region_uv.zw);
}
