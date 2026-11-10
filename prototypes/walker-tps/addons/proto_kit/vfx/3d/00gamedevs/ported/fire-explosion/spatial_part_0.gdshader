// 00GameDevs MIT, 2026 @00vchannel; native Godot port of original GLSL.
// Authoring source: tools/vfx/three_port; Compatibility spatial, no fragment texture loops.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;
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
varying vec3 bridge_vLocal;
varying vec3 bridge_vNormal;
varying vec3 bridge_vView;
varying float bridge_vHeight;
varying float bridge_vSeed;


    
    
    
    float vs_hash3(vec3 p){p=fract(p*.3183099+vec3(.11,.17,.23));p*=17.0;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
    float vs_field3(vec3 p){
      vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
      return mix(mix(mix(vs_hash3(i),vs_hash3(i+vec3(1,0,0)),f.x),mix(vs_hash3(i+vec3(0,1,0)),vs_hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(vs_hash3(i+vec3(0,0,1)),vs_hash3(i+vec3(1,0,1)),f.x),mix(vs_hash3(i+vec3(0,1,1)),vs_hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
    }
    float vs_turbulence(vec3 p){return vs_field3(p)*.64+vs_field3(p*2.03+5.1)*.26+vs_field3(p*4.01-2.7)*.10;}
    vec3 vs_hotColor(vec3 base,float heat){
      vec3 flame=min(base*(1.2+max(0.0,heat)*3.0),vec3(1.0));
      return mix(flame,vec3(1.0,.97,.85),smoothstep(.75,1.10,heat));
    }
  
    vec3 vs_lobeSurface(vec3 point,float t,vec4 seed,mat3 roll){
      float wrinkle=vs_turbulence(point*2.5+seed.x*19.0+vec3(0.0,-t*.95,0.0));
      vec3 local=roll*point,shape=local*vec3(1.05,.88,1.0);
      shape.x+=local.y*local.y*(seed.y-.5)*.35;
      return shape*(.60+wrinkle*.88);
    }
    void vs_main(inout vec4 aLobe, inout vec4 aSeed, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 normal, inout mat3 normalMatrix, inout vec3 position, inout mat4 projectionMatrix, inout float vHeight, inout vec3 vLocal, inout vec3 vNormal, inout float vSeed, inout vec3 vView){
      float t=uTime,launch=1.0-exp(-t*56.0),spread=1.0-exp(-t*32.0);
      float turn=t*(.65+aSeed.x*.55)*(aSeed.z>.5?1.0:-1.0),c=cos(turn),s=sin(turn);
      mat3 roll=mat3(vec3(c,s,0.0),vec3(-s,c,0.0),vec3(0.0,0.0,1.0));
      vLocal=position;vSeed=aSeed.x;
      float swell=(.78+launch*.22)*(1.0+min(t,.9)*.19);
      vec3 center=aLobe.xyz*vec3(spread,launch,spread);
      center.xz*=1.0+min(t,.9)*.12;
      center.y+=max(0.0,t-.3)*(.48+aSeed.y*.4);
      vec3 surface=vs_lobeSurface(position,t,aSeed,roll);
      vec3 tangent=normalize(cross(normal,abs(normal.y)>.99?vec3(1,0,0):vec3(0,1,0))),bitangent=cross(normal,tangent);
      vec3 dx=vs_lobeSurface(normalize(position+tangent*.012),t,aSeed,roll)-surface;
      vec3 dy=vs_lobeSurface(normalize(position+bitangent*.012),t,aSeed,roll)-surface;
      vec3 p=center+surface*aLobe.w*swell;
      p.y=max(.025,p.y);vHeight=p.y;p*=uSize;p.y-=1.35;
      vec4 mv=modelViewMatrix*vec4(p,1.0);vView=mv.xyz;vNormal=normalMatrix*normalize(cross(dx,dy));
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
  
    void fs_main(inout vec4 gl_FragColor, inout float vHeight, inout vec3 vLocal, inout vec3 vNormal, inout float vSeed, inout vec3 vView){
      if(uTime<=0.0||uTime>=1.95)discard;
      vec3 flow=vLocal*2.5+vec3(vSeed*19.0,-uTime*.95,0.0);
      float broad=fs_turbulence(flow),grain=fs_field3(flow*3.4);
      
      
      float burn=smoothstep(.45,2.10,uTime)*.95+(1.0-smoothstep(.0,3.2,vHeight))*.40;
      if(broad+.19<burn)discard;
      vec3 n=normalize(vNormal),view=normalize(-vView);
      float rim=pow(1.0-max(0.0,dot(n,view)),2.4);
      float heat=1.20-uTime*1.9+(vHeight-1.2)*.30+rim*.65+(broad-.5)*.25+vSeed*.05;
      heat-=sin(clamp((uTime-.15)/.80,0.0,1.0)*3.141593)*.12;
      float flame=smoothstep(.32,.68,heat);
      float light=.45+.55*max(0.0,dot(n,normalize(vec3(-.35,.8,.5))));
      vec3 soot=mix(vec3(.003,.0035,.005),vec3(.022,.023,.028),light*(.65+broad*.35));
      soot*=.86+grain*.16*uDetail;
      vec3 color=mix(soot,fs_hotColor(uColor,heat),flame);
      color=mix(color,vec3(1.0,.98,.88),smoothstep(.96,1.23,heat));
      float edge=(1.0-smoothstep(.0,.045,broad+.19-burn))*step(.60,uTime)*(1.0-smoothstep(.65,1.05,uTime));
      color=mix(color,fs_hotColor(uColor,.55),edge*.6);
      gl_FragColor=vec4(color,1.0);
    
    
  
    }
void vertex(){
vec4 aLobe = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
vec4 aSeed = vec4(CUSTOM1.x,CUSTOM1.y,CUSTOM1.z,CUSTOM1.w);
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 normal = NORMAL;
mat3 normalMatrix = MODELVIEW_NORMAL_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
float vHeight = float(0);
vec3 vLocal = vec3(0);
vec3 vNormal = vec3(0);
float vSeed = float(0);
vec3 vView = vec3(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aLobe, aSeed, gl_Position, modelViewMatrix, normal, normalMatrix, position, projectionMatrix, vHeight, vLocal, vNormal, vSeed, vView);
bridge_vLocal = vLocal;
bridge_vNormal = vNormal;
bridge_vView = vView;
bridge_vHeight = vHeight;
bridge_vSeed = vSeed;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vHeight = bridge_vHeight;
vec3 vLocal = bridge_vLocal;
vec3 vNormal = bridge_vNormal;
float vSeed = bridge_vSeed;
vec3 vView = bridge_vView;
fs_main(gl_FragColor, vHeight, vLocal, vNormal, vSeed, vView);
ALBEDO = gl_FragColor.rgb; 
}
