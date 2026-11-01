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
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;
varying vec2 bridge_vCoreOffset;
varying float bridge_vSeed;
varying float bridge_vValid;

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
  
    float vs_inkProgress(float time,float start){float q=(min(time,vs_constant_DC_burst)-start)/(vs_constant_DC_burst-start);return vs_constant_DC_inkPullLead*q+(1.0-vs_constant_DC_inkPullLead)*pow(max(0.0,q),2.0);}
    float vs_inkTime(float progress,float start){float a=1.0-vs_constant_DC_inkPullLead,q=progress<0.0?progress/vs_constant_DC_inkPullLead:(-vs_constant_DC_inkPullLead+sqrt(vs_constant_DC_inkPullLead*vs_constant_DC_inkPullLead+4.0*a*progress))/(2.0*a);return start+q*(vs_constant_DC_burst-start);}
    vec3 vs_inkPoint(float sampleTime,vec4 seed,float start){
      float q=clamp((sampleTime-start)/(vs_constant_DC_burst-start),0.0,1.0),pull=clamp(vs_inkProgress(sampleTime,start),0.0,1.0);
      float budget=mix(vs_constant_DC_inkTurnsMin,vs_constant_DC_inkTurnsMax,seed.z),turns=vs_constant_DC_inkLead*q+(budget-vs_constant_DC_inkLead)*q*q,angle=seed.x*vs_constant_vs_TAU+vs_constant_vs_TAU*turns;
      float r=mix(mix(vs_constant_DC_inkMinRadius,vs_constant_DC_inkRadius,seed.w),vs_constant_DC_inkCoreRadius,pull);
      float baseLatitude=(seed.y*2.0-1.0)*.96,tilt=.2+seed.w*.25;
      float latitude=baseLatitude*cos(tilt)+sqrt(1.0-baseLatitude*baseLatitude)*sin(tilt)*sin(angle+seed.z*vs_constant_vs_TAU);
      float side=sqrt(max(0.0,1.0-latitude*latitude));
      vec3 direction=vec3(cos(angle)*side,latitude,sin(angle)*side);
      vec3 center=vec3(0,vs_constant_DC_centerY,0),p=center+direction*r;
      return p+normalize(p-center)*(1.0-exp(-max(0.0,sampleTime-vs_constant_DC_burst)*18.0))*.85;
    }
    vec4 vs_inkTrail(vec4 seed,float start,float span,float width,out float valid,out vec2 coreOffset, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv){
      
      float turnBudget=mix(vs_constant_DC_inkTurnsMin,vs_constant_DC_inkTurnsMax,seed.z);
      
      float headQ=clamp((uTime-start)/(vs_constant_DC_burst-start),0.0,1.0),headTurn=vs_constant_DC_inkLead*headQ+(turnBudget-vs_constant_DC_inkLead)*headQ*headQ;
      float tailTurn=max(0.0,headTurn-.30),a=turnBudget-vs_constant_DC_inkLead;
      float tailQ=(-vs_constant_DC_inkLead+sqrt(vs_constant_DC_inkLead*vs_constant_DC_inkLead+4.0*a*tailTurn))/(2.0*a);
      float headProgress=vs_inkProgress(uTime,start),minimumProgress=vs_constant_DC_inkPullLead*tailQ+(1.0-vs_constant_DC_inkPullLead)*tailQ*tailQ;
      float tailProgress=max(minimumProgress,headProgress-span*.75*min(1.0,.85/turnBudget));
      float progress=mix(tailProgress,headProgress,uv.x);
      float sampleTime=vs_inkTime(progress,start)+max(0.0,uTime-vs_constant_DC_burst);valid=1.0;
      vec4 mv=modelViewMatrix*vec4(vs_inkPoint(sampleTime,seed,start)*uSize,1);
      vec4 next=modelViewMatrix*vec4(vs_inkPoint(sampleTime+.002,seed,start)*uSize,1);
      vec4 prior=modelViewMatrix*vec4(vs_inkPoint(sampleTime-.002,seed,start)*uSize,1);
      float perspective=1.0-step(.5,projectionMatrix[3][3]);
      
      vec3 velocity=next.xyz-prior.xyz;vec2 tangent=normalize(velocity.xy-mv.xy*(velocity.z/mv.z)*perspective+vec2(.00001,0));
      mv.xy+=vec2(-tangent.y,tangent.x)*position.y*width*uSize*length(modelViewMatrix[0].xyz);
      vec4 core=modelViewMatrix*vec4(0,vs_constant_DC_centerY*uSize,0,1);
      coreOffset=(mv.xy-core.xy*(mv.z/core.z))/(mix(.3,1.45,vs_charge())*uSize*length(modelViewMatrix[0].xyz));
      return mv;
    }
  
    void vs_main(inout vec4 aAura, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout vec2 vCoreOffset, inout float vSeed, inout vec2 vUv, inout float vValid){vUv=uv;vSeed=aAura.z;vec4 mv=vs_inkTrail(aAura,.32,vs_constant_DC_auraTrail,.065+aAura.w*.025,vValid,vCoreOffset, modelViewMatrix, position, projectionMatrix, uv);gl_Position=projectionMatrix*mv;}

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
  
vec3 fs_inkBrush(vec2 uv,float seed,float travel){
    float u=uv.x,q=uv.y*2.0-1.0;
    float grain=fs_noise21(vec2(u*17.0-travel,seed*27.0));
    float profile=pow(max(0.0,sin(u*3.14159265)),.82)*(.84-u*.18);
    float edge=profile*(.91+grain*.07),aa=max(fwidth(q)*1.2,.012);
    float body=1.0-smoothstep(edge-aa,edge+aa,abs(q));
    float hairs=fs_noise21(vec2(u*2.0-travel*.15,q*31.0+seed*39.0));
    float dry=smoothstep(.42,.72,hairs)*smoothstep(.04,.28,u)*smoothstep(.02,.20,abs(q));
    body*=1.0-dry*.08*min(uDetail,1.0);
    float rim=(1.0-smoothstep(.012,.065,abs(q-edge*.88)))*smoothstep(.36,.68,grain);
    return vec3(body,dry,rim);
  }
    void fs_main(inout vec4 gl_FragColor, inout vec2 vCoreOffset, inout float vSeed, inout vec2 vUv, inout float vValid){vec3 brush=fs_inkBrush(vUv,vSeed,uTime*.6);float b=max(0.0,uTime-fs_constant_DC_burst);
      float life=smoothstep(.32,.65,uTime)*(1.0-smoothstep(.04,.24,b))*(.60+.40*fs_charge());
      float gap=smoothstep(.85,1.10,length(vCoreOffset)),alpha=brush.x*life*gap*vValid*.98;if(alpha<.003)discard;
      float flash=step(fs_constant_DC_burst,uTime)*(1.0-smoothstep(.008,.065,b));
      vec3 tint=mix(vec3(1.0,.003,.012),uColor,smoothstep(.25,.75,fract(vSeed*3.17)));
      float pigment=smoothstep(.16,.48,vSeed)*smoothstep(.06,.78,vUv.x);
      vec3 ink=mix(vec3(.00015,.0001,.0003),tint*.045,pigment);
      vec3 edge=tint*brush.z*(.035+flash*.10)*min(uDetail,1.5);
      gl_FragColor=vec4(ink+edge,alpha);
    
    
  }
void vertex(){
vec4 aAura = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
vec2 vCoreOffset = vec2(0);
float vSeed = float(0);
vec2 vUv = vec2(0);
float vValid = float(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aAura, gl_Position, modelViewMatrix, position, projectionMatrix, uv, vCoreOffset, vSeed, vUv, vValid);
bridge_vUv = vUv;
bridge_vCoreOffset = vCoreOffset;
bridge_vSeed = vSeed;
bridge_vValid = vValid;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
vec2 vCoreOffset = bridge_vCoreOffset;
float vSeed = bridge_vSeed;
vec2 vUv = bridge_vUv;
float vValid = bridge_vValid;
fs_main(gl_FragColor, vCoreOffset, vSeed, vUv, vValid);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
