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
uniform float uHalo;
uniform float uDetail;
uniform vec3 uColor;
varying float bridge_vAlive;
varying float bridge_vAlong;
varying float bridge_vFlight;
varying vec2 bridge_vLink;

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
  
    vec3 vs_path(float u, inout vec3 aEnd, inout vec4 aLink, inout vec4 aStart){float tension=uChainTension;if(abs(tension)<.00001)return mix(aStart.xyz,aEnd,u);vec3 radial=vec3(cos(aLink.w),0,sin(aLink.w)),side=vec3(-sin(aLink.w),0,cos(aLink.w));return mix(aStart.xyz,aEnd,u)+(radial*sin(u*3.14159265)*vs_constant_DC_chainBend+side*sin(u*vs_constant_vs_TAU)*.16)*tension;}
    vec3 vs_spinFragment(vec3 v,vec3 axis,float angle){return v*cos(angle)+cross(axis,v)*sin(angle)+axis*dot(axis,v)*(1.0-cos(angle));}
    void vs_main(inout vec4 aBreak, inout vec3 aEnd, inout vec4 aLink, inout vec3 aShock, inout vec4 aStart, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout float vAlive, inout float vAlong, inout float vFlight, inout vec2 vLink){float u=aLink.x;vAlong=u;vLink=position.xy*vec2(.29,.41);
      float reach=mix(-.025,1.025,smoothstep(vs_constant_DC_chainStart,vs_constant_DC_chainEnd,uTime)),grow=smoothstep(u-.02,u+.02,reach)*step(vs_constant_DC_chainStart,uTime);
      vec3 center=vs_path(u, aEnd, aLink, aStart),delta=vs_path(min(1.0,u+.002), aEnd, aLink, aStart)-vs_path(max(0.0,u-.002), aEnd, aLink, aStart),up=normalize(delta);
      float stretch=length(delta)/((min(1.0,u+.002)-max(0.0,u-.002))*length(aEnd-aStart.xyz));
      vec3 chunk=vs_path(aBreak.x, aEnd, aLink, aStart),radial=chunk-vec3(0,vs_constant_DC_centerY,0);float hitTime=aShock.y+abs(aBreak.x-aShock.x)/aShock.z*vs_constant_DC_breakTravel;vFlight=uTime-hitTime;
      float flight=max(0.0,vFlight),seed=fract(sin(aBreak.y*17.1+aBreak.z*31.7)*437.31),spin=flight*(4.0+seed*5.0),fragmentScale=mix(1.0,aBreak.w*vs_constant_DC_fragmentScale,smoothstep(0.0,.08,flight));
      vec3 axis=normalize(vec3(cos(seed*vs_constant_vs_TAU),.35,sin(seed*vs_constant_vs_TAU)));
      vec3 p=chunk+vs_spinFragment((center-chunk)*fragmentScale,axis,spin)+normalize(radial)*((vs_constant_DC_fragmentImpulse+seed*vs_constant_DC_fragmentSpread)/sqrt(aBreak.w))*(1.0-exp(-flight*2.2))/2.2+vec3(0,-1.4*flight*flight,0);
      vec4 mv=modelViewMatrix*vec4(p*uSize,1.0);vec3 direction=(modelViewMatrix*vec4(vs_spinFragment(up,axis,spin),0)).xyz;
      float perspective=1.0-step(.5,projectionMatrix[3][3]);vec2 projected=direction.xy-mv.xy*(direction.z/mv.z)*perspective;
      vec2 heading=normalize(projected+vec2(.000001,0)),across=vec2(heading.y,-heading.x);
      float foreshorten=clamp(length(projected)/max(length(direction),.000001),.22,1.0),narrow=mix(1.0,.58,mod(aLink.y,2.0));
      float scale=uSize*length(modelViewMatrix[0].xyz)*aLink.z*fragmentScale*grow;
      mv.xy+=(across*vLink.x*narrow+heading*vLink.y*stretch*foreshorten)*scale;
      vAlive=grow*(1.0-smoothstep(4.35,4.98,uTime));gl_Position=projectionMatrix*mv;
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
  

    void fs_main(inout vec4 gl_FragColor, inout vec4 gl_FragCoord, inout float vAlive, inout float vAlong, inout float vFlight, inout vec2 vLink){if(vAlive<.005)discard;vec2 radii=vec2(.078,.1209),q=vLink/radii;float r=length(q);
      float d=(r-1.0)*r/max(length(vLink/(radii*radii)),.00001),aa=max(fwidth(d),.0005);
      float body=1.0-smoothstep(.017,.019+aa,abs(d));
      float running=1.0-step(fs_constant_DC_burst,uTime),head=fract(uFlow*.8),band=exp(-pow((vAlong-head)*22.0,2.0));
      float hit=step(0.0,vFlight)*(1.0-smoothstep(.008,.046,vFlight)),hot=band*(.02+uBeat*.02)*running+hit*.12;
      if(uHalo<.5){if(r<.001||fs_hash21(gl_FragCoord.xy)>body*vAlive)discard;
        float light=.2+.8*max(0.0,dot(normalize(q),normalize(vec2(-.3,.8))));
        
        vec3 color=vec3(.00035)+vec3(.0008)*light+vec3(.0015)*hit;
        gl_FragColor=vec4(color,1.0);
      }else{float cardFade=(1.0-smoothstep(.125,.145,abs(vLink.x)))*(1.0-smoothstep(.180,.205,abs(vLink.y)));
        float halo=exp(-pow(abs(d)/.040,2.0))*(1.0-body)*cardFade,alpha=halo*(.72+hot*.35)*vAlive*(.75+.25*min(uDetail,1.5));
        if(r<.001||alpha<.003)discard;gl_FragColor=vec4(uColor,alpha);
      }
      
    
    
  
    }
void vertex(){
vec4 aBreak = vec4(CUSTOM1.x,CUSTOM1.y,CUSTOM1.z,CUSTOM1.w);
vec3 aEnd = vec3(CUSTOM3.x,CUSTOM3.y,CUSTOM3.z);
vec4 aLink = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
vec3 aShock = vec3(CUSTOM3.w,UV2.x,UV2.y);
vec4 aStart = vec4(CUSTOM2.x,CUSTOM2.y,CUSTOM2.z,CUSTOM2.w);
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
float vAlive = float(0);
float vAlong = float(0);
float vFlight = float(0);
vec2 vLink = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aBreak, aEnd, aLink, aShock, aStart, gl_Position, modelViewMatrix, position, projectionMatrix, vAlive, vAlong, vFlight, vLink);
bridge_vAlive = vAlive;
bridge_vAlong = vAlong;
bridge_vFlight = vFlight;
bridge_vLink = vLink;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
vec4 gl_FragCoord = FRAGCOORD;
float vAlive = bridge_vAlive;
float vAlong = bridge_vAlong;
float vFlight = bridge_vFlight;
vec2 vLink = bridge_vLink;
fs_main(gl_FragColor, gl_FragCoord, vAlive, vAlong, vFlight, vLink);
ALBEDO = gl_FragColor.rgb; 
}
