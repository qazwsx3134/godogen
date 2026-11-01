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


    
    void vs_main(inout vec4 aSeed, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout mat4 projectionMatrix, inout vec2 uv, inout vec4 vSeed, inout vec2 vUv){
      vUv=uv;vSeed=aSeed;vec3 p;
      if(aSeed.x<.5)p=vec3((uv.x-.5)*3.35,.022,(uv.y-.5)*3.35);
      else if(aSeed.x<2.5){
        float t=uTime,angle=uv.x*6.283185;
        float wave=sin(angle*9.0+t*2.0+aSeed.x)*.14+sin(angle*17.0-.7+aSeed.x)*.08+sin(angle*5.0)*.10;
        float radius=(1.0-exp(-t*13.0))*(1.70+aSeed.x*.46)+min(t,1.5)*.62;
        radius+=(uv.y-.5)*(.32+aSeed.x*.15)+wave;
        p=vec3(cos(angle)*radius,.04+sin(uv.y*3.141593)*.025,sin(angle)*radius);
      }else{
        float t=uTime,angle=uv.x*6.283185+t*2.6;
        float r=(1.0-exp(-t*48.0))*(2.12-(aSeed.x-3.0)*.42)+t*.28;
        r+=sin(angle*7.0+aSeed.x)*.045+sin(angle*13.0)*.035;
        p=vec3(cos(angle)*r,.55+(aSeed.x-3.0)*.88+sin(angle*3.0+t*3.0)*.08+(uv.y-.5)*.12,sin(angle)*r);
      }
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
  
    float fs_hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
    float fs_noise2(vec2 p){
      vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
      return mix(mix(fs_hash(i),fs_hash(i+vec2(1,0)),f.x),mix(fs_hash(i+vec2(0,1)),fs_hash(i+vec2(1)),f.x),f.y);
    }
    float fs_fbm(vec2 p){ return fs_noise2(p)*0.57+fs_noise2(p*2.07+3.1)*0.29+fs_noise2(p*4.13-1.7)*0.14; }
    float fs_band(float x,float width){ return 1.0-smoothstep(width,width+0.004,abs(x)); }
    #define SRC_PI 3.14159265359
  
    void fs_main(inout vec4 gl_FragColor, inout vec4 vSeed, inout vec2 vUv){
      float kind=vSeed.x,t=uTime,alpha;vec3 color;
      if(kind<.5){
        vec2 p=(vUv-.5)*2.0;float r=length(p);
        float dist=r+(fs_noise2(p*3.5)-.5)*.24;
        vec2 cells=p*3.0,cell=floor(cells),f=fract(cells);
        float first=10.0,second=10.0;
        for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
          vec2 at=vec2(float(x),float(y)),id=cell+at;
          vec2 jitter=vec2(fs_hash3(vec3(id,1.0)),fs_hash3(vec3(id,2.0)))*.7+.15;
          float d=length(at+jitter-f);
          if(d<first){second=first;first=d;}else if(d<second)second=d;
        }
        float lava=(1.0-smoothstep(.025,.11,second-first))*(1.0-smoothstep(.3,1.0,dist));
        float heat=1.0-smoothstep(.65,2.8,t);
        color=mix(vec3(.012,.010,.009),fs_hotColor(uColor,.6),lava*heat);
        alpha=(1.0-smoothstep(.7,1.0,dist))*(1.0-smoothstep(2.25,2.8,t))*.85;
      }else if(kind<2.5){
        float edge=sin(vUv.y*3.141593);
        float rough=fs_noise2(vec2(vUv.x*24.0-kind*9.0,vUv.y*6.0-t*.4));
        float fade=1.0-smoothstep(.45,1.05,t);
        alpha=smoothstep(.0,.22,edge)*(.45+rough*.40)*fade*smoothstep(.0,.035,t);
        if(rough+.15<smoothstep(.30,1.4,t)*.6)discard;
        color=mix(vec3(.23,.24,.26),fs_hotColor(uColor,.65),1.0-smoothstep(.30,.68,t));
      }else{
        float rip=fs_noise2(vec2(vUv.x*18.0-kind*7.0,vUv.y*2.0-t*1.8));
        if(rip<.20)discard;
        alpha=sin(vUv.y*3.141593)*.85*smoothstep(.0,.035,t)*(1.0-smoothstep(.22,.56,t));
        color=fs_hotColor(uColor,.85);
      }
      if(alpha<.005)discard;gl_FragColor=vec4(color,alpha);
    
    
  
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
vec4 vSeed = bridge_vSeed;
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vSeed, vUv);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
