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
#define KIND 3
#define VARIANT 0
#define TOON 1
uniform float uSize;
uniform float uTime;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;
varying float bridge_vFade;
varying float bridge_vSeed;


    
    void vs_main(inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec4 seed, inout vec2 uv, inout float vFade, inout float vSeed, inout vec2 vUv){
      vUv=uv;vSeed=seed.w;float t=max(0.0,uTime-seed.y*.08);
      float angle=seed.x*6.283185,travel=(1.0-exp(-t*12.0))*(1.2+seed.z*2.3);
      vec3 p=vec3(cos(angle)*travel,max(.04,(1.0-exp(-t*8.0))*(.25+seed.w*1.7)-t*t*1.4),sin(angle)*travel);
      vec3 velocity=vec3(cos(angle)*exp(-t*5.0),.4+seed.w-t*2.0,sin(angle)*exp(-t*5.0));
      vec2 axis=(modelViewMatrix*vec4(velocity,0.0)).xy;
      float len=length(axis);axis=len>.0001?axis/len:vec2(1,0);
      vec2 side=vec2(-axis.y,axis.x);
      p*=uSize;p.y-=1.35;vec4 mv=modelViewMatrix*vec4(p,1.0);
      float streakLength=(.18+seed.z*.38)*(1.0-smoothstep(.12,.55,t))+.09;
      float width=.08+seed.w*.07;
      mv.xy+=(axis*position.x*streakLength+side*position.y*width)*uSize*length(modelMatrix[1].xyz);
      vFade=smoothstep(.0,.015,t)*(1.0-smoothstep(.40,1.4+seed.w*.6,t));
      gl_Position=projectionMatrix*mv;
    }


    float fs_styleStep(float edge,float value){float aa=max(fwidth(value),.012);return smoothstep(edge-aa,edge+aa,value);}
    vec3 fs_styleColor(vec3 tint,float light){
      vec3 c=mix(tint*.22,tint*.72,fs_styleStep(.38,light));
      return mix(c,mix(tint,vec3(1.0),.38)*1.04,fs_styleStep(.70,light));
    }
    vec3 fs_styleHeat(vec3 tint,float heat){
      vec3 c=mix(tint*.24,tint*1.05,fs_styleStep(.38,heat));
      return mix(c,mix(tint,vec3(1.0,.88,.51),.62),fs_styleStep(.70,heat));
    }
  
    
    
    float fs_hash3(vec3 p){p=fract(p*.3183099+vec3(.11,.17,.23));p*=17.0;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
    float fs_field3(vec3 p){
      vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
      return mix(mix(mix(fs_hash3(i),fs_hash3(i+vec3(1,0,0)),f.x),mix(fs_hash3(i+vec3(0,1,0)),fs_hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(fs_hash3(i+vec3(0,0,1)),fs_hash3(i+vec3(1,0,1)),f.x),mix(fs_hash3(i+vec3(0,1,1)),fs_hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
    }
    float fs_turbulence(vec3 p){return fs_field3(p)*.64+fs_field3(p*2.03+5.1)*.26+fs_field3(p*4.01-2.7)*.10;}
    vec3 fs_hotColor(vec3 base,float heat){
      vec3 flame=min(base*(1.2+max(0.0,heat)*3.0),vec3(1.0));
      return mix(flame,vec3(1.0,.97,.85),smoothstep(.75,1.10,heat));
    }
  
    void fs_main(inout vec4 gl_FragColor, inout float vFade, inout vec2 vUv){
      vec2 p=(vUv-.5)*2.0;float d=abs(p.x)+abs(p.y);
      float core=1.0-smoothstep(.08,.48,d),halo=exp(-d*d*4.0)*(1.0-smoothstep(.7,1.0,d));
      float alpha=(core+halo*.45)*vFade;
      if(alpha<.005)discard;
      gl_FragColor=vec4(mix(fs_hotColor(uColor,.65),vec3(1.0,.98,.87),core),alpha);
    
    
  
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
float vSeed = float(0);
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelMatrix, modelViewMatrix, position, projectionMatrix, seed, uv, vFade, vSeed, vUv);
bridge_vUv = vUv;
bridge_vFade = vFade;
bridge_vSeed = vSeed;
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
