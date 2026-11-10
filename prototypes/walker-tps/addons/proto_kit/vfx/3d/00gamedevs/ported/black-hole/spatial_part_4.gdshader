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
uniform sampler2D transmissionSamplerMap : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 transmissionSamplerSize;
varying vec3 bridge_vLensPoint;
varying vec3 bridge_vLensEye;
varying vec4 bridge_vDiskScreen;
varying vec4 bridge_vDiskCenterClip;
varying vec2 bridge_vDiskRadius;

    
    float vs_bhGrowth(){return smoothstep(0.0,1.0,uLifeStart)*(1.0-smoothstep(.05,1.0,uLifeEnd));}
    float vs_bhFade(){return smoothstep(0.0,.28,uLifeStart)*(1.0-smoothstep(.6,1.0,uLifeEnd));}
    vec3 vs_bhCenter(){return vec3(0.0,1.5,0.0)*uSize;}
  
    
    
    void vs_main(inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec4 vDiskCenterClip, inout vec2 vDiskRadius, inout vec4 vDiskScreen, inout vec3 vLensEye, inout vec3 vLensPoint){
      const vec3 vs_constant_axes=vec3(3.05,.58,3.05);
      float scale=uSize*max(.0001,vs_bhGrowth());
      vec3 eye=-modelViewMatrix[3].xyz;
      vec3 localEye=vec3(dot(eye,modelViewMatrix[0].xyz)/dot(modelViewMatrix[0].xyz,modelViewMatrix[0].xyz),
        dot(eye,modelViewMatrix[1].xyz)/dot(modelViewMatrix[1].xyz,modelViewMatrix[1].xyz),
        dot(eye,modelViewMatrix[2].xyz)/dot(modelViewMatrix[2].xyz,modelViewMatrix[2].xyz));
      vLensPoint=position/vs_constant_axes;vLensEye=(localEye-vs_bhCenter())/(vs_constant_axes*scale);
      vec4 center=modelViewMatrix*vec4(vs_bhCenter(),1.0);
      gl_Position=projectionMatrix*modelViewMatrix*vec4(vs_bhCenter()+position*scale,1.0);
      vDiskScreen=gl_Position;vDiskCenterClip=projectionMatrix*center;
      float projectedRadius=2.15*scale*length(modelViewMatrix[0].xyz)/max(.01,-center.z);
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
  
    vec2 fs_bhBackgroundOffset(vec2 uv,vec2 direction,float r,float spiral,float noise,vec2 radius,vec2 inset){
      const float fs_constant_BH_BACKGROUND_DISTORTION=5.0;
      vec2 tangent=vec2(-direction.y,direction.x);
      float bend=.48*pow(1.0-r,2.0)/max(r,.24);
      float shear=.045*sin(spiral*2.0+(noise-.5)*2.0)*pow(1.0-r,1.5);
      vec2 delta=(-direction*min(bend,.70)+tangent*shear)*fs_constant_BH_BACKGROUND_DISTORTION*radius*uDetail;
      float edge=max(0.0,min(min(uv.x-inset.x,1.0-inset.x-uv.x),min(uv.y-inset.y,1.0-inset.y-uv.y)));
      return delta*smoothstep(0.0,max(.015,length(delta)*1.25),edge);
    }
  
    
    
    void fs_main(inout vec4 gl_FragColor, inout vec4 vDiskCenterClip, inout vec2 vDiskRadius, inout vec4 vDiskScreen, inout vec3 vLensEye, inout vec3 vLensPoint){
      float fade=fs_bhFade();if(fade<.001||vDiskCenterClip.w<=0.0)discard;
      
      
      vec3 ray=normalize(vLensPoint-vLensEye);
      float r=clamp(length(cross(vLensPoint,ray)),0.0,1.0);
      float coverage=(1.0-smoothstep(.96,1.0,r))*fade;
      if(coverage<.001)discard;
      vec2 uv=vDiskScreen.xy/vDiskScreen.w*.5+.5;
      vec2 center=vDiskCenterClip.xy/vDiskCenterClip.w*.5+.5;
      vec2 radius=max(abs(vDiskRadius),vec2(.00001));
      vec2 q=(uv-center)/radius,direction=q/max(length(q),.0001);
      float angle=atan(q.y,q.x);
      float spiral=angle+2.6*log(r+.13)+uTime*.8;
      float noise=fs_bhFbm(vec2(cos(spiral),sin(spiral))*4.0+vec2(r*8.0+uTime*.9,r*3.0));
      
      
      float fieldDistance=mix(.25,.80,r*r);
      vec2 inset=.5/max(transmissionSamplerSize,vec2(1.0));
      vec2 delta=fs_bhBackgroundOffset(uv,direction,fieldDistance,spiral,noise,radius,inset)*.5*(1.0-smoothstep(.85,1.0,r));
      vec3 background=texture(transmissionSamplerMap,clamp(uv+delta,inset,1.0-inset)).rgb;
      gl_FragColor=vec4(background,coverage);
    
    
  
    }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec4 vDiskCenterClip = vec4(0);
vec2 vDiskRadius = vec2(0);
vec4 vDiskScreen = vec4(0);
vec3 vLensEye = vec3(0);
vec3 vLensPoint = vec3(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelViewMatrix, position, projectionMatrix, vDiskCenterClip, vDiskRadius, vDiskScreen, vLensEye, vLensPoint);
bridge_vLensPoint = vLensPoint;
bridge_vLensEye = vLensEye;
bridge_vDiskScreen = vDiskScreen;
bridge_vDiskCenterClip = vDiskCenterClip;
bridge_vDiskRadius = vDiskRadius;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
vec4 vDiskCenterClip = bridge_vDiskCenterClip;
vec2 vDiskRadius = bridge_vDiskRadius;
vec4 vDiskScreen = bridge_vDiskScreen;
vec3 vLensEye = bridge_vLensEye;
vec3 vLensPoint = bridge_vLensPoint;
fs_main(gl_FragColor, vDiskCenterClip, vDiskRadius, vDiskScreen, vLensEye, vLensPoint);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
