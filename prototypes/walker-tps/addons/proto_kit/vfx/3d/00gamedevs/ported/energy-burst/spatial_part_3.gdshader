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
#define VARIANT 1
#define TOON 1
uniform float uSize;
uniform float uTime;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;
varying float bridge_vFade;


    float vs_hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
    float vs_noise2(vec2 p){
      vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
      return mix(mix(vs_hash(i),vs_hash(i+vec2(1,0)),f.x),mix(vs_hash(i+vec2(0,1)),vs_hash(i+vec2(1)),f.x),f.y);
    }
    float vs_fbm(vec2 p){ return vs_noise2(p)*0.57+vs_noise2(p*2.07+3.1)*0.29+vs_noise2(p*4.13-1.7)*0.14; }
    float vs_band(float x,float width){ return 1.0-smoothstep(width,width+0.004,abs(x)); }
    #define SRC_PI 3.14159265359
  
          void vs_main(inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec4 seed, inout vec2 uv, inout float vFade, inout vec2 vUv){vUv=uv;float t=uTime,a=seed.x*SRC_PI*2.0,dt=max(0.0,t-.09-seed.w*.09);vec3 dir=normalize(vec3(cos(a),.4+seed.y*1.8,sin(a)));
            vec3 p=dir*(.35+(1.0-exp(-dt*3.0))*(1.2+seed.z*1.8));p*=uSize;p.y-=1.2;
            vec4 mv=modelViewMatrix*vec4(p,1);vec2 along=normalize((modelViewMatrix*vec4(dir,0)).xy+vec2(.0001));vec2 side=vec2(-along.y,along.x);
            float jag=(vs_hash(vec2(seed.w*71.0,floor(uv.x*4.0+.01)))-.5)*sin(uv.x*SRC_PI);
            mv.xy+=(along*position.x*(.22+seed.z*.45)+side*(jag*.05+position.y*.16))*uSize*length(modelMatrix[1].xyz);
            vFade=smoothstep(.0,.07,dt)*(1.0-smoothstep(.28+seed.z*.15,.65+seed.z*.3,dt));gl_Position=projectionMatrix*mv;}


    float fs_styleStep(float edge,float value){float aa=max(fwidth(value),.012);return smoothstep(edge-aa,edge+aa,value);}
    vec3 fs_styleColor(vec3 tint,float light){
      vec3 c=mix(tint*.22,tint*.72,fs_styleStep(.38,light));
      return mix(c,mix(tint,vec3(1.0),.38)*1.04,fs_styleStep(.70,light));
    }
    vec3 fs_styleHeat(vec3 tint,float heat){
      vec3 c=mix(tint*.24,tint*1.05,fs_styleStep(.38,heat));
      return mix(c,mix(tint,vec3(1.0,.88,.51),.62),fs_styleStep(.70,heat));
    }
  
          void fs_main(inout vec4 gl_FragColor, inout float vFade, inout vec2 vUv){vec2 q=vUv*2.0-1.0;float core=exp(-q.y*q.y*90.0),halo=exp(-q.y*q.y*8.0),tip=1.0-smoothstep(.2,1.0,abs(q.x));
            gl_FragColor=vec4(uColor*1.3+vec3(core*1.8),(core+halo*.25)*tip*vFade*uDetail);
    
    
  }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelMatrix = MODEL_MATRIX;
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec4 seed = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
vec2 uv = UV;
float vFade = float(0);
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelMatrix, modelViewMatrix, position, projectionMatrix, seed, uv, vFade, vUv);
bridge_vUv = vUv;
bridge_vFade = vFade;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vFade = bridge_vFade;
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vFade, vUv);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
