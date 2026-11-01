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
#define KIND 2
#define VARIANT 9
#define TOON 0
uniform float uSize;
uniform float uTime;
uniform float uLifeStart;
uniform float uLifeEnd;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;
varying float bridge_vAlpha;
varying vec4 bridge_vParticleScreen;
varying vec4 bridge_vParticleCenter;
varying vec2 bridge_vParticleRadius;


    
    float vs_bhGrowth(){return smoothstep(0.0,1.0,uLifeStart)*(1.0-smoothstep(.05,1.0,uLifeEnd));}
    float vs_bhFade(){return smoothstep(0.0,.28,uLifeStart)*(1.0-smoothstep(.6,1.0,uLifeEnd));}
    vec3 vs_bhCenter(){return vec3(0.0,1.5,0.0)*uSize;}
  
    
    
    
    
    vec3 vs_bhParticlePath(float age,vec3 right,vec3 toward,float overhead, inout vec4 seed){
      float a=age*6.283185;
      float r=mix(2.65+seed.y*.30,.38,smoothstep(.48,1.0,age));
      float rear=max(0.0,sin(a));
      float hemisphere=seed.z<.5?-1.0:1.0;
      float lift=pow(rear,1.35)*r*.52*hemisphere;
      float depth=-sin(a)*r*mix(1.0,.18,smoothstep(0.0,.35,rear));
      vec3 arch=right*(-cos(a)*r*mix(1.0,.72,smoothstep(0.0,.75,rear)))+toward*depth+vec3(0.0,lift+(seed.z-.5)*.07*(1.0-age),0.0);
      float rimRadius=2.45+seed.y*.15;
      
      
      vec3 rim=right*(-cos(a)*rimRadius)+toward*(-sin(a)*rimRadius)+vec3(0.0,(seed.z-.5)*.025,0.0);
      return mix(arch,rim,overhead);
    }
    void vs_main(inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec4 seed, inout vec2 uv, inout float vAlpha, inout vec4 vParticleCenter, inout vec2 vParticleRadius, inout vec4 vParticleScreen, inout vec2 vUv){
      float age=fract(seed.x+uTime*(.11+seed.w*.04));
      float scale=uSize*max(.0001,vs_bhGrowth());
      vec3 eye=-modelViewMatrix[3].xyz;
      vec3 localEye=vec3(dot(eye,modelViewMatrix[0].xyz)/dot(modelViewMatrix[0].xyz,modelViewMatrix[0].xyz),
        dot(eye,modelViewMatrix[1].xyz)/dot(modelViewMatrix[1].xyz,modelViewMatrix[1].xyz),
        dot(eye,modelViewMatrix[2].xyz)/dot(modelViewMatrix[2].xyz,modelViewMatrix[2].xyz));
      vec3 viewOffset=localEye-vs_bhCenter();
      float overhead=smoothstep(.40,.92,abs(viewOffset.y)/max(length(viewOffset),.0001));
      
      
      vec3 right=vec3(modelViewMatrix[0].x/dot(modelViewMatrix[0].xyz,modelViewMatrix[0].xyz),0.0,
        modelViewMatrix[2].x/dot(modelViewMatrix[2].xyz,modelViewMatrix[2].xyz));
      right=length(right)>.0001?normalize(right):vec3(1.0,0.0,0.0);
      vec3 toward=vec3(-right.z,0.0,right.x);
      vec3 q=vs_bhParticlePath(age,right,toward,overhead, seed);
      vec3 tangent=vs_bhParticlePath(min(.9999,age+.001),right,toward,overhead, seed)-vs_bhParticlePath(max(0.0,age-.001),right,toward,overhead, seed);
      vec4 mv=modelViewMatrix*vec4(vs_bhCenter()+q*scale,1.0);
      vec2 along=normalize((modelViewMatrix*vec4(tangent,0.0)).xy+vec2(.00001));
      mv.xy+=(along*position.x*(.035+.125*seed.w)+vec2(-along.y,along.x)*position.y*.007)*scale*length(modelViewMatrix[0].xyz);
      vUv=uv;vAlpha=smoothstep(0.0,.07,age)*(1.0-smoothstep(.94,1.0,age))*vs_bhFade();
      gl_Position=projectionMatrix*mv;vParticleScreen=gl_Position;
      vec4 center=modelViewMatrix*vec4(vs_bhCenter(),1.0);vParticleCenter=projectionMatrix*center;
      float projectedRadius=2.15*scale*length(modelViewMatrix[0].xyz)/max(.01,-center.z);
      vParticleRadius=vec2(projectionMatrix[0][0],projectionMatrix[1][1])*projectedRadius*.5;
    }


    
    float fs_bhGrowth(){return smoothstep(0.0,1.0,uLifeStart)*(1.0-smoothstep(.05,1.0,uLifeEnd));}
    float fs_bhFade(){return smoothstep(0.0,.28,uLifeStart)*(1.0-smoothstep(.6,1.0,uLifeEnd));}
    vec3 fs_bhCenter(){return vec3(0.0,1.5,0.0)*uSize;}
  
    
    
    void fs_main(inout vec4 gl_FragColor, inout float vAlpha, inout vec4 vParticleCenter, inout vec2 vParticleRadius, inout vec4 vParticleScreen, inout vec2 vUv){vec2 q=vUv*2.0-1.0;float glow=exp(-dot(q,q)*5.0)*(1.0-smoothstep(.5,1.0,length(q)));
      vec2 screen=vParticleScreen.xy/vParticleScreen.w*.5+.5;
      vec2 center=vParticleCenter.xy/vParticleCenter.w*.5+.5;
      float coreRadius=length((screen-center)/max(abs(vParticleRadius),vec2(.00001)));
      float alpha=min(1.0,glow*2.0)*vAlpha*smoothstep(.285,.31,coreRadius);if(alpha<.002)discard;
      gl_FragColor=vec4(vec3(1.6)*uDetail,alpha);
    
    
  
    }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec4 seed = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
vec2 uv = UV;
float vAlpha = float(0);
vec4 vParticleCenter = vec4(0);
vec2 vParticleRadius = vec2(0);
vec4 vParticleScreen = vec4(0);
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelViewMatrix, position, projectionMatrix, seed, uv, vAlpha, vParticleCenter, vParticleRadius, vParticleScreen, vUv);
bridge_vUv = vUv;
bridge_vAlpha = vAlpha;
bridge_vParticleScreen = vParticleScreen;
bridge_vParticleCenter = vParticleCenter;
bridge_vParticleRadius = vParticleRadius;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vAlpha = bridge_vAlpha;
vec4 vParticleCenter = bridge_vParticleCenter;
vec2 vParticleRadius = bridge_vParticleRadius;
vec4 vParticleScreen = bridge_vParticleScreen;
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vAlpha, vParticleCenter, vParticleRadius, vParticleScreen, vUv);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
