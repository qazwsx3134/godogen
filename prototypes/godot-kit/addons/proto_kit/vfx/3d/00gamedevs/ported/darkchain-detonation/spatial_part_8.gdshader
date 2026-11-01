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
uniform vec4 uField[36];
uniform float uFieldSeed;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;
varying float bridge_vAlpha;
varying float bridge_vFieldRed;

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
  
    vec3 vs_fieldPoint(float u,float event,float fork, inout vec2 aField){
      vec3 point=vec3(0.0);
      float seed=uFieldSeed+aField.x*31.7+event*17.3,angle=(aField.x+.5)*vs_constant_vs_TAU/vs_constant_DC_fieldArcs+(vs_hash21(vec2(seed,1))-.5)*.36;
      if(uTime>=vs_constant_DC_burst){
        float latitude=1.0-2.0*(aField.x+.5)/vs_constant_DC_fieldArcs,longitude=aField.x*2.39996323;
        vec3 direction=vec3(cos(longitude)*sqrt(1.0-latitude*latitude),latitude,sin(longitude)*sqrt(1.0-latitude*latitude));
        vec3 side=normalize(cross(direction,vec3(0,1,0))),up=cross(side,direction);
        float v=mix(u,.38+u*.52,fork),k=v*6.0,j=floor(k),age=max(0.0,uTime-vs_constant_DC_burst);
        float jitter=mix(vs_hash21(vec2(seed,j)),vs_hash21(vec2(seed,j+1.0)),fract(k))-.5;
        float distance=3.1+vs_hash21(vec2(aField.x,uFieldSeed)) *2.05,reach=mix(1.6,distance,1.0-pow(1.0-clamp(age/.10,0.0,1.0),3.0));
        float tilt=vs_hash21(vec2(seed,8))*vs_constant_vs_TAU;vec3 along=normalize(side*cos(tilt)+up*sin(tilt)+direction*.25),across=cross(direction,along);
        float span=.48+vs_hash21(vec2(seed,9))*.62;
        point=vec3(0,vs_constant_DC_centerY,0)+direction*reach+along*((v-.5)*span)+across*(jitter*.24+fork*u*.22);
      }else{
      float v=mix(u,.35+u*.38,fork),k=v*20.0,j=floor(k);
      float jag=mix(vs_hash21(vec2(seed,j)),vs_hash21(vec2(seed,j+1.0)),fract(k))-.5;
      float bend=sin(v*3.14159265),r=vs_constant_DC_lowerRadius*mix(sqrt(.015+vs_hash21(vec2(seed,2))*.88),sqrt(.015+vs_hash21(vec2(seed,3))*.88),v);
      angle+=v*(vs_hash21(vec2(seed,4))-.5)*1.1+jag*.38*bend+fork*u*.38;
      point=vec3(cos(angle)*r,vs_constant_DC_baseY+v*vs_constant_DC_height,sin(angle)*r);
      }return point;
    }
    void vs_main(inout vec2 aField, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout float vAlpha, inout float vFieldRed, inout vec2 vUv){vUv=uv;vec4 state=uField[int(aField.x)];vAlpha=state.x;vFieldRed=step(vs_constant_DC_burst,uTime)*step(.5,vs_hash21(vec2(aField.x,uFieldSeed+47.0)));
      if(vAlpha<.001){gl_Position=vec4(0,0,2,1);return;}
      vec4 mv=modelViewMatrix*vec4(vs_fieldPoint(uv.x,state.y,aField.y, aField)*uSize,1);
      vec4 ahead=modelViewMatrix*vec4(vs_fieldPoint(min(1.0,uv.x+.002),state.y,aField.y, aField)*uSize,1),behind=modelViewMatrix*vec4(vs_fieldPoint(max(0.0,uv.x-.002),state.y,aField.y, aField)*uSize,1);
      vec3 velocity=ahead.xyz-behind.xyz;float perspective=1.0-step(.5,projectionMatrix[3][3]);vec2 tangent=normalize(velocity.xy-mv.xy*(velocity.z/mv.z)*perspective+vec2(.00001,0));
      float width=mix(.11,.055,aField.y)*(.85+vs_hash21(vec2(aField.x,state.y))*.35)*(1.0+step(vs_constant_DC_burst,uTime)*.25);
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
  

    void fs_main(inout vec4 gl_FragColor, inout float vAlpha, inout float vFieldRed, inout vec2 vUv){float q=abs(vUv.y*2.0-1.0),tip=mix(.7,1.0,smoothstep(0.0,.08,vUv.x)*(1.0-smoothstep(.92,1.0,vUv.x)));
      float core=1.0-smoothstep(.28,.36,q),edge=exp(-pow((q-.43)*15.0,2.0)),corona=exp(-q*q*3.5);
      float alpha=max(core,max(edge,corona*.55))*vAlpha*tip;if(alpha<.005)discard;
      vec3 coronaColor=mix(mix(uColor,vec3(.67,.12,1),.25),vec3(.35,.0007,.01225),vFieldRed);
      vec3 color=mix(coronaColor*(.45+edge*.95),vec3(.0002,.0001,.0004),core);
      gl_FragColor=vec4(color,alpha);
    
    
  }
void vertex(){
vec2 aField = vec2(CUSTOM0.x,CUSTOM0.y);
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
float vAlpha = float(0);
float vFieldRed = float(0);
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aField, gl_Position, modelViewMatrix, position, projectionMatrix, uv, vAlpha, vFieldRed, vUv);
bridge_vUv = vUv;
bridge_vAlpha = vAlpha;
bridge_vFieldRed = vFieldRed;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vAlpha = bridge_vAlpha;
float vFieldRed = bridge_vFieldRed;
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vAlpha, vFieldRed, vUv);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
