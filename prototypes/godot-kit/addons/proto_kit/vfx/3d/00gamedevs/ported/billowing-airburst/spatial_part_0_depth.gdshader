// 00GameDevs MIT, 2026 @00vchannel; native Godot port of original GLSL.
// Authoring source: tools/vfx/three_port; Compatibility spatial, no fragment texture loops.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, shadows_disabled, fog_disabled, blend_mix;
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
#define AIRBURST_JETS 0
uniform float uSize;
uniform float uTime;
uniform float uDetail;
uniform float uQuantity;
uniform vec4 uJetPaths[6];
uniform vec4 uJetBends[6];
uniform vec3 uBurstOffset;
uniform vec3 uColor;
varying vec3 bridge_vSurface;
varying vec3 bridge_vNormal;
varying vec3 bridge_vView;
varying float bridge_vSeed;
varying float bridge_vJet;
varying float bridge_vAlong;
varying float bridge_vAge;


    
    
    
    
    
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
  
    vec3 vs_surface(vec3 p,float t, inout vec4 aData){
      float turn=t*(.52+aData.w*.40),c=cos(turn),s=sin(turn);
      vec3 r=vec3(c*p.x+s*p.z,p.y,-s*p.x+c*p.z);
      float rolling=sin(r.x*3.1+t*.8+aData.x*6.0)*sin(r.y*3.4-t*.6+aData.w*5.0)*sin(r.z*2.6+t*.5);
      float broad=vs_noise3(r*2.1+uBurstOffset+vec3(0,-t*.25,0));
      float curls=pow(.5+.5*sin(r.x*5.0+t*.55+aData.x*7.0)*cos(r.y*4.0-t*.45)*sin(r.z*4.5+t*.3),2.0);
      float shape=1.0+rolling*(.08+.045*uDetail)+(broad-.5)*.14+curls*(.13+.055*uDetail);
      return r*shape;
    }
    void vs_main(inout vec4 aData, inout vec4 aLobe, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 normal, inout mat3 normalMatrix, inout vec3 position, inout mat4 projectionMatrix, inout float vAge, inout float vAlong, inout float vJet, inout vec3 vNormal, inout float vSeed, inout vec3 vSurface, inout vec3 vView){
      float t=uTime;vSeed=aData.x;vJet=aData.y;vAlong=aData.z;vAge=t;
      vec3 p=vs_surface(position,t, aData);
      vec3 tangent=normalize(cross(normal,abs(normal.y)>.98?vec3(1,0,0):vec3(0,1,0))),bitangent=cross(normal,tangent);
      vec3 dx=vs_surface(normalize(position+tangent*.012),t, aData)-p;
      vec3 dy=vs_surface(normalize(position+bitangent*.012),t, aData)-p;
      vec3 center;float swell,age;vs_lobeMotion(t,center,swell,age, aData, aLobe);vAge=age;
      vec3 localNormal=normalize(cross(dx,dy));
      #if AIRBURST_JETS == 1
        vec3 d=uJetPaths[int(aData.y)].xyz;p=d*dot(p,d)*1.24+(p-d*dot(p,d));
        localNormal-=d*dot(localNormal,d)*(1.0-1.0/1.24);
      #else
        p*=vec3(1.08,.94,1.0);localNormal/=vec3(1.08,.94,1.0);
      #endif
      p=center+p*aLobe.w*swell;
      vSurface=p;vNormal=normalize(normalMatrix*normalize(localNormal));
      vec4 mv=modelViewMatrix*vec4(p*uSize,1.0);vView=mv.xyz;
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
    float fs_noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
      return mix(mix(mix(fs_hash3(i),fs_hash3(i+vec3(1,0,0)),f.x),mix(fs_hash3(i+vec3(0,1,0)),fs_hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(fs_hash3(i+vec3(0,0,1)),fs_hash3(i+vec3(1,0,1)),f.x),mix(fs_hash3(i+vec3(0,1,1)),fs_hash3(i+vec3(1,1,1)),f.x),f.y),f.z);}
    float fs_billow(vec3 p){return fs_noise3(p)*.65+fs_noise3(p*2.07+7.3)*.25+fs_noise3(p*4.11-3.1)*.10;}
    float fs_flameHeat(float age,float pattern){
      return 1.0-smoothstep(.26,.59,age+(.5-pattern)*.24);
    }
    vec3 fs_heatColor(vec3 base,float heat){
      vec3 flame=mix(base*vec3(1.25,.75,.45),vec3(1.0,.34,.025),.45);
      return mix(flame,vec3(1.0,.96,.79),smoothstep(.72,1.12,heat));
    }
  
    void fs_main(inout vec4 gl_FragColor, inout float vAge, inout float vAlong, inout float vJet, inout vec3 vNormal, inout float vSeed, inout vec3 vSurface, inout vec3 vView, inout mat4 viewMatrix){
      if(uTime<=0.0||uTime>=2.4)discard;
      #if AIRBURST_JETS == 1
        if(vJet>=uQuantity||vAge<=.001)discard;
      #endif
      float t=uTime;
      vec3 flow=vSurface*1.65+uBurstOffset+vec3(0,-t*.36,t*.12);
      float broad=fs_billow(flow),fine=fs_noise3(flow*3.0);
      float localTime=t-vSeed*.14-vAlong*.08;
      float erosion=smoothstep(.72,2.16,localTime);
      float matter=broad*.72+fine*.12+.22;
      float edge=matter-erosion;
      float coverage=smoothstep(-.035,.065,edge);
      coverage*=1.0-smoothstep(1.8,2.4,t);
      if(coverage<.48)discard;
      vec3 n=normalize(vNormal),view=normalize(-vView);
      vec3 light=normalize(mat3(viewMatrix)*vec3(-.45,.8,.45));
      float diffuse=max(0.0,dot(n,light));
      float rim=pow(1.0-max(0.0,dot(n,view)),1.65);
      float heatAge=t;
      #if AIRBURST_JETS == 1
        heatAge=t-vAlong*.22;
      #endif
      float burn=fs_flameHeat(heatAge,broad);
      
      float hot=burn*(.78+(broad-.5)*1.0+rim*.17);
      float whiteHot=pow(smoothstep(.50,.94,hot),1.4);
      vec3 soot=mix(vec3(.0004,.00025,.00018),vec3(.008,.005,.003),pow(diffuse,1.1));
      soot*=.80+broad*.30;
      
      vec3 warmSurface=fs_heatColor(uColor,.50)*(.8+burn*1.6)*(.30+.70*diffuse)*0.5;
      vec3 hotEmission=vec3(1.0,.96,.79)*(1.0+burn*3.0)*0.5;
      vec3 thermalMix=vec3(whiteHot,whiteHot,pow(whiteHot,2.0));
      vec3 fire=mix(vec3(1.0)-exp(-warmSurface),vec3(1.0)-exp(-hotEmission),thermalMix);
      vec3 color=mix(soot,fire,smoothstep(.20,.72,burn));
      float residual=(1.0-smoothstep(.40,1.08,heatAge))*(1.0-burn);
      float seams=pow(smoothstep(.35,.72,broad),1.35);
      float hotEdges=(rim*1.35+pow(max(0.0,broad-.48)*2.0,3.0)*.45)*seams;
      vec3 edgeLight=fs_heatColor(uColor,.78+hotEdges*.28)*hotEdges*residual*1.5;
      color+=(vec3(1.0)-color)*(vec3(1.0)-exp(-edgeLight));
      
      gl_FragColor=vec4(color,1.0);
    
    
  
    }
  
void vertex(){
vec4 aData = vec4(CUSTOM1.x,CUSTOM1.y,CUSTOM1.z,CUSTOM1.w);
vec4 aLobe = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 normal = NORMAL;
mat3 normalMatrix = MODELVIEW_NORMAL_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
float vAge = float(0);
float vAlong = float(0);
float vJet = float(0);
vec3 vNormal = vec3(0);
float vSeed = float(0);
vec3 vSurface = vec3(0);
vec3 vView = vec3(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aData, aLobe, gl_Position, modelViewMatrix, normal, normalMatrix, position, projectionMatrix, vAge, vAlong, vJet, vNormal, vSeed, vSurface, vView);
bridge_vSurface = vSurface;
bridge_vNormal = vNormal;
bridge_vView = vView;
bridge_vSeed = vSeed;
bridge_vJet = vJet;
bridge_vAlong = vAlong;
bridge_vAge = vAge;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vAge = bridge_vAge;
float vAlong = bridge_vAlong;
float vJet = bridge_vJet;
vec3 vNormal = bridge_vNormal;
float vSeed = bridge_vSeed;
vec3 vSurface = bridge_vSurface;
vec3 vView = bridge_vView;
mat4 viewMatrix = VIEW_MATRIX;
fs_main(gl_FragColor, vAge, vAlong, vJet, vNormal, vSeed, vSurface, vView, viewMatrix);
ALBEDO = gl_FragColor.rgb; 
}
