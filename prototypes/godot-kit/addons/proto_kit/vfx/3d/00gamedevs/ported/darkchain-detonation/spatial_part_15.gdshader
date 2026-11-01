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
#define KIND 2
#define VARIANT 14
#define TOON 0
uniform float uSize;
uniform float uJetTravel;
uniform float uJetFade;
uniform float uWarpKick;
uniform float uWarpFade;
uniform float uTime;
uniform float uChainTension;
uniform float uFlow;
uniform float uOrbRadius;
uniform float uBeat;
uniform float uOrbAlive;
uniform float uBlastRadius;
uniform float uWaveRadius;
uniform float uPressureGlow;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vPressureUV;
varying vec3 bridge_vPressureLocal;
varying float bridge_vPressureAge;

const float vs_constant_DC_coreReleaseRadius=0.286867;const float vs_constant_DC_releaseRadius=1.450000;const float vs_constant_vs_TAU=6.28318530718;const float vs_constant_DC_plasmaLife=0.140000;
const float vs_constant_DC_ejectionLife=0.500000;
const float vs_constant_DC_glintLife=0.500000;
const float vs_constant_DC_flareLife=0.075000;
const float vs_constant_DC_pressureLife=1.000000;
const float vs_constant_DC_compressionStart=3.470000;
const float vs_constant_DC_compressionScale=0.216667;
const float vs_constant_DC_coreFlashLife=0.060000;
const float vs_constant_DC_duration=5.150000;
const float vs_constant_DC_lowerRadius=2.300000;
const float vs_constant_DC_upperRadius=6.210000;
const float vs_constant_DC_baseY=0.040000;
const float vs_constant_DC_height=4.400000;
const float vs_constant_DC_centerY=2.240000;
const float vs_constant_DC_chains=12.000000;
const float vs_constant_DC_maxLinks=48.000000;
const float vs_constant_DC_chainStart=0.450000;
const float vs_constant_DC_chainEnd=0.850000;
const float vs_constant_DC_chainBend=1.050000;
const float vs_constant_DC_chainSettle=0.400000;
const float vs_constant_DC_orbStart=1.150000;
const float vs_constant_DC_burst=3.650000;
const float vs_constant_DC_settle=0.036000;
const float vs_constant_DC_attack=0.012000;
const float vs_constant_DC_overshoot=1.100000;
const float vs_constant_DC_restRadius=0.200000;
const float vs_constant_DC_blastRadius=4.200000;
const float vs_constant_DC_blastExpand=0.080000;
const float vs_constant_DC_breakTravel=0.120000;
const float vs_constant_DC_orbWarp=0.125000;
const float vs_constant_DC_blastPieces=252.000000;
const float vs_constant_DC_blastLife=1.300000;
const float vs_constant_DC_warpLife=1.500000;
const float vs_constant_DC_warpCycles=10.000000;
const float vs_constant_DC_warpPower=0.495000;
const float vs_constant_DC_warpRadius=4.200000;
const float vs_constant_DC_waveRadius=10.600000;
const float vs_constant_DC_waveWidth=4.300000;
const float vs_constant_DC_waveExpand=0.800000;
const float vs_constant_DC_waveLife=0.800000;
const float vs_constant_DC_waveHeight=0.180000;
const float vs_constant_DC_arcGroups=6.000000;
const float vs_constant_DC_arcLife=0.160000;
const float vs_constant_DC_fragmentScale=0.500000;
const float vs_constant_DC_fragmentImpulse=6.400000;
const float vs_constant_DC_fragmentSpread=0.600000;
const float vs_constant_DC_auraTrail=0.560000;
const float vs_constant_DC_inkTrail=0.840000;
const float vs_constant_DC_auraCount=16.000000;
const float vs_constant_DC_inkCount=12.000000;
const float vs_constant_DC_inkMinRadius=7.800000;
const float vs_constant_DC_inkRadius=10.100000;
const float vs_constant_DC_inkCoreRadius=0.720000;
const float vs_constant_DC_inkTurnsMin=1.000000;
const float vs_constant_DC_inkTurnsMax=2.000000;
const float vs_constant_DC_inkLead=0.180000;
const float vs_constant_DC_inkPullLead=0.280000;
const float vs_constant_DC_fieldArcs=36.000000;
const float vs_constant_DC_fieldLife=1.300000;
    float vs_hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
    float vs_noise21(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(vs_hash21(i),vs_hash21(i+vec2(1,0)),f.x),mix(vs_hash21(i+vec2(0,1)),vs_hash21(i+1.0),f.x),f.y);}
    float vs_mist(vec2 p){return vs_noise21(p)*.57+vs_noise21(p*2.07+3.1)*.29+vs_noise21(p*4.13-1.7)*.14;}
    float vs_charge(){return smoothstep(vs_constant_DC_orbStart,vs_constant_DC_burst,uTime);}
    float vs_hash31(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
    float vs_noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(vs_hash31(i),vs_hash31(i+vec3(1,0,0)),f.x),mix(vs_hash31(i+vec3(0,1,0)),vs_hash31(i+vec3(1,1,0)),f.x),f.y),mix(mix(vs_hash31(i+vec3(0,0,1)),vs_hash31(i+vec3(1,0,1)),f.x),mix(vs_hash31(i+vec3(0,1,1)),vs_hash31(i+vec3(1,1,1)),f.x),f.y),f.z);}
  
    
    
    float vs_pressureRadius(float t){
      if(t<.08){float q=clamp(t/.08,0.0,1.0);return mix(vs_constant_DC_coreReleaseRadius,4.2,1.0-pow(1.0-q,3.0));}
      float q=clamp((t-.08)/(vs_constant_DC_pressureLife-.08),0.0,1.0);return 4.2+.4*(1.0-(1.0-q)*(1.0-q));
    }
    vec3 vs_pressureRotate(vec3 p,vec4 q){return p+2.0*cross(q.xyz,cross(q.xyz,p)+q.w*p);}
  
    void vs_main(inout vec4 aPressureRotation, inout vec4 aPressureShape, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout mat4 projectionMatrix, inout vec2 uv, inout float vPressureAge, inout vec3 vPressureLocal, inout vec2 vPressureUV){float globalAge=uTime-vs_constant_DC_burst,age=max(0.0,globalAge-aPressureShape.w);
      float radius=vs_pressureRadius(age),catchup=smoothstep(.045,vs_constant_DC_pressureLife*.92,age);
      float inner=mix(vs_constant_DC_coreReleaseRadius*.28,radius-.10,catchup),u=uv.x,v=uv.y;
      float angle=(u-.5)*aPressureShape.y+aPressureShape.x;
      float latitude=(v-.5)*aPressureShape.z;
      float r=mix(inner,radius,v);
      vec3 direction=vec3(cos(angle)*cos(latitude),sin(latitude),sin(angle)*cos(latitude));
      vec3 local=vs_pressureRotate(direction*r,aPressureRotation);
      vPressureUV=uv;vPressureLocal=local;vPressureAge=globalAge-aPressureShape.w;
      
      if(uPressureGlow>.5)local=vs_pressureRotate(direction*(r+(v-.5)*.08),aPressureRotation);
      gl_Position=projectionMatrix*modelViewMatrix*vec4((local*1.12+vec3(0,vs_constant_DC_centerY,0))*uSize,1.0);}
  

const float fs_constant_DC_coreReleaseRadius=0.286867;const float fs_constant_DC_releaseRadius=1.450000;const float fs_constant_fs_TAU=6.28318530718;const float fs_constant_DC_plasmaLife=0.140000;
const float fs_constant_DC_ejectionLife=0.500000;
const float fs_constant_DC_glintLife=0.500000;
const float fs_constant_DC_flareLife=0.075000;
const float fs_constant_DC_pressureLife=1.000000;
const float fs_constant_DC_compressionStart=3.470000;
const float fs_constant_DC_compressionScale=0.216667;
const float fs_constant_DC_coreFlashLife=0.060000;
const float fs_constant_DC_duration=5.150000;
const float fs_constant_DC_lowerRadius=2.300000;
const float fs_constant_DC_upperRadius=6.210000;
const float fs_constant_DC_baseY=0.040000;
const float fs_constant_DC_height=4.400000;
const float fs_constant_DC_centerY=2.240000;
const float fs_constant_DC_chains=12.000000;
const float fs_constant_DC_maxLinks=48.000000;
const float fs_constant_DC_chainStart=0.450000;
const float fs_constant_DC_chainEnd=0.850000;
const float fs_constant_DC_chainBend=1.050000;
const float fs_constant_DC_chainSettle=0.400000;
const float fs_constant_DC_orbStart=1.150000;
const float fs_constant_DC_burst=3.650000;
const float fs_constant_DC_settle=0.036000;
const float fs_constant_DC_attack=0.012000;
const float fs_constant_DC_overshoot=1.100000;
const float fs_constant_DC_restRadius=0.200000;
const float fs_constant_DC_blastRadius=4.200000;
const float fs_constant_DC_blastExpand=0.080000;
const float fs_constant_DC_breakTravel=0.120000;
const float fs_constant_DC_orbWarp=0.125000;
const float fs_constant_DC_blastPieces=252.000000;
const float fs_constant_DC_blastLife=1.300000;
const float fs_constant_DC_warpLife=1.500000;
const float fs_constant_DC_warpCycles=10.000000;
const float fs_constant_DC_warpPower=0.495000;
const float fs_constant_DC_warpRadius=4.200000;
const float fs_constant_DC_waveRadius=10.600000;
const float fs_constant_DC_waveWidth=4.300000;
const float fs_constant_DC_waveExpand=0.800000;
const float fs_constant_DC_waveLife=0.800000;
const float fs_constant_DC_waveHeight=0.180000;
const float fs_constant_DC_arcGroups=6.000000;
const float fs_constant_DC_arcLife=0.160000;
const float fs_constant_DC_fragmentScale=0.500000;
const float fs_constant_DC_fragmentImpulse=6.400000;
const float fs_constant_DC_fragmentSpread=0.600000;
const float fs_constant_DC_auraTrail=0.560000;
const float fs_constant_DC_inkTrail=0.840000;
const float fs_constant_DC_auraCount=16.000000;
const float fs_constant_DC_inkCount=12.000000;
const float fs_constant_DC_inkMinRadius=7.800000;
const float fs_constant_DC_inkRadius=10.100000;
const float fs_constant_DC_inkCoreRadius=0.720000;
const float fs_constant_DC_inkTurnsMin=1.000000;
const float fs_constant_DC_inkTurnsMax=2.000000;
const float fs_constant_DC_inkLead=0.180000;
const float fs_constant_DC_inkPullLead=0.280000;
const float fs_constant_DC_fieldArcs=36.000000;
const float fs_constant_DC_fieldLife=1.300000;
    float fs_hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
    float fs_noise21(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(fs_hash21(i),fs_hash21(i+vec2(1,0)),f.x),mix(fs_hash21(i+vec2(0,1)),fs_hash21(i+1.0),f.x),f.y);}
    float fs_mist(vec2 p){return fs_noise21(p)*.57+fs_noise21(p*2.07+3.1)*.29+fs_noise21(p*4.13-1.7)*.14;}
    float fs_charge(){return smoothstep(fs_constant_DC_orbStart,fs_constant_DC_burst,uTime);}
    float fs_hash31(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
    float fs_noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(fs_hash31(i),fs_hash31(i+vec3(1,0,0)),f.x),mix(fs_hash31(i+vec3(0,1,0)),fs_hash31(i+vec3(1,1,0)),f.x),f.y),mix(mix(fs_hash31(i+vec3(0,0,1)),fs_hash31(i+vec3(1,0,1)),f.x),mix(fs_hash31(i+vec3(0,1,1)),fs_hash31(i+vec3(1,1,1)),f.x),f.y),f.z);}
  

    
    void fs_main(inout vec4 gl_FragColor, inout float vPressureAge, inout vec3 vPressureLocal, inout vec2 vPressureUV){float globalAge=uTime-fs_constant_DC_burst,t=vPressureAge;if(t<0.0||globalAge>=fs_constant_DC_pressureLife)discard;
      float u=vPressureUV.x,v=vPressureUV.y;
      
      vec3 flow=vPressureLocal*exp(-t*1.3);
      float coarse=fs_noise3(flow*1.05),grain=fs_noise3(flow*3.1);
      float erosion=smoothstep(.30,fs_constant_DC_pressureLife,globalAge);
      float holes=smoothstep(.31+erosion*.48,.53+erosion*.43,coarse*.8+grain*.2);
      float sideGrain=fs_noise3(vec3(u*7.0,v*.8-t*3.0,2.7));
      float sideCut=.08+(1.0-v)*.10+(grain-.5)*.12;
      float ends=smoothstep(sideCut,sideCut+.13,u)*(1.0-smoothstep(1.0-sideCut-.16,1.0-sideCut,u));
      ends*=smoothstep(.24,.55,sideGrain)*(1.0-smoothstep(.90+(grain-.5)*.10,1.0,v));
      float rim=.88+(grain-.5)*.10;
      float crest=exp(-pow((v-rim)/.065,2.0));
      float surface=smoothstep(0.0,.16,v)*(1.0-smoothstep(.84,1.0,v));
      float fade=pow(1.0-smoothstep(.18,fs_constant_DC_pressureLife,globalAge),1.15);
      float alpha=surface*.88*ends*holes*fade;
      vec3 energy=mix(uColor,vec3(.95,.002,.055),smoothstep(.25,.75,coarse));
      energy=pow(energy/max(max(energy.r,energy.g),max(energy.b,.001)),vec3(1.3));
      
      vec3 color=vec3(.00018,.00008,.00024);
      if(uPressureGlow>.5){alpha=crest*.35*ends*holes*fade*smoothstep(.65,.78,v)*(1.0-smoothstep(.92,1.0,v));color=energy*2.25;}
      if(alpha<.003)discard;gl_FragColor=vec4(color,alpha);
    
    
  }
  
void vertex(){
vec4 aPressureRotation = vec4(CUSTOM1.x,CUSTOM1.y,CUSTOM1.z,CUSTOM1.w);
vec4 aPressureShape = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
float vPressureAge = float(0);
vec3 vPressureLocal = vec3(0);
vec2 vPressureUV = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aPressureRotation, aPressureShape, gl_Position, modelViewMatrix, projectionMatrix, uv, vPressureAge, vPressureLocal, vPressureUV);
bridge_vPressureUV = vPressureUV;
bridge_vPressureLocal = vPressureLocal;
bridge_vPressureAge = vPressureAge;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vPressureAge = bridge_vPressureAge;
vec3 vPressureLocal = bridge_vPressureLocal;
vec2 vPressureUV = bridge_vPressureUV;
fs_main(gl_FragColor, vPressureAge, vPressureLocal, vPressureUV);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
