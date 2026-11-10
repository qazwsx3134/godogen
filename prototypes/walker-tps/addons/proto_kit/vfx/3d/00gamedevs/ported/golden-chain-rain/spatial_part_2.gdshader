// 00GameDevs MIT, 2026 @00vchannel; native Godot port of original GLSL.
// Authoring source: tools/vfx/three_port; Compatibility spatial, no fragment texture loops.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;
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
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vCrack;
varying float bridge_vAge;


    vec2 vs_gcCrackPoint(vec2 q,float seed){
      float radius=length(q),angle=seed*6.283185;
      q*=.88+.12*sin((radius>0.0?atan(q.y,q.x):0.0)*3.0+seed*37.0+radius*4.0);
      return mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)))*q;
    }
  
    void vs_main(inout vec3 aEnd, inout vec2 aTime, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout float vAge, inout vec2 vCrack){
      vec2 q=vs_gcCrackPoint(position.xz,aTime.y);
      vec3 p=aEnd+vec3(q.x,position.y,q.y);vCrack=uv;vAge=uTime-aTime.x;
      gl_Position=projectionMatrix*modelViewMatrix*vec4(p*uSize,1.0);
    }


    void fs_main(inout vec4 gl_FragColor, inout float vAge, inout vec2 vCrack){
      float reveal=smoothstep(vCrack.y*.15,vCrack.y*.15+.03,vAge-.35);
      float fade=1.0-smoothstep(1.10,1.85,vAge);
      float edge=1.0-smoothstep(.72,1.0,abs(vCrack.x));
      float alpha=reveal*fade*edge;if(alpha<.004)discard;
      
      float core=1.0-smoothstep(.08,.72,abs(vCrack.x));
      vec3 color=mix(uColor*vec3(1.0,.72,.12),mix(uColor,vec3(1.0,.92,.44),.35)*1.5,core);
      gl_FragColor=vec4(color,alpha);
    
    
  
    }
void vertex(){
vec3 aEnd = vec3(CUSTOM0.w,CUSTOM1.x,CUSTOM1.y);
vec2 aTime = vec2(CUSTOM1.z,CUSTOM1.w);
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
float vAge = float(0);
vec2 vCrack = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aEnd, aTime, gl_Position, modelViewMatrix, position, projectionMatrix, uv, vAge, vCrack);
bridge_vCrack = vCrack;
bridge_vAge = vAge;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vAge = bridge_vAge;
vec2 vCrack = bridge_vCrack;
fs_main(gl_FragColor, vAge, vCrack);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
