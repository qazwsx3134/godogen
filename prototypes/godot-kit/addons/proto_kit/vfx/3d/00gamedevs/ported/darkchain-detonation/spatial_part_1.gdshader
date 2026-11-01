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
uniform float uTier;
uniform float uDetail;
uniform vec3 uColor;
uniform vec4 uGlyphs[192];
varying vec2 bridge_vDisk;

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
  
    void vs_main(inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 vDisk){vDisk=position.xy;float t=clamp(uTime/vs_constant_DC_chainStart,0.0,1.0),pop=1.0-pow(1.0-t,3.0)+sin(t*3.14159265)*.18;vec3 p=vec3(position.x*mix(vs_constant_DC_lowerRadius,vs_constant_DC_upperRadius,uTier)*pop,vs_constant_DC_baseY+uTier*vs_constant_DC_height,position.y*mix(vs_constant_DC_lowerRadius,vs_constant_DC_upperRadius,uTier)*pop);gl_Position=projectionMatrix*modelViewMatrix*vec4(p*uSize,1.0);}

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
  

    vec2 fs_line(float d,float w){float aa=max(fwidth(d),.001),distance=abs(d);return vec2(1.0-smoothstep(w,w+aa,distance),exp(-pow(distance/(w*3.4+aa*1.5),1.5)));}
    vec2 fs_segment(vec2 p,vec2 a,vec2 b,float width){vec2 v=b-a;return fs_line(length(p-a-v*clamp(dot(p-a,v)/max(dot(v,v),.000001),0.0,1.0)),width);}
    vec2 fs_magicLetter(vec2 p,float glyph){vec2 ink=vec2(0);for(int i=0;i<8;i++){vec4 stroke=uGlyphs[int(glyph)*8+i];ink=max(ink,fs_segment(p,stroke.xy,stroke.zw,.065));}return ink;}
    void fs_main(inout vec4 gl_FragColor, inout vec2 vDisk){float r=length(vDisk),a=atan(vDisk.y,vDisk.x),turn=uTime*.44*(uTier*2.0-1.0);
      vec2 edge=fs_line(r-.965,.0035)+fs_line(r-.935,.0025)*.8;
      vec2 frame=fs_line(r-.84,.0025),hub=fs_line(r-.23,.0025)+fs_line(r-.205,.0018)*.7,glyphs=vec2(0),ornament=fs_line(r-.30,.0015)+fs_line(r-.545,.0015)+fs_line(r-.615,.0015);
      for(int i=0;i<3;i++){
        float angle=1.57079633+float(i)*fs_constant_fs_TAU/3.0,next=angle+fs_constant_fs_TAU/3.0;
        vec2 axis=vec2(cos(angle),sin(angle)),other=vec2(cos(next),sin(next)),vertex=axis*.84,node=axis*.42;
        frame=max(frame,fs_segment(vDisk,vertex,other*.84,.0025));
        frame=max(frame,fs_segment(vDisk,axis*.23,vertex,.002));
        float corner=length(vDisk-vertex);frame=max(frame,(fs_line(corner-.34,.002)+fs_line(corner-.395,.002))*(1.0-smoothstep(.838,.845,r)));
        float small=length(vDisk-node);hub=max(hub,fs_line(small-.115,.003));ornament=max(ornament,fs_line(small-.095,.0015));
        float ticksAround=atan(vDisk.y-vertex.y,vDisk.x-vertex.x);ornament=max(ornament,fs_line(sin(ticksAround*24.0),.07)*smoothstep(.348,.353,corner)*(1.0-smoothstep(.381,.387,corner))*(1.0-smoothstep(.838,.845,r)));
        vec2 q=vDisk-node;float rotation=angle+turn;q=mat2(vec2(cos(rotation),-sin(rotation)),vec2(sin(rotation),cos(rotation)))*q;
        vec2 symbol=fs_line(length(q-vec2(.012,0))-.035,.004)*(1.0-smoothstep(.05,.055,q.x));
        symbol=max(symbol,fs_segment(q,vec2(-.018,-.025),vec2(-.05,-.065),.004));symbol=max(symbol,fs_segment(q,vec2(-.01,.03),vec2(-.045,.065),.004));symbol=max(symbol,fs_segment(q,vec2(.04,0),vec2(.073,0),.004));glyphs=max(glyphs,symbol);
        hub=max(hub,fs_segment(vDisk,-axis*.195,axis*.195,.0018));
      }
      
      
      float letterPosition=fract((a+turn*.35)/fs_constant_fs_TAU+.5)*60.0,letterIndex=floor(letterPosition);
      float glyph=mod(letterIndex*7.0+floor(letterIndex/24.0)*5.0+uTier*11.0,24.0);
      vec2 runes=vec2(0);if(abs(r-.885)<.045)runes=fs_magicLetter(vec2((fract(letterPosition)-.5)*2.0,(r-.885)/.035),glyph);
      vec2 ticks=fs_line(sin(a*48.0),.08)*smoothstep(.242,.245,r)*(1.0-smoothstep(.258,.261,r));
      for(int i=0;i<6;i++){
        float angle=(float(i)+.5)*fs_constant_fs_TAU/6.0;vec2 axis=vec2(cos(angle),sin(angle)),side=vec2(-axis.y,axis.x),local=vec2(dot(vDisk,axis)-.63,dot(vDisk,side));
        ornament=max(ornament,fs_line(abs(local.x)+abs(local.y)-.032,.0018));
        ornament=max(ornament,fs_segment(vDisk,axis*.667,axis*.79,.0014));
        ornament=max(ornament,fs_line(length(vDisk-axis*.79)-.012,.0017));
      }
      float innerPosition=((a-turn*.35)/fs_constant_fs_TAU+.5)*48.0,innerIndex=floor(innerPosition);vec2 script=vec2(0);
      if(abs(r-.579)<.027)script=fs_magicLetter(vec2((fract(innerPosition)-.5)*2.0,(r-.579)/.019),mod(innerIndex*11.0+floor(innerIndex/24.0)*7.0+uTier*5.0+240.0,24.0));
      ornament=max(ornament,script*.8);
      vec2 ink=edge*.8+frame*.60+hub*.65+glyphs*.80+runes*.42+(ticks*.35+ornament*.45)*min(uDetail,1.25);
      float life=smoothstep(0.0,.18,uTime)*(1.0-smoothstep(fs_constant_DC_burst+.08,fs_constant_DC_burst+.60,uTime))*smoothstep(-.04,.12,uTime/.35-fract(a/fs_constant_fs_TAU+.5)*.35);
      float dim=1.0-smoothstep(fs_constant_DC_orbStart,fs_constant_DC_orbStart+.35,uTime)*.35;
      float core=smoothstep(.08,.30,ink.x),halo=clamp(ink.y*.8-ink.x*.45,0.0,1.0)*dim;
      float alpha=max(core,halo*.85)*life;if(r>1.0||alpha<.002)discard;
      float hue=smoothstep(-.75,.75,dot(vDisk,vec2(.8,.6)));
      vec3 black=vec3(.00012,.00008,.0002),corona=mix(vec3(1.0,.002,.035),uColor,hue)*(.90+uBeat*.14);
      gl_FragColor=vec4(mix(corona,black,core),alpha);
    
    
  }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 vDisk = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelViewMatrix, position, projectionMatrix, vDisk);
bridge_vDisk = vDisk;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
vec2 vDisk = bridge_vDisk;
fs_main(gl_FragColor, vDisk);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
