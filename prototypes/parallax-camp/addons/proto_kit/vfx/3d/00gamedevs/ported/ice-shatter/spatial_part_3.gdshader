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
#define KIND 3
#define VARIANT 3
#define TOON 1
uniform float uSize;
uniform float uTime;
uniform float uDetail;
uniform vec3 uColor;
varying float bridge_vFade;
varying vec3 bridge_vN;


        
        void vs_main(inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 normal, inout mat3 normalMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec4 seed, inout float vFade, inout vec3 vN){float t=uTime,a=seed.x*6.28318;float dt=max(0.0,t-seed.w*0.1);float speed=0.5+seed.z*1.4;vec3 c=vec3(cos(a)*dt*speed,max(-1.32,-1.32+(2.0+seed.y*3.8)*dt-2.4*dt*dt),sin(a)*dt*speed);vec3 p=position;p.y*=2.2;float spin=a+t*2.0;mat2 rot=mat2(vec2(cos(spin),-sin(spin)),vec2(sin(spin),cos(spin)));p.xy=rot*p.xy;p*=0.6+seed.z;vN=normalMatrix*normal;vFade=pow(max(0.0,1.0-t/2.8),1.3);gl_Position=projectionMatrix*modelViewMatrix*vec4(c+p,1.0);}
      


    float fs_styleStep(float edge,float value){float aa=max(fwidth(value),.012);return smoothstep(edge-aa,edge+aa,value);}
    vec3 fs_styleColor(vec3 tint,float light){
      vec3 c=mix(tint*.22,tint*.72,fs_styleStep(.38,light));
      return mix(c,mix(tint,vec3(1.0),.38)*1.04,fs_styleStep(.70,light));
    }
    vec3 fs_styleHeat(vec3 tint,float heat){
      vec3 c=mix(tint*.24,tint*1.05,fs_styleStep(.38,heat));
      return mix(c,mix(tint,vec3(1.0,.88,.51),.62),fs_styleStep(.70,heat));
    }
  void fs_main(inout vec4 gl_FragColor, inout float vFade, inout vec3 vN){float light=0.35+max(dot(normalize(vN),normalize(vec3(-0.6,0.8,0.4))),0.0);vec3 c=uColor*(.7+light);
        #if TOON == 1
          c=fs_styleColor(uColor,light*.7);
        #endif
        gl_FragColor=vec4(c,vFade*uDetail);
    
    
  }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 normal = NORMAL;
mat3 normalMatrix = MODELVIEW_NORMAL_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec4 seed = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
float vFade = float(0);
vec3 vN = vec3(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelViewMatrix, normal, normalMatrix, position, projectionMatrix, seed, vFade, vN);
bridge_vFade = vFade;
bridge_vN = vN;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vFade = bridge_vFade;
vec3 vN = bridge_vN;
fs_main(gl_FragColor, vFade, vN);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
