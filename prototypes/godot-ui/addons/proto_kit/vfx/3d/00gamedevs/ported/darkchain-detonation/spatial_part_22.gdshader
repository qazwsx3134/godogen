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
uniform float uDetail;
uniform vec3 uColor;
varying float bridge_vAcross;
varying float bridge_vHeight;
varying vec2 bridge_vRing;

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
  
    void vs_main(inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout float vAcross, inout float vHeight, inout vec2 vRing){float t=max(0.0,uTime-vs_constant_DC_burst),shrink=1.0-smoothstep(.32,vs_constant_DC_waveLife,t);vAcross=uv.x;vHeight=uv.y;
      float width=min(uWaveRadius*.8,vs_constant_DC_waveWidth)*shrink,r=uWaveRadius-width*(1.0-uv.x);vec2 direction=normalize(position.xz);vRing=direction;
      vec3 p=vec3(direction.x*r,vs_constant_DC_centerY+uv.y*vs_constant_DC_waveHeight*shrink,direction.y*r);
      gl_Position=projectionMatrix*modelViewMatrix*vec4(p*uSize,1.0);}

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
  

    void fs_main(inout vec4 gl_FragColor, inout float vAcross, inout vec2 vRing){float t=max(0.0,uTime-fs_constant_DC_burst),life=1.0-smoothstep(.08,fs_constant_DC_waveLife,t);
      float across=clamp(vAcross,0.0,1.0);vec2 direction=normalize(vRing);
      float grain=fs_noise3(vec3(direction*18.0,across*4.0-t*.5)),bristles=fs_noise3(vec3(direction*110.0,across*.85));
      float brush=.68+.32*smoothstep(.20,.72,grain),dry=smoothstep(.42,.70,bristles);
      float tears=fs_noise3(vec3(direction*6.0,1.7)),edge=.57+.27*fs_noise3(vec3(direction*16.0,2.3))+.16*bristles;
      float broken=smoothstep(.31,.49,tears)*(1.0-smoothstep(edge-.025,edge,across));
      float pressure=pow(smoothstep(0.0,.82,across),.75),trailingFade=smoothstep(0.0,.24,across),rimFade=broken;
      
      float inkOpacity=(.65+pressure*.33)*brush*(1.0-dry*.32)*trailingFade*rimFade;
      vec3 color=vec3(.0002,.0001,.0004);
      if(life*inkOpacity<.003)discard;gl_FragColor=vec4(color,life*inkOpacity);
    
    
  }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
float vAcross = float(0);
float vHeight = float(0);
vec2 vRing = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelViewMatrix, position, projectionMatrix, uv, vAcross, vHeight, vRing);
bridge_vAcross = vAcross;
bridge_vHeight = vHeight;
bridge_vRing = vRing;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vAcross = bridge_vAcross;
vec2 vRing = bridge_vRing;
fs_main(gl_FragColor, vAcross, vRing);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
