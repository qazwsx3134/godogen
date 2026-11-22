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
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vEject;
varying vec4 bridge_vEjectSeed;
varying float bridge_vEjectAge;

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
  
    
    void vs_main(inout vec4 aEjectDirection, inout vec4 aEjectSeed, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout mat4 projectionMatrix, inout vec2 uv, inout vec2 vEject, inout float vEjectAge, inout vec4 vEjectSeed){float age=(uTime-vs_constant_DC_burst)/vs_constant_DC_ejectionLife-aEjectSeed.z,t=max(age,0.0),u=uv.x;
      float tip=1.0+aEjectDirection.w*(1.0-exp(-t*34.0));
      float root=tip*smoothstep(.15,1.0,t),r=mix(root,tip,u);
      vec3 local=aEjectDirection.xyz*r;
      vec4 mv=modelViewMatrix*vec4((local+vec3(0,vs_constant_DC_centerY,0))*uSize,1.0);
      vec3 velocity=mat3(modelViewMatrix)*aEjectDirection.xyz;
      float projectedLength=length(velocity.xy);
      vec2 across=projectedLength>.001?vec2(-velocity.y,velocity.x)/projectedLength:vec2(1,0);
      float envelope=.28+.72*pow(max(0.0,sin(u*3.14159265)),.65);
      float width=aEjectSeed.y*envelope*(1.0-.55*smoothstep(.04,1.0,t));
      mv.xy+=across*(uv.y-.5)*width*4.0*uSize*length(modelViewMatrix[0].xyz);
      vEject=uv;vEjectSeed=aEjectSeed;vEjectAge=age;gl_Position=projectionMatrix*mv;}
  

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
  

    void fs_main(inout vec4 gl_FragColor, inout vec2 vEject, inout float vEjectAge, inout vec4 vEjectSeed){float age=(uTime-fs_constant_DC_burst)/fs_constant_DC_ejectionLife,t=vEjectAge;if(t<0.0||age>=1.0)discard;
      float u=vEject.x,v=(vEject.y-.5)*2.0;
      float grain=fs_noise3(vec3(u*6.0-t*18.0,v*2.0,vEjectSeed.x*17.0));
      float width=.14+.12*grain;
      float filament=1.0-smoothstep(width*.3,width,abs(v));
      float glow=exp(-v*v*9.0)*.35+exp(-v*v*4.0)*.35*(1.0-smoothstep(.15,.65,u));
      float ends=smoothstep(0.0,.05,u)*(1.0-smoothstep(.80,1.0,u));
      float breaks=smoothstep(.13+smoothstep(.45,1.0,age)*.65,.36+smoothstep(.45,1.0,age)*.65,grain);
      float fade=pow(1.0-clamp(age,0.0,1.0),2.0),heat=1.0-smoothstep(.025,.095,age);
      vec3 energy=mix(uColor,vec3(1.0,.001,.055),vEjectSeed.x);
      vec3 color=mix(energy*2.4,vec3(1.0,.55,.76)*3.0,filament*heat*(1.0-u)*(1.0-u));
      
      float separate=smoothstep(.18,.45,age),sparks=0.0;
      for(int j=0;j<4;j++){
        float seed=fs_hash21(vec2(vEjectSeed.x*53.0,float(j)+11.0));
        float scatter=fs_hash21(vec2(vEjectSeed.x*71.0,float(j)+29.0));
        float sizeSeed=fs_hash21(vec2(vEjectSeed.x*97.0,float(j)+47.0));
        float released=max(0.0,age-(.18+sizeSeed*.09));
        float drift=1.0-exp(-released*(3.0+scatter*3.0));
        
        float center=.045+seed*.19+drift*(scatter-.4)*.09;
        float lateral=(scatter*2.0-1.0)*.66*drift;
        float halfLength=mix(.038,.008+.017*sizeSeed,separate),halfWidth=.075+sizeSeed*.13;
        vec2 spark=vec2((u-center)/halfLength,(v-lateral)/halfWidth);
        float solid=1.0-smoothstep(.15,1.0,length(spark));
        float halo=exp(-dot(spark,spark)*.85)*.55;
        sparks+=(solid+halo)*(.65+sizeSeed*.55)*smoothstep(0.0,.055,released);
      }
      float line=(filament+glow)*breaks;
      float tailOnly=1.0-smoothstep(.27,.42,u);
      float alpha=mix(line,sparks,separate*tailOnly)*ends*fade*vEjectSeed.w;
      if(alpha<.003)discard;gl_FragColor=vec4(color,alpha);
    
    
  }
  
void vertex(){
vec4 aEjectDirection = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
vec4 aEjectSeed = vec4(CUSTOM1.x,CUSTOM1.y,CUSTOM1.z,CUSTOM1.w);
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
vec2 vEject = vec2(0);
float vEjectAge = float(0);
vec4 vEjectSeed = vec4(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aEjectDirection, aEjectSeed, gl_Position, modelViewMatrix, projectionMatrix, uv, vEject, vEjectAge, vEjectSeed);
bridge_vEject = vEject;
bridge_vEjectSeed = vEjectSeed;
bridge_vEjectAge = vEjectAge;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
vec2 vEject = bridge_vEject;
float vEjectAge = bridge_vEjectAge;
vec4 vEjectSeed = bridge_vEjectSeed;
fs_main(gl_FragColor, vEject, vEjectAge, vEjectSeed);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
