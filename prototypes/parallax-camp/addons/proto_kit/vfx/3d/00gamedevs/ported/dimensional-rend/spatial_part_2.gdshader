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
uniform float uQuantity;
uniform float uSpread;
uniform float uPanelCount;
uniform float uDetail;
uniform sampler2D transmissionSamplerMap : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 transmissionSamplerSize;
uniform vec3 uColor;
varying float bridge_vAlpha;
varying float bridge_vTone;
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
    
      
      void vs_main(inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec4 seed, inout float vAlpha, inout vec4 vScreen, inout vec2 vShift, inout float vTone){
        float i=floor(seed.x*uQuantity),impulseAge=max(0.0,uTime-vs_constant_REND_RELEASE),kick=1.0-exp(-5.0*impulseAge);
        vTone=seed.w;vAlpha=smoothstep(0.0,.045,impulseAge)*(1.0-smoothstep(2.2+seed.z*.15,3.4,uTime));
        float shardScale=vs_rendShardScale(seed);
        vec3 shape=vs_rendShardShape(seed);
        vec3 q=vs_rendShardVertex(position.xy,shape,seed)*shardScale;
        float growth=1.0+.65*smoothstep(0.0,.10,impulseAge);q*=growth;
        float a=seed.y*6.283185+(seed.x<.5?-1.0:1.0)*(.7+.5*seed.z)*kick;
        q.xy=mat2(vec2(cos(a),-sin(a)),vec2(sin(a),cos(a)))*q.xy;
        mat3 frame=vs_rf(i);
        vec3 p=vs_rc(i)+frame*vec3((seed.y*2.0-1.0)*vs_rl(i),(seed.z-.5)*.15,(seed.w-.5)*.15)*uSize;
        
        
        float radius=vs_rendShardRadius(shape,seed)*shardScale*1.65;
        p.y=max(p.y,(.02+radius)*uSize);
        vec3 direction=p-vs_rendCenter();direction.y=max(0.0,direction.y);
        if(length(direction)<.01*uSize)direction=vec3(cos(seed.x*6.283185),0.0,sin(seed.x*6.283185));
        p+=normalize(direction)*2.2*uSize*kick;
        gl_Position=projectionMatrix*modelViewMatrix*vec4(p+frame*q*uSize,1.0);
        vScreen=gl_Position;vShift=(projectionMatrix*vec4(mat3(modelViewMatrix)*frame[0],0.0)).xy*(seed.w<.5?-1.0:1.0);
      }


      
      
      vec4 fs_displacedScene(float strength, inout vec4 vScreen, inout vec2 vShift){
        vec2 uv=vScreen.xy/vScreen.w*.5+.5;
        vec2 resolution=max(transmissionSamplerSize,vec2(1.0));
        vec2 direction=vShift*resolution;
        direction=length(direction)>.0001?normalize(direction):vec2(1.0,0.0);
        
        
        vec2 inset=.5/resolution;
        float edge=max(0.0,min(min(uv.x-inset.x,1.0-inset.x-uv.x),min(uv.y-inset.y,1.0-inset.y-uv.y)));
        float amount=.032*clamp(uDetail,.25,2.0)*strength;
        
        
        amount*=smoothstep(0.0,max(.08,abs(amount)*1.25),edge);
        vec2 delta=direction*min(resolution.x,resolution.y)/resolution*amount;
        return texture(transmissionSamplerMap,clamp(uv+delta,inset,1.0-inset));
      }
    
      
      void fs_main(inout vec4 gl_FragColor, inout float vAlpha, inout vec4 vScreen, inout vec2 vShift, inout float vTone){
        if(vAlpha<.003)discard;
        vec4 background=fs_displacedScene(5.0*(.65+.65*vTone)*vAlpha, vScreen, vShift);
        
        
        gl_FragColor=vec4(background.rgb,vAlpha*background.a);
    
    
  
      }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec4 seed = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
float vAlpha = float(0);
vec4 vScreen = vec4(0);
vec2 vShift = vec2(0);
float vTone = float(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelViewMatrix, position, projectionMatrix, seed, vAlpha, vScreen, vShift, vTone);
bridge_vAlpha = vAlpha;
bridge_vTone = vTone;
bridge_vScreen = vScreen;
bridge_vShift = vShift;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vAlpha = bridge_vAlpha;
vec4 vScreen = bridge_vScreen;
vec2 vShift = bridge_vShift;
float vTone = bridge_vTone;
fs_main(gl_FragColor, vAlpha, vScreen, vShift, vTone);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
