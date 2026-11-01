// 00GameDevs MIT, 2026 @00vchannel; native Godot port of original GLSL.
// Authoring source: tools/vfx/three_port; Compatibility spatial, no fragment texture loops.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_add;
uniform mat4 source_to_group;
uniform float source_draw_start = 0.0;
uniform float source_draw_count = -1.0;
uniform int source_vertices_per_instance = 1;
uniform float source_instance_count = 1.0;
varying flat float source_draw;
varying flat float source_instance;
#define KIND 2
#define VARIANT 15
#define TOON 0
uniform float uSize;
uniform float uTime;
uniform float uCrackBloomSpread;
uniform float uDetail;
uniform float uCrackBloom;
uniform vec3 uColor;
varying vec2 bridge_vGlow;
varying vec2 bridge_vReveal;
varying float bridge_vAge;
varying float bridge_vLength;


    vec2 vs_gcCrackPoint(vec2 q,float seed){
      float radius=length(q),angle=seed*6.283185;
      q*=.88+.12*sin((radius>0.0?atan(q.y,q.x):0.0)*3.0+seed*37.0+radius*4.0);
      return mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)))*q;
    }
  
    
    
    void vs_main(inout vec3 aCrackA, inout vec3 aCrackB, inout vec3 aEnd, inout vec2 aTime, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout float vAge, inout vec2 vGlow, inout float vLength, inout vec2 vReveal){
      vec2 a=vs_gcCrackPoint(aCrackA.xy,aTime.y),b=vs_gcCrackPoint(aCrackB.xy,aTime.y),delta=b-a;
      float lengthAB=length(delta);vec2 direction=delta/max(lengthAB,.0001),across=vec2(-direction.y,direction.x);
      float reach=.20*uCrackBloomSpread;
      vGlow=position.xy*vec2(lengthAB*.5+reach,reach);vLength=lengthAB;vReveal=vec2(aCrackA.z,aCrackB.z);vAge=uTime-aTime.x;
      vec2 q=(a+b)*.5+direction*vGlow.x+across*vGlow.y;
      vec3 p=aEnd+vec3(q.x,.014,q.y);gl_Position=projectionMatrix*modelViewMatrix*vec4(p*uSize,1.0);
    }


    
    void fs_main(inout vec4 gl_FragColor, inout float vAge, inout vec2 vGlow, inout float vLength, inout vec2 vReveal){
      float along=clamp((vGlow.x+vLength*.5)/max(vLength,.0001),0.0,1.0);
      float progress=mix(vReveal.x,vReveal.y,along);
      float reveal=smoothstep(progress*.15,progress*.15+.03,vAge-.35);
      float fade=1.0-smoothstep(1.10,1.85,vAge);
      float distance=length(vec2(max(abs(vGlow.x)-vLength*.5,0.0),vGlow.y))/uCrackBloomSpread;
      
      float glow=(exp(-distance*distance/ .0036)*.46+exp(-distance*distance/ .0144)*.24);
      float alpha=glow*(1.0-smoothstep(.13,.20,distance))*reveal*fade*uCrackBloom;
      if(alpha<.001)discard;
      gl_FragColor=vec4(uColor*vec3(2.3,1.8,.65),alpha);
    
    
  
    }
void vertex(){
vec3 aCrackA = vec3(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z);
vec3 aCrackB = vec3(CUSTOM0.w,CUSTOM1.x,CUSTOM1.y);
vec3 aEnd = vec3(CUSTOM2.y,CUSTOM2.z,CUSTOM2.w);
vec2 aTime = vec2(CUSTOM3.x,CUSTOM3.y);
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
float vAge = float(0);
vec2 vGlow = vec2(0);
float vLength = float(0);
vec2 vReveal = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aCrackA, aCrackB, aEnd, aTime, gl_Position, modelViewMatrix, position, projectionMatrix, vAge, vGlow, vLength, vReveal);
bridge_vGlow = vGlow;
bridge_vReveal = vReveal;
bridge_vAge = vAge;
bridge_vLength = vLength;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vAge = bridge_vAge;
vec2 vGlow = bridge_vGlow;
float vLength = bridge_vLength;
vec2 vReveal = bridge_vReveal;
fs_main(gl_FragColor, vAge, vGlow, vLength, vReveal);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
