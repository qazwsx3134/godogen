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
#define KIND 6
#define VARIANT 1
#define TOON 0
#define REND_GLOW 1
uniform float uSize;
uniform float uTime;
uniform float uQuantity;
uniform float uSpread;
uniform float uPanelCount;
uniform float uDetail;
uniform vec3 uColor;
varying float bridge_vEcho;
varying float bridge_vBand;
varying float bridge_vTaper;
varying float bridge_vAlong;
varying float bridge_vAlpha;
varying float bridge_vAge;
varying float bridge_vExit;
varying vec2 bridge_vUv;
varying vec4 bridge_vScreen;
varying vec2 bridge_vShift;


      const float vs_constant_REND_RELEASE=1.0; const float vs_constant_REND_EXIT=1.2;
      
      float vs_rh(float n){return fract(sin(n*127.1+32.36308927)*43758.5453);}
      float vs_rl(float i){return 1.35+vs_rh(i+71.0)*2.05;}
      float vs_rw(float i){return .036+vs_rh(i+89.0)*.024;}
      
      
      vec2 vs_rendPanel(float i,float x,float side){
        float taper=(1.0-x)*.5;
        float height=(vs_rw(i)*18.0+.18)*mix(.117,.5,vs_rh(i+151.0));
        float skew=mix(-.65,1.65,vs_rh(i+173.0));
        return vec2(x+side*taper*skew,side*taper*height);
      }
      float vs_rb(float i){return .2+.36*i/max(1.0,uQuantity-1.0);}
      mat3 vs_rf(float i){
        float a=i<.5?.38:vs_rh(i+109.0)*6.283185;
        float tilt=i<.5?.12:(vs_rh(i+93.0)-.5)*2.4,twist=(vs_rh(i+19.0)-.5)*2.6;
        vec3 d=normalize(vec3(cos(a),sin(a),tilt)),s=normalize(cross(vec3(0.0,0.0,1.0),d)),n=cross(d,s);
        s=s*cos(twist)+n*sin(twist);return mat3(d,s,cross(d,s));
      }
      vec3 vs_rc(float i){
        vec3 c=vec3(vs_rh(i+11.0)-.5,0.0,vs_rh(i+57.0)-.5)*vec3(3.6,0.0,2.8)*uSpread;
        if(i<.5)c.xz=vec2(0.0);
        
        
        c.y=abs(vs_rf(i)[0].y)*vs_rl(i)*uSize+(i<.5?.04*uSize:.10*uSize+vs_rh(i+31.0)*.45*uSpread);
        return c;
      }
      
      vec3 vs_rendPanelCenter(float i){
        vec3 c=vec3((vs_rh(i+211.0)-.5)*3.6,0.0,(vs_rh(i+239.0)-.5)*2.8)*uSpread;
        c.y=abs(vs_rf(i)[0].y)*vs_rl(i)*uSize+(.03+vs_rh(i+263.0)*.42)*uSize;
        return c;
      }
      
      float vs_rendShardScale(vec4 seed){
        return seed.w<.58?mix(.9,1.2,seed.z):mix(.2,.4,seed.z);
      }
      vec3 vs_rendShardShape(vec4 seed){
        float lengthScale=mix(.65,2.4,vs_rh(seed.x*997.0+307.0));
        float widthScale=mix(.2,1.4,vs_rh(seed.y*997.0+331.0));
        float apex=mix(-1.4,1.4,vs_rh(seed.z*997.0+359.0))*.577350269*lengthScale;
        return vec3(lengthScale,widthScale,apex);
      }
      
      
      vec3 vs_rendShardVertex(vec2 corner,vec3 shape,vec4 seed){
        float top=step(0.0,corner.y);
        float topWidth=seed.x<.5?0.0:mix(.35,1.1,vs_rh(seed.w*997.0+383.0));
        return vec3(corner.x*shape.x*mix(1.0,topWidth,top)+top*shape.z,corner.y*shape.y,0.0);
      }
      float vs_rendShardRadius(vec3 shape,vec4 seed){
        float h=.577350269;
        return max(max(length(vs_rendShardVertex(vec2(-h,-h),shape,seed)),length(vs_rendShardVertex(vec2(h,-h),shape,seed))),
          max(length(vs_rendShardVertex(vec2(h,h),shape,seed)),length(vs_rendShardVertex(vec2(-h,h),shape,seed))));
      }
      vec3 vs_rendCenter(){
        vec3 center=vec3(0.0);
        
        
        for(int j=0;j<32;j++){float index=uQuantity-1.0-float(j);if(index<0.0)break;center+=vs_rc(index);}
        return center/max(1.0,uQuantity);
      }
    
      
      void vs_main(inout vec4 aData, inout float aUnit, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout float vAge, inout float vAlong, inout float vAlpha, inout float vBand, inout float vEcho, inout float vExit, inout vec4 vScreen, inout vec2 vShift, inout float vTaper, inout vec2 vUv){
        float i=aUnit,localTime=uTime;vEcho=0.0;
        #if REND_GLOW == 1
          vEcho=aData.x;localTime-=vEcho*.12;
          
          if(vEcho>.5)localTime=min(localTime,vs_constant_REND_RELEASE+.10);
        #endif
        float age=localTime-vs_rb(i),sweep=smoothstep(0.0,.06,age),exitProgress=smoothstep(vs_constant_REND_RELEASE,vs_constant_REND_EXIT,localTime);
        float activeCount=uQuantity;
        #if REND_GLOW == 0
          activeCount=uPanelCount;age=uTime-(.2+.36*i/max(1.0,uPanelCount-1.0));sweep=smoothstep(0.0,.06,age);
        #endif
        float alive=step(i+.5,activeCount)*step(0.0,age)*(1.0-step(vs_constant_REND_EXIT,localTime));
        vUv=uv;vBand=position.y;vAlong=(position.x+1.0)*.5;vAge=age;vExit=exitProgress;vAlpha=alive;
        vec3 q=position;
        #if REND_GLOW == 1
          float guide=step(i+.5,uQuantity)*step(i,2.0)*smoothstep(.01,.10,uTime)*(1.0-smoothstep(.14,.2,uTime));
          guide*=1.0-step(.5,vEcho);
          vAlpha=max(alive,guide*.24);
          if(vEcho>.5){vAlpha*=smoothstep(.98,1.03,uTime)*.65;vExit=smoothstep(1.15,1.9,uTime);}
          if(age<0.0)sweep=1.0;
        #endif
        q.x=mix(-1.0,sweep*2.0-1.0,vAlong);
        float taper=pow(max(0.0,1.0-q.x*q.x),.7);
        
        
        float spatialTaper=(1.0-q.x)*.5;
        vBand=position.y*taper;vTaper=taper;
        #if REND_GLOW == 0
          vBand=(position.y+1.0)*spatialTaper;
        #endif
        mat3 frame=vs_rf(i);
        float anchor=frame[0].y>=0.0?-1.0:1.0;
        #if REND_GLOW == 0
          q.xy=vs_rendPanel(i,q.x,position.y+1.0);
        #endif
        q.x=(anchor+(q.x-anchor)*(1.0+.8*exitProgress))*vs_rl(i);
        #if REND_GLOW == 1
          q.yz*=vs_rw(i)*5.5*.375*taper;if(vEcho>.5)q.yz*=1.5;if(age<0.0)q.yz*=.10;
        #else
          q.z*=.008*spatialTaper;q*=2.0;
        #endif
        #if REND_GLOW == 1
          
          vec4 mv=modelViewMatrix*vec4(vs_rc(i)+(frame[0]*q.x)*uSize,1.0);
          vec3 direction=mat3(modelViewMatrix)*frame[0];vec2 across=normalize(vec2(-direction.y,direction.x)+vec2(.00001,0.0));
          mv.xy+=across*q.y*uSize*length(modelViewMatrix[1].xyz);gl_Position=projectionMatrix*mv;
        #else
          gl_Position=projectionMatrix*modelViewMatrix*vec4(vs_rendPanelCenter(i)+vs_rf(i)*q*uSize,1.0);
        #endif
        vScreen=gl_Position;vShift=(projectionMatrix*vec4(mat3(modelViewMatrix)*frame[0],0.0)).xy;
      }


      void fs_main(inout vec4 gl_FragColor, inout float vAlpha, inout float vBand, inout float vEcho, inout float vExit, inout float vTaper){if(vAlpha<.003)discard;float radial=abs(vBand)/max(.00001,vTaper)*5.5;
        float halo=(exp(-pow((radial-1.02)*1.3,2.0))*.60+exp(-pow((radial-1.0)*.53,2.0))*.16)*smoothstep(.73,1.10,radial);
        
        
        float distanceToBlade=abs(vBand)-(.65/5.5)*max(vTaper,0.0);
        float aa=clamp(fwidth(distanceToBlade),.0001,.5/5.5);
        float blade=(1.0-smoothstep(-aa,aa,distanceToBlade))*step(.001,vTaper);
        float alpha=max(halo*(.55+.45*uDetail),blade)*vAlpha*pow(1.0-vExit,vEcho>.5?1.0:2.0);
        vec3 color=mix(uColor,mix(uColor,vec3(1.0),vEcho>.5?.55:.88)*1.35,blade);
        if(alpha<.003)discard;gl_FragColor=vec4(color,alpha);
    
    
  
      }
void vertex(){
vec4 aData = vec4(CUSTOM0.w,CUSTOM1.x,CUSTOM1.y,CUSTOM1.z);
float aUnit = CUSTOM1.w;
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
float vAge = float(0);
float vAlong = float(0);
float vAlpha = float(0);
float vBand = float(0);
float vEcho = float(0);
float vExit = float(0);
vec4 vScreen = vec4(0);
vec2 vShift = vec2(0);
float vTaper = float(0);
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aData, aUnit, gl_Position, modelViewMatrix, position, projectionMatrix, uv, vAge, vAlong, vAlpha, vBand, vEcho, vExit, vScreen, vShift, vTaper, vUv);
bridge_vEcho = vEcho;
bridge_vBand = vBand;
bridge_vTaper = vTaper;
bridge_vAlong = vAlong;
bridge_vAlpha = vAlpha;
bridge_vAge = vAge;
bridge_vExit = vExit;
bridge_vUv = vUv;
bridge_vScreen = vScreen;
bridge_vShift = vShift;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vAlpha = bridge_vAlpha;
float vBand = bridge_vBand;
float vEcho = bridge_vEcho;
float vExit = bridge_vExit;
float vTaper = bridge_vTaper;
fs_main(gl_FragColor, vAlpha, vBand, vEcho, vExit, vTaper);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
