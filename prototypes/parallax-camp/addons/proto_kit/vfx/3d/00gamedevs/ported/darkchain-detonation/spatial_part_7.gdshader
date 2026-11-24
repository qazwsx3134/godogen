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
uniform vec4 uArcs[6];
uniform float uArcSeed;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;
varying float bridge_vAlpha;
varying float bridge_vFlash;
varying float bridge_vFork;

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
  
    vec3 vs_arcPoint(float u,float event,float fork, inout vec2 aArc){
      float seed=uArcSeed+aArc.x*19.0+event*13.0,longitude=aArc.x*vs_constant_vs_TAU/6.0+vs_hash21(vec2(seed,1))*.75,latitude=(vs_hash21(vec2(seed,2))-.5)*1.65;
      vec3 axis=vec3(cos(longitude)*cos(latitude),sin(latitude),sin(longitude)*cos(latitude)),side=normalize(cross(axis,vec3(0,1,0))),up=cross(side,axis);
      float tilt=vs_hash21(vec2(seed,3))*vs_constant_vs_TAU;vec3 along=side*cos(tilt)+up*sin(tilt),across=cross(along,axis);
      float v=mix(u,.5+u*.36,fork),k=v*12.0,index=floor(k),jitter=mix(vs_hash21(vec2(seed,index)),vs_hash21(vec2(seed,index+1.0)),fract(k))-.5;
      return normalize(axis+along*((v-.5)*1.40)+across*(jitter*.32*sin(v*3.14159265)+fork*u*.46));
    }
    void vs_main(inout vec2 aArc, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout float vAlpha, inout float vFlash, inout float vFork, inout vec2 vUv){vUv=uv;vec4 state=uArcs[int(aArc.x)];vAlpha=state.x;vFlash=state.z;vFork=aArc.y;
      if(vAlpha<.001){gl_Position=vec4(0,0,2,1);return;}
      float b=max(0.0,uTime-vs_constant_DC_burst),radius=uOrbRadius*(1.035+smoothstep(0.0,.16,b)*.58);
      vec3 center=vec3(0,vs_constant_DC_centerY,0);
      vec4 mv=modelViewMatrix*vec4((vs_arcPoint(uv.x,state.y,aArc.y, aArc)*radius+center)*uSize,1),a=modelViewMatrix*vec4((vs_arcPoint(min(1.0,uv.x+.005),state.y,aArc.y, aArc)*radius+center)*uSize,1),z=modelViewMatrix*vec4((vs_arcPoint(max(0.0,uv.x-.005),state.y,aArc.y, aArc)*radius+center)*uSize,1);
      vec2 tangent=normalize(a.xy-z.xy+vec2(.00001,0));float width=mix(.052,.024,aArc.y)*(.8+state.z*.7);
      mv.xy+=vec2(-tangent.y,tangent.x)*position.y*width*uSize*length(modelViewMatrix[0].xyz);gl_Position=projectionMatrix*mv;
    }

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
  

    void fs_main(inout vec4 gl_FragColor, inout float vAlpha, inout float vFlash, inout float vFork, inout vec2 vUv){float q=abs(vUv.y*2.0-1.0),tip=smoothstep(0.0,.06,vUv.x)*(1.0-smoothstep(.83,1.0,vUv.x));
      float alpha=(1.0-smoothstep(.42,1.0,q))*tip*vAlpha*mix(1.0,.7,vFork);if(alpha<.003)discard;
      vec3 color=mix(uColor,vec3(.94,.83,1),(.46+vFlash*.4)*(1.0-smoothstep(.12,.65,q)));
      gl_FragColor=vec4(color*(1.0+vFlash*.35),alpha);
    
    
  }
void vertex(){
vec2 aArc = vec2(CUSTOM0.x,CUSTOM0.y);
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
float vAlpha = float(0);
float vFlash = float(0);
float vFork = float(0);
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aArc, gl_Position, modelViewMatrix, position, projectionMatrix, uv, vAlpha, vFlash, vFork, vUv);
bridge_vUv = vUv;
bridge_vAlpha = vAlpha;
bridge_vFlash = vFlash;
bridge_vFork = vFork;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vAlpha = bridge_vAlpha;
float vFlash = bridge_vFlash;
float vFork = bridge_vFork;
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vAlpha, vFlash, vFork, vUv);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
