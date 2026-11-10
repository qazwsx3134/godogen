shader_type spatial;
// Walker TPS: low-poly ruins atlas, Compatibility/mobile. Six texture reads; two decorrelated scales share one atlas.
uniform sampler2D atlas_color : source_color, filter_linear_mipmap;
uniform sampler2D atlas_normal : hint_normal, filter_linear_mipmap;
uniform sampler2D atlas_orm : filter_linear_mipmap;
uniform vec2 atlas_cell = vec2(3.0,0.0);
uniform float tile_meters : hint_range(0.5,8.0) = 3.0;
uniform float moss_amount : hint_range(0.0,1.0) = 0.25;
varying vec3 world_position;
varying vec3 world_normal;
varying vec2 object_offset;
// Smooth value noise: broad dirt patches rather than a periodic stripe mask.
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2(vec2 p) {
	vec2 cell=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(cell),hash21(cell+vec2(1,0)),f.x),
		mix(hash21(cell+vec2(0,1)),hash21(cell+vec2(1,1)),f.x),f.y);
}
const vec2 ATLAS_GRADIENT_SCALE=vec2(0.234375,0.46875); // 240px inset tile / atlas size

vec2 atlas_uv(vec2 uv) { return (atlas_cell + (fract(uv)*240.0+8.0)/256.0)/vec2(4.0,2.0); }
void vertex() {
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
	object_offset=vec2(hash21(MODEL_MATRIX[3].xz),hash21(MODEL_MATRIX[3].zx+19.7))*37.0;
}
void fragment() {
	// Dominant-axis projection avoids UV stretch on the simple box modules.
	vec3 n=abs(world_normal);
	vec2 plane=mix(world_position.xy,world_position.zy,step(n.z,n.x));
	plane=mix(plane,world_position.xz,step(max(n.x,n.z),n.y));
	// Object offsets prevent neighboring modules from sharing the same crack positions.
	float angle=object_offset.x;
	mat2 rotation=mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)));
	vec2 warped=plane+vec2(noise2(plane*0.19),noise2(plane*0.19+31.0))*0.7;
	vec2 first=rotation*warped/tile_meters+object_offset;
	vec2 second=rotation*vec2(-warped.y,warped.x)/(tile_meters*1.73)+object_offset.yx+11.3;
	vec2 dx=dFdx(first)*ATLAS_GRADIENT_SCALE, dy=dFdy(first)*ATLAS_GRADIENT_SCALE;
	vec2 dx2=dFdx(second)*ATLAS_GRADIENT_SCALE, dy2=dFdy(second)*ATLAS_GRADIENT_SCALE;
	float blend=smoothstep(0.22,0.78,noise2(plane*0.27+object_offset));
	vec3 base=mix(textureGrad(atlas_color,atlas_uv(first),dx,dy).rgb,
		textureGrad(atlas_color,atlas_uv(second),dx2,dy2).rgb,blend);
	vec3 properties=mix(textureGrad(atlas_orm,atlas_uv(first),dx,dy).rgb,
		textureGrad(atlas_orm,atlas_uv(second),dx2,dy2).rgb,blend);
	vec3 detail=mix(textureGrad(atlas_normal,atlas_uv(first),dx,dy).rgb,
		textureGrad(atlas_normal,atlas_uv(second),dx2,dy2).rgb,blend);
	float broad=noise2(plane*0.14+object_offset);
	float dirt=smoothstep(0.45,0.8,broad);
	float rust_surface=(1.0-step(0.5,atlas_cell.x))*step(0.5,atlas_cell.y);
	// Paint remnants interrupt continuous rust. Streaks stretch in world Y (gravity).
	base=mix(base,vec3(0.11,0.13,0.105),rust_surface*smoothstep(0.5,0.74,broad)*0.8);
	float streak=smoothstep(0.57,0.78,noise2(vec2(plane.x*3.7,world_position.y*0.12)+object_offset));
	streak*=1.0-smoothstep(0.3,0.8,world_normal.y);
	base*=1.0-0.26*dirt-0.22*streak;
	base*=0.93+0.12*hash21(object_offset);
	float moss=moss_amount*smoothstep(0.45,0.72,noise2(plane*0.65+object_offset))*smoothstep(0.15,0.8,world_normal.y);
	ALBEDO=mix(base,vec3(0.12,0.18,0.055),moss);
	ROUGHNESS=mix(properties.g,0.98,max(dirt,moss));
	METALLIC=properties.b*(1.0-max(dirt,moss));
	NORMAL_MAP=detail;
	NORMAL_MAP_DEPTH=0.3;
}
