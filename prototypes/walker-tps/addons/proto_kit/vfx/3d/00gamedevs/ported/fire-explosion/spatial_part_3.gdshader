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
#define VARIANT 0
#define TOON 1
uniform float uSize;
uniform float uTime;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;
varying vec4 bridge_vSeed;


    
    
    vec3 vs_path(float age,vec4 seed){
      float angle=seed.x*2.399963+seed.y*.8;
      float travel=(1.0-exp(-age*8.0))*(2.5+seed.z*.8);
      float lift=(1.0-exp(-age*10.0))*(1.4+seed.w*2.6)-age*age*2.8;
      vec3 p=vec3(cos(angle)*travel,max(.055,lift+.35),sin(angle)*travel);
      float curl=sin(age*15.0+seed.y*13.0)*age*.12;
      p+=vec3(-sin(angle)*curl,cos(age*11.0+seed.z*9.0)*age*.06,cos(angle)*curl);
      return p;
    }
  
    void vs_main(inout vec4 aSeed, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout mat4 projectionMatrix, inout vec2 uv, inout vec4 vSeed, inout vec2 vUv){
      vUv=uv;vSeed=aSeed;
      float t=max(0.0,uTime-aSeed.y*.025),tail=max(0.0,t-.5),age=mix(tail,t,uv.x);
      vec3 p=vs_path(age,aSeed),direction=normalize(vs_path(age+.002,aSeed)-p);
      vec3 side=normalize(cross(direction,vec3(0.0,1.0,.01))),up=cross(side,direction);
      float width=mix(.020,.055,smoothstep(.95,1.0,uv.x))*(.5+sin(uv.x*3.141593)*.5);
      p+=(side*cos(uv.y*6.283185)+up*sin(uv.y*6.283185))*width;
      p*=uSize;p.y-=1.35;gl_Position=projectionMatrix*modelViewMatrix*vec4(p,1.0);
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
  
    void fs_main(inout vec4 gl_FragColor, inout vec2 vUv){
      float alpha=smoothstep(.0,.025,uTime)*(1.0-smoothstep(.55,1.70,uTime));
      float head=smoothstep(.94,.98,vUv.x),heat=max(head,1.0-smoothstep(.08,.27,uTime));
      alpha*=mix(.28,.95,heat)*smoothstep(.0,.20,vUv.x);
      if(alpha<.005)discard;
      gl_FragColor=vec4(mix(vec3(.19,.19,.20),fs_hotColor(uColor,.70),heat),alpha);
    
    
  
    }
void vertex(){
vec4 aSeed = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
vec4 vSeed = vec4(0);
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aSeed, gl_Position, modelViewMatrix, projectionMatrix, uv, vSeed, vUv);
bridge_vUv = vUv;
bridge_vSeed = vSeed;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vUv);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
