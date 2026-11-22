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
#define STANDARD 
#define PHYSICAL 
uniform float uSize;
uniform float uTime;
uniform float uLifeStart;
uniform float uLifeEnd;
uniform float uDetail;
uniform vec3 uColor;
uniform sampler2D transmissionSamplerMap : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 transmissionSamplerSize;
varying vec4 bridge_vScreen;
varying vec4 bridge_vCenterClip;
varying vec2 bridge_vRadius;
varying float bridge_vLensInclination;

    
    float vs_bhGrowth(){return smoothstep(0.0,1.0,uLifeStart)*(1.0-smoothstep(.05,1.0,uLifeEnd));}
    float vs_bhFade(){return smoothstep(0.0,.28,uLifeStart)*(1.0-smoothstep(.6,1.0,uLifeEnd));}
    vec3 vs_bhCenter(){return vec3(0.0,1.5,0.0)*uSize;}
  
    
    void vs_main(inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec4 vCenterClip, inout float vLensInclination, inout vec2 vRadius, inout vec4 vScreen){
      float radius=2.15*uSize*max(.0001,vs_bhGrowth());
      vec4 center=modelViewMatrix*vec4(vs_bhCenter(),1.0);
      vec4 p=modelViewMatrix*vec4(vs_bhCenter()+position*radius,1.0);
      vLensInclination=abs(dot(normalize(-center.xyz),normalize(modelViewMatrix[1].xyz)));
      vCenterClip=projectionMatrix*center;
      float worldScale=length(modelViewMatrix[0].xyz);
      float projectedRadius=radius*worldScale/max(.01,-center.z);
      vRadius=vec2(projectionMatrix[0][0],projectionMatrix[1][1])*projectedRadius*.5;
      gl_Position=projectionMatrix*p;vScreen=gl_Position;
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
  
    vec2 fs_bhBackgroundOffset(vec2 uv,vec2 direction,float r,float spiral,float noise,vec2 radius,vec2 inset){
      const float fs_constant_BH_BACKGROUND_DISTORTION=5.0;
      vec2 tangent=vec2(-direction.y,direction.x);
      float bend=.48*pow(1.0-r,2.0)/max(r,.24);
      float shear=.045*sin(spiral*2.0+(noise-.5)*2.0)*pow(1.0-r,1.5);
      vec2 delta=(-direction*min(bend,.70)+tangent*shear)*fs_constant_BH_BACKGROUND_DISTORTION*radius*uDetail;
      float edge=max(0.0,min(min(uv.x-inset.x,1.0-inset.x-uv.x),min(uv.y-inset.y,1.0-inset.y-uv.y)));
      return delta*smoothstep(0.0,max(.015,length(delta)*1.25),edge);
    }
  
    float fs_bhHaloShape(float angle){
      float shapeNoise=fs_bhFbm(vec2(cos(angle-uTime*.16),sin(angle-uTime*.16))*3.0);
      return .045*sin(angle*3.0-uTime*.32)+.008*sin(angle*5.0+uTime*.23)+.005*(shapeNoise-.5);
    }
    vec2 fs_bhJoinPoint(float t,vec2 end){
      vec2 a=vec2(.97,.0),b=vec2(.77,.0),c=end+vec2(.16,-.18);
      float u=1.0-t;
      return u*u*u*a+3.0*u*u*t*b+3.0*u*t*t*c+t*t*t*end;
    }
    float fs_bhJunction(vec2 q,float overhead){
      if(q.y<-.04||abs(q.x)<.30||overhead>=.999)return 0.0;
      float angle=q.x>0.0?.82:3.141593-.82;
      vec2 end=vec2(abs(cos(angle)),sin(angle))*.58*(1.0+fs_bhHaloShape(angle));
      vec2 p=vec2(abs(q.x),q.y),last=fs_bhJoinPoint(0.0,end);
      float distance=10.0,along=0.0;
      for(int i=1;i<=12;i++){
        float t=float(i)/12.0;vec2 next=fs_bhJoinPoint(t,end),d=next-last;
        float h=clamp(dot(p-last,d)/max(dot(d,d),.000001),0.0,1.0);
        float candidate=length(p-last-d*h);
        if(candidate<distance){distance=candidate;along=(float(i)-1.0+h)/12.0;}
        last=next;
      }
      float width=mix(.018,.012,along),aa=max(fwidth(q.x),fwidth(q.y));
      float mask=1.0-smoothstep(width*.35,width+aa,distance);
      mask*=smoothstep(0.0,.12,along)*(1.0-smoothstep(.80,1.0,along));
      return mask*(.55+.45*pow(.5+.5*sin(along*24.0-uTime*1.2),2.0))*(1.0-overhead);
    }
  
    
    
    void fs_main(inout vec4 gl_FragColor, inout vec4 vCenterClip, inout float vLensInclination, inout vec2 vRadius, inout vec4 vScreen){
      float fade=fs_bhFade();if(fade<.001||vCenterClip.w<=0.0)discard;
      vec2 uv=vScreen.xy/vScreen.w*.5+.5,center=vCenterClip.xy/vCenterClip.w*.5+.5;
      vec2 radius=max(abs(vRadius),vec2(.00001));vec2 q=(uv-center)/radius;
      float r=length(q);if(r>=1.0)discard;
      float angle=atan(q.y,q.x),spin=uTime*.8;
      vec2 direction=q/max(r,.0001);
      float spiral=angle+2.6*log(r+.13)+spin;
      vec2 flow=vec2(cos(spiral),sin(spiral));
      float n=fs_bhFbm(flow*4.0+vec2(r*8.0+uTime*.9,r*3.0));
      float large=fs_bhFbm(vec2(cos(angle-spin*.4),sin(angle-spin*.4))*3.0);
      
      
      float ringShape=fs_bhHaloShape(angle);
      float warped=r/(1.0+ringShape);
      vec2 inset=.5/max(transmissionSamplerSize,vec2(1.0));
      vec2 delta=fs_bhBackgroundOffset(uv,direction,r,spiral,n,radius,inset);
      vec3 background=texture(transmissionSamplerMap,clamp(uv+delta,inset,1.0-inset)).rgb;
      float aa=max(fwidth(r),.0005),horizon=1.0-smoothstep(.275-aa,.275+aa,r);
      vec3 color=mix(background,vec3(0.0),horizon);
      float stream=pow(.5+.5*sin(spiral*3.0+(n-.5)*2.6),3.0);
      float corona=exp(-pow((warped-.50)/(.065+large*.02),2.0));
      
      float filaments=.65+.35*stream;
      float continuity=.55+.45*stream;
      float inner=exp(-pow((warped-.35)/.016,2.0))*continuity;
      float fringe=exp(-pow((warped-.58)/.055,2.0))*continuity;
      vec3 cool=vec3(.018,.075,1.0),spectrum=fs_bhSpectrum(warped*9.0+large*.8+n*.4);
      vec3 energy=vec3(1.0,.98,.96)*corona*filaments*continuity*(1.4+large);
      energy+=spectrum*fringe*1.9;
      energy+=cool*(exp(-abs(warped-.51)*8.0)*.38+exp(-abs(warped-.30)*38.0)*.24)*(.4+.6*stream);
      energy+=mix(uColor,vec3(1.0),.8)*inner*1.6;
      float stableRim=exp(-pow((r-.284)/max(.0018,aa*.65),2.0));
      const float fs_constant_BH_COLOR_JOIN=1.0;
      float junction=fs_bhJunction(q,smoothstep(.40,.92,vLensInclination))*fs_constant_BH_COLOR_JOIN;
      vec3 joiningLight=mix(spectrum,uColor,.08)*junction*1.1;
      vec3 glow=(energy+joiningLight)*uDetail;
      glow/=1.0+max(glow.r,max(glow.g,glow.b))*1.2;
      color+=glow*smoothstep(.287,.32,r);
      color+=mix(uColor,vec3(1.0),.8)*stableRim*1.3*uDetail*(1.0-horizon);
      
      
      float brushZone=smoothstep(.30,.34,r)*(1.0-smoothstep(.60,.68,warped));
      vec3 haloBrush=fs_bhBrushPaint(r,angle,1.0,brushZone);
      vec3 pigment=mix(vec3(.008,.018,.055),mix(spectrum*.32,vec3(.08,.25,.40),.55),haloBrush.y);
      color=mix(color,pigment*(.75+.25*uDetail),haloBrush.x*brushZone);
      float innerInk=haloBrush.z*brushZone;
      color=mix(color,vec3(.002,.004,.012),innerInk*.98);
      float alpha=fade*(1.0-smoothstep(.91,1.0,r));
      gl_FragColor=vec4(color,alpha);
    
    
  
    }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec4 vCenterClip = vec4(0);
float vLensInclination = float(0);
vec2 vRadius = vec2(0);
vec4 vScreen = vec4(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelViewMatrix, position, projectionMatrix, vCenterClip, vLensInclination, vRadius, vScreen);
bridge_vScreen = vScreen;
bridge_vCenterClip = vCenterClip;
bridge_vRadius = vRadius;
bridge_vLensInclination = vLensInclination;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
vec4 vCenterClip = bridge_vCenterClip;
float vLensInclination = bridge_vLensInclination;
vec2 vRadius = bridge_vRadius;
vec4 vScreen = bridge_vScreen;
fs_main(gl_FragColor, vCenterClip, vLensInclination, vRadius, vScreen);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
