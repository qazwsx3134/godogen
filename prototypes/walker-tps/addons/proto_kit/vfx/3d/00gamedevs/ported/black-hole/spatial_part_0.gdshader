// 00GameDevs MIT, 2026 @00vchannel; native Godot port of original GLSL.
// Authoring source: tools/vfx/three_port; Compatibility spatial, no fragment texture loops.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled, blend_premul_alpha;
uniform mat4 source_to_group;
uniform float source_draw_start = 0.0;
uniform float source_draw_count = -1.0;
uniform int source_vertices_per_instance = 1;
uniform float source_instance_count = 1.0;
varying flat float source_draw;
varying flat float source_instance;
#define KIND 2
#define VARIANT 9
#define TOON 0
#define BH_FRONT 0
uniform float uSize;
uniform float uTime;
uniform float uLifeStart;
uniform float uLifeEnd;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vDisk;
varying vec3 bridge_vPoint;
varying vec3 bridge_vCenter;
varying vec4 bridge_vDiskScreen;
varying vec4 bridge_vDiskCenterClip;
varying vec2 bridge_vDiskRadius;


    
    float vs_bhGrowth(){return smoothstep(0.0,1.0,uLifeStart)*(1.0-smoothstep(.05,1.0,uLifeEnd));}
    float vs_bhFade(){return smoothstep(0.0,.28,uLifeStart)*(1.0-smoothstep(.6,1.0,uLifeEnd));}
    vec3 vs_bhCenter(){return vec3(0.0,1.5,0.0)*uSize;}
  
    float vs_bhHash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
    float vs_bhNoise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
      return mix(mix(vs_bhHash(i),vs_bhHash(i+vec2(1,0)),f.x),mix(vs_bhHash(i+vec2(0,1)),vs_bhHash(i+vec2(1,1)),f.x),f.y);}
    float vs_bhFbm(vec2 p){return vs_bhNoise(p)*.57+vs_bhNoise(p*2.03+17.0)*.28+vs_bhNoise(p*4.11-9.0)*.15;}
    vec3 vs_bhSpectrum(float t){return .5+.5*cos(6.283185*t+vec3(0.0,2.1,4.2));}
  
    
    
    void vs_main(inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec3 vCenter, inout vec2 vDisk, inout vec4 vDiskCenterClip, inout vec2 vDiskRadius, inout vec4 vDiskScreen, inout vec3 vPoint){
      vDisk=position.xy;float scale=uSize*max(.0001,vs_bhGrowth());
      float r=length(position.xy),a=atan(position.y,position.x),spin=uTime*.72;
      vec2 flow=vec2(cos(a-spin/(r+.25)),sin(a-spin/(r+.25)))*r;
      float n=vs_bhFbm(flow*2.7);
      
      
      float ringShape=.045*sin(a*3.0-uTime*.32)+.025*sin(a*5.0+uTime*.23)+.015*(n-.5);
      float radius=r*(1.0+ringShape);
      float twist=.10*sin(a*3.0+r*1.8-uTime*.35)/(r+.3);
      vec2 disk=vec2(cos(a+twist),sin(a+twist))*radius;
      float thickness=position.z*(.34+.08*n);
      float lift=.06*sin(a*3.0-r*2.0+uTime*.32)*smoothstep(.7,1.7,r);
      float height=(thickness+lift)*.125;
      vec3 q=vec3(disk.x,height,disk.y)*scale;
      vPoint=(modelViewMatrix*vec4(vs_bhCenter()+q,1.0)).xyz;
      vCenter=(modelViewMatrix*vec4(vs_bhCenter(),1.0)).xyz;
      gl_Position=projectionMatrix*vec4(vPoint,1.0);
      vDiskScreen=gl_Position;vDiskCenterClip=projectionMatrix*vec4(vCenter,1.0);
      float projectedRadius=2.15*scale*length(modelViewMatrix[0].xyz)/max(.01,-vCenter.z);
      vDiskRadius=vec2(projectionMatrix[0][0],projectionMatrix[1][1])*projectedRadius*.5;
    }


    
    float fs_bhGrowth(){return smoothstep(0.0,1.0,uLifeStart)*(1.0-smoothstep(.05,1.0,uLifeEnd));}
    float fs_bhFade(){return smoothstep(0.0,.28,uLifeStart)*(1.0-smoothstep(.6,1.0,uLifeEnd));}
    vec3 fs_bhCenter(){return vec3(0.0,1.5,0.0)*uSize;}
  
    float fs_bhHash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
    float fs_bhNoise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
      return mix(mix(fs_bhHash(i),fs_bhHash(i+vec2(1,0)),f.x),mix(fs_bhHash(i+vec2(0,1)),fs_bhHash(i+vec2(1,1)),f.x),f.y);}
    float fs_bhFbm(vec2 p){return fs_bhNoise(p)*.57+fs_bhNoise(p*2.03+17.0)*.28+fs_bhNoise(p*4.11-9.0)*.15;}
    vec3 fs_bhSpectrum(float t){return .5+.5*cos(6.283185*t+vec3(0.0,2.1,4.2));}
  
    
    
    vec3 fs_bhStrokeSeed(vec2 p){
      vec3 h=fract(vec3(p.xyx)*vec3(.1031,.1030,.0973));
      h+=dot(h,h.yxz+33.33);
      return fract((h.xxy+h.yzz)*h.zyx);
    }
    vec3 fs_bhBrushPaint(float r,float angle,float inner,float mask){
      float t=uTime*1.5;
      const float fs_constant_radialDensity=13.0;
      
      
      float flowRadius=r+t*.032;
      vec2 p=vec2((angle+log(flowRadius+.14)*1.6+t*mix(.8,-.8,inner))*16.0/6.283185,flowRadius*fs_constant_radialDensity);
      
      
      float pixel=max(length(vec2(dFdx(p.y),dFdy(p.y)))/fs_constant_radialDensity,.0003);
      
      if(mask<=0.0 && pixel<.005)return vec3(0.0);
      float wash=0.0,shade=0.0,scratch=0.0;
      
      
      for(int layer=0;layer<5;layer++){
        float field=float(layer);
        vec2 fieldPosition=p+vec2(field*1.37,field*.417);
        vec2 cell=floor(fieldPosition),local=fract(fieldPosition);
        for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
          vec2 offset=vec2(float(x),float(y));
          vec2 id=cell+offset;id.x=mod(id.x,16.0);
          id+=vec2(field*19.0,field*43.0);
          vec3 seed=fs_bhStrokeSeed(id),shape=fs_bhStrokeSeed(id+vec2(37.0,71.0));
          
          if(shape.z<.28)continue;
          vec2 d=local-offset-seed.xy;
          float halfLength=mix(.07,.94,shape.x*shape.x);
          float u=d.x/halfLength;
          if(abs(u)>1.0)continue;
          
          
          float direction=mix(-1.0,1.0,inner);
          float pitch=-direction*mix(.009,.015,shape.y);
          float cross=d.y/fs_constant_radialDensity-d.x*pitch;
          
          if(abs(cross)>.006+pixel*.5)continue;
          float alongFlow=u*direction;
          float taper=pow(max(0.0,1.0-abs(u)),.65)*(1.0-.35*max(0.0,alongFlow));
          float width=mix(.0022,.006,seed.z*seed.z)*taper;
          
          
          float grain=.82+.18*sin(u*16.0+shape.y*23.0)*sin(u*7.0+seed.z*31.0);
          float edge=abs(cross)-width*grain;
          float coverage=(1.0-smoothstep(-pixel*.5,pixel*.5,edge))*step(abs(u),1.0);
          coverage*=step(.28,shape.z);
          float split=abs(cross-width*.34)-width*.11;
          float dryGap=mix(1.0,smoothstep(-pixel*.22,pixel*.22,split),step(.68,seed.x));
          coverage*=dryGap;
          float pigment=.15+.55*seed.z+.12*sin(u*4.0+seed.x*9.0);
          if(coverage>wash){wash=coverage;shade=pigment;}
          scratch=max(scratch,coverage*step(.78,seed.y));
        }
      }
      return vec3(wash,shade,scratch);
    }
  
    
    void fs_main(inout vec4 gl_FragColor, inout vec3 vCenter, inout vec2 vDisk, inout vec3 vPoint){
      float nearSide=dot(vPoint-vCenter,normalize(-vCenter));
      
      
      float frontWeight=smoothstep(-.45*uSize,.45*uSize,nearSide);
      #if BH_FRONT == 1
        float layerWeight=frontWeight;
      #else
        float layerWeight=1.0-frontWeight;
      #endif
      if(layerWeight<.0001)discard;
      float r=length(vDisk),a=atan(vDisk.y,vDisk.x),spin=uTime*.9;
      
      
      float advected=a+log(r+.12)*2.4+spin;
      vec2 flow=vec2(cos(advected),sin(advected))*vec2(3.0,3.0);
      float n=fs_bhFbm(flow+vec2(r*4.0+uTime*1.15,r*1.5)),large=fs_bhFbm(flow*.55+r);
      float warped=r+5.0*((n-.5)*.055+sin(a*5.0-r*3.0+spin)*.016);
      float phase=advected*3.0+(n-.5)*3.0;
      float bands=pow(.5+.5*sin(phase),2.5);
      float fine=smoothstep(.38,.64,n);
      float envelope=smoothstep(.65,.88,r)*(1.0-smoothstep(2.05+large*.3,2.65,r));
      float torn=smoothstep(.12,.65,n)*(.3+.7*large);
      float hot=bands*(.55+.45*n);
      vec3 spectrum=fs_bhSpectrum(warped*1.8+large*.7);
      vec3 color=mix(vec3(.02,.10,.9),spectrum*1.8,.7);
      color=mix(color,uColor,.18);
      color=mix(color,vec3(1.0,.97,.94)*2.8,smoothstep(.32,.82,hot));
      
      vec3 brush=fs_bhBrushPaint(r/2.15,a,0.0,1.0);
      float ink=brush.z;
      float outerWeight=smoothstep(.68,.88,r);
      color*=mix(.55,1.0,step(.48,hot));

      float alpha=envelope*(.24+bands*.88+fine*.16)*torn*fs_bhFade();
      if(alpha<.002)discard;
      
      
      float inkCoverage=ink*outerWeight*envelope*fs_bhFade()*.98;
      vec3 emission=color*2.4*uDetail*min(1.0,alpha)*(1.0-ink*outerWeight);
      
      
      emission/=1.0+max(emission.r,max(emission.g,emission.b))*1.2;
      float wash=brush.x*outerWeight*envelope*fs_bhFade();
      vec3 pigment=mix(vec3(.008,.018,.055),mix(spectrum*.32,vec3(.08,.25,.40),.55),brush.y);
      
      emission=mix(emission,pigment*(.75+.25*uDetail),wash)*(1.0-ink*outerWeight);
      inkCoverage=max(inkCoverage,wash*.98);
      emission*=layerWeight;inkCoverage*=layerWeight;
      gl_FragColor=vec4(emission+vec3(.002,.004,.012)*inkCoverage,inkCoverage);
    
    
  
    }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec3 vCenter = vec3(0);
vec2 vDisk = vec2(0);
vec4 vDiskCenterClip = vec4(0);
vec2 vDiskRadius = vec2(0);
vec4 vDiskScreen = vec4(0);
vec3 vPoint = vec3(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelViewMatrix, position, projectionMatrix, vCenter, vDisk, vDiskCenterClip, vDiskRadius, vDiskScreen, vPoint);
bridge_vDisk = vDisk;
bridge_vPoint = vPoint;
bridge_vCenter = vCenter;
bridge_vDiskScreen = vDiskScreen;
bridge_vDiskCenterClip = vDiskCenterClip;
bridge_vDiskRadius = vDiskRadius;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
vec3 vCenter = bridge_vCenter;
vec2 vDisk = bridge_vDisk;
vec3 vPoint = bridge_vPoint;
fs_main(gl_FragColor, vCenter, vDisk, vPoint);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
