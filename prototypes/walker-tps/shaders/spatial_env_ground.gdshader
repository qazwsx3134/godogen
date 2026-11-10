shader_type spatial;
// Walker TPS: shared atlas ground, Compatibility/mobile. Six texture reads, two-scale surface color breakup.
uniform sampler2D atlas_color : source_color, filter_linear_mipmap;
uniform sampler2D atlas_normal : hint_normal, filter_linear_mipmap;
uniform float tile_meters : hint_range(0.5, 8.0) = 3.0;
uniform float road_half_width : hint_range(2.0, 12.0) = 6.0;
varying vec3 world_position;
// Smooth value noise: broad dirt patches rather than a periodic stripe mask.
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2(vec2 p) {
	vec2 cell=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(cell),hash21(cell+vec2(1,0)),f.x),
		mix(hash21(cell+vec2(0,1)),hash21(cell+vec2(1,1)),f.x),f.y);
}
const vec2 ATLAS_GRADIENT_SCALE=vec2(0.234375,0.46875); // 240px inset tile / atlas size

vec2 atlas_uv(vec2 uv, vec2 cell) {
	return (cell + (fract(uv) * 240.0 + 8.0) / 256.0) / vec2(4.0, 2.0);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_position.xz;
	vec2 warp=vec2(noise2(p*0.13),noise2(p*0.13+43.0))-0.5;
	vec2 uv=(p+warp*1.4)/tile_meters;
	vec2 alternate=vec2(-p.y,p.x)/(tile_meters*1.81)+17.3;
	vec2 dx=dFdx(uv)*ATLAS_GRADIENT_SCALE, dy=dFdy(uv)*ATLAS_GRADIENT_SCALE;
	vec2 dx2=dFdx(alternate)*ATLAS_GRADIENT_SCALE, dy2=dFdy(alternate)*ATLAS_GRADIENT_SCALE;
	float patches=noise2(p*0.065)+0.25*noise2(p*0.31);
	float blend=smoothstep(0.25,0.8,noise2(p*0.24));
	vec3 soil=mix(textureGrad(atlas_color,atlas_uv(uv,vec2(0,0)),dx,dy).rgb,
		textureGrad(atlas_color,atlas_uv(alternate,vec2(0,0)),dx2,dy2).rgb,blend);
	vec3 asphalt=mix(textureGrad(atlas_color,atlas_uv(uv,vec2(1,0)),dx,dy).rgb,
		textureGrad(atlas_color,atlas_uv(alternate,vec2(1,0)),dx2,dy2).rgb,blend);
	vec3 grass=textureGrad(atlas_color,atlas_uv(alternate,vec2(2,0)),dx2,dy2).rgb;
	float edge=(noise2(p*0.18)-0.5)*3.0+(noise2(p*0.73)-0.5)*0.8;
	float road=1.0-smoothstep(road_half_width-1.8,road_half_width+2.2,abs(p.x-7.0*sin(p.y*0.025))+edge);
	float worn=smoothstep(0.65,0.95,patches)*0.42;
	ALBEDO=mix(mix(soil,grass,smoothstep(0.35,0.85,patches)),asphalt,road*(0.93-worn));
	ALBEDO*=0.85+0.22*noise2(p*0.1+31.0);
	NORMAL_MAP=textureGrad(atlas_normal,atlas_uv(uv,vec2(0,0)),dx,dy).rgb;
	NORMAL_MAP_DEPTH=0.3;
	ROUGHNESS=0.96;
}
