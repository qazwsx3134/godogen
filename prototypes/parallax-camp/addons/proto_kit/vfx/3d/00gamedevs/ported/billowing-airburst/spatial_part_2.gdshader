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
#define VARIANT 11
#define TOON 1
uniform float uSize;
uniform float uTime;
uniform float uQuantity;
uniform vec4 uJetPaths[6];
uniform vec4 uJetBends[6];
uniform vec3 uBurstOffset;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;
varying float bridge_vHeat;
varying float bridge_vJet;
varying float bridge_vHot;


    
    
    
    float vs_hash3(vec3 p){p=fract(p*.3183099+vec3(.11,.17,.23));p*=17.0;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
    float vs_noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
      return mix(mix(mix(vs_hash3(i),vs_hash3(i+vec3(1,0,0)),f.x),mix(vs_hash3(i+vec3(0,1,0)),vs_hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(vs_hash3(i+vec3(0,0,1)),vs_hash3(i+vec3(1,0,1)),f.x),mix(vs_hash3(i+vec3(0,1,1)),vs_hash3(i+vec3(1,1,1)),f.x),f.y),f.z);}
    float vs_billow(vec3 p){return vs_noise3(p)*.65+vs_noise3(p*2.07+7.3)*.25+vs_noise3(p*4.11-3.1)*.10;}
    float vs_flameHeat(float age,float pattern){
      return 1.0-smoothstep(.26,.59,age+(.5-pattern)*.24);
    }
    vec3 vs_heatColor(vec3 base,float heat){
      vec3 flame=mix(base*vec3(1.25,.75,.45),vec3(1.0,.34,.025),.45);
      return mix(flame,vec3(1.0,.96,.79),smoothstep(.72,1.12,heat));
    }
  
    
    void vs_lobeMotion(float t,out vec3 center,out float swell,out float age, inout vec4 aData, inout vec4 aLobe){
      age=t;
      if(aData.y>=0.0){
        vec4 path=uJetPaths[int(aData.y)],bend=uJetBends[int(aData.y)];
        float u=aData.z;age=max(0.0,t-.025-bend.z-u*.11);
        float travel=(1.0-exp(-max(0.0,t-.045)*6.5))*path.w;
        vec3 d=path.xyz,side=normalize(cross(d,vec3(.13,1.0,.07))),up=normalize(cross(side,d));
        center=d*(.65+travel*u);
        center+=side*(sin(u*3.141593)*bend.x+aLobe.y)+up*(sin(u*3.7)*bend.y+aLobe.z);
        float drift=max(0.0,t-.65);
        center+=side*(aData.x-.5)*drift*.32+up*(aData.w-.5)*drift*.22;
        center.y+=drift*(.12+.14*u);
        swell=(1.0-exp(-age*30.0))*(1.0+min(t,.8)*.36)*bend.w;
      }else{
        float launch=1.0-exp(-t*19.0);
        float c=cos(t*.23),s=sin(t*.23);
        center=vec3(c*aLobe.x+s*aLobe.z,aLobe.y,-s*aLobe.x+c*aLobe.z)*launch;
        center*=1.0+min(t,.65)*.27;
        center.y+=max(0.0,t-.55)*(.14+aData.w*.16);
        center+=normalize(aLobe.xyz+vec3(.001))*smoothstep(.8,2.0,t)*.23;
        swell=launch*(1.0+min(t,.6)*.22);
      }
    }
  
    void vs_main(inout vec4 aData, inout vec4 aLobe, inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout float vHeat, inout float vHot, inout float vJet, inout vec2 vUv){
      vUv=uv;vJet=aData.y;vec3 center;float swell,age;vs_lobeMotion(uTime,center,swell,age, aData, aLobe);
      float heatAge=uTime-(aData.y>=0.0?aData.z*.22:0.0);
      float pattern=vs_billow(center*1.65+uBurstOffset+vec3(0,-uTime*.36,uTime*.12));
      vHot=vs_flameHeat(heatAge,pattern);
      float cooling=1.0-smoothstep(.40,1.08,heatAge);
      vHeat=(1.0-exp(-age*30.0))*(vHot+cooling*(1.0-vHot)*.30);
      if(aData.y>=uQuantity||age<=0.0)vHeat=0.0;
      
      
      if(vHeat*(vJet>=0.0?.085:.065)*1.5<.00199){gl_Position=vec4(2,2,2,1);return;}
      float bodyRadius=aLobe.w*swell*1.2;
      float radius=bodyRadius+(aData.y>=0.0?1.05:1.8)*min(1.0,swell);
      vec4 mv=modelViewMatrix*vec4(center*uSize,1.0);
      float scale=length(modelMatrix[1].xyz)*uSize;
      mv.xy+=position.xy*radius*scale;
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
  
    
    void fs_main(inout vec4 gl_FragColor, inout float vHeat, inout float vHot, inout float vJet, inout vec2 vUv){
      float r=length((vUv-.5)*2.0);
      if(r>=1.0)discard; 
      
      float softHalo=exp(-r*r*5.0)*.6+exp(-r*r*2.0)*.4;
      float alpha=softHalo*(1.0-smoothstep(.65,1.0,r));
      alpha*=vHeat*(vJet>=0.0?.085:.065)*1.5;
      if(alpha<.002)discard;
      vec3 tint=uColor;
      tint=mix(tint,vec3(1.0,.92,.68),vHot*exp(-r*r*8.0)*.30);
      gl_FragColor=vec4(tint,alpha);
    
    
  
    }
void vertex(){
vec4 aData = vec4(CUSTOM1.x,CUSTOM1.y,CUSTOM1.z,CUSTOM1.w);
vec4 aLobe = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
vec4 gl_Position = vec4(0);
mat4 modelMatrix = MODEL_MATRIX;
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
float vHeat = float(0);
float vHot = float(0);
float vJet = float(0);
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aData, aLobe, gl_Position, modelMatrix, modelViewMatrix, position, projectionMatrix, uv, vHeat, vHot, vJet, vUv);
bridge_vUv = vUv;
bridge_vHeat = vHeat;
bridge_vJet = vJet;
bridge_vHot = vHot;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vHeat = bridge_vHeat;
float vHot = bridge_vHot;
float vJet = bridge_vJet;
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vHeat, vHot, vJet, vUv);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
