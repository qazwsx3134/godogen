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
#define VARIANT 15
#define TOON 0
#define GC_RIPPLE_FEATHER 1
uniform float uSize;
uniform float uTime;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vRipple;
varying float bridge_vAge;
varying float bridge_vFade;
varying float bridge_vSeed;


    
    void vs_main(inout vec3 aEnd, inout vec3 aStart, inout vec2 aTime, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout float vAge, inout float vFade, inout vec2 vRipple, inout float vSeed){
      float age=uTime-aTime.x,localAge=age;
      vFade=smoothstep(0.0,.085,localAge)*(1.0-smoothstep(1.10,1.55,age));
      float open=1.0-pow(1.0-clamp(localAge/.16,0.0,1.0),3.0);
      float radius=.82*(.45+.55*open);
      vec3 forward=normalize(aEnd-aStart),right=normalize(cross(forward,vec3(0,1,0))),side=normalize(cross(right,forward));
      vec3 across=right,up=side,center=aStart;
      float extent=1.0;
      #ifdef GC_RIPPLE_GLOW
        extent=1.9;
        
        
        vec3 planeNormal=normalize(cross(across,up));
        vec3 viewNormal=mat3(modelViewMatrix)*planeNormal;
        vec3 viewCenter=(modelViewMatrix*vec4(center*uSize,1.0)).xyz;
        center+=planeNormal*.004*sign(dot(viewNormal,-viewCenter));
      #endif
      #ifdef GC_RIPPLE_FEATHER
        extent=1.2;
      #endif
      
      radius*=mix(.48,1.0,sqrt(vFade));
      vec3 p=center+(across*position.x+up*position.y)*radius*extent;
      vRipple=position.xy*extent;vAge=localAge;vSeed=aTime.y;
      gl_Position=projectionMatrix*modelViewMatrix*vec4(p*uSize,1.0);
    }


    float fs_grHash(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
    float fs_grNoise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
      return mix(mix(fs_grHash(i),fs_grHash(i+vec2(1,0)),f.x),mix(fs_grHash(i+vec2(0,1)),fs_grHash(i+vec2(1,1)),f.x),f.y);}
  
    
    void fs_main(inout vec4 gl_FragColor, inout float vAge, inout float vFade, inout vec2 vRipple, inout float vSeed){
      if(vFade<=0.0)discard;
      vec2 q=vRipple,drift=vec2(vAge*.23,-vAge*.17)+vSeed*17.0;
      float r=length(q),flow=fs_grNoise(q*7.0+drift),fine=fs_grNoise(q*23.0-drift*.8);
      float warped=r+(flow-.5)*.045+(fine-.5)*.012;
      float phase=warped*52.0-vAge*8.5+sin(atan(q.y,q.x)*2.0+r*13.0-vAge*1.7)*.3;
      float crest=pow(.5+.5*cos(phase),5.5);
      float softCrest=pow(.5+.5*cos(phase),1.6);
      float threads=pow(.5+.5*cos(warped*91.0-vAge*6.4+flow*3.0),14.0);
      float broken=smoothstep(.18,.80,fs_grNoise(q*vec2(11.0,16.0)+drift*.45));
      float edge=.64+(flow-.5)*.025;
      float alpha=1.0;
      #ifdef GC_RIPPLE_FEATHER
        if(r<edge-.005||r>1.16)discard;
        alpha=1.0-smoothstep(edge,1.16,r);
      #else
        if(r>edge)discard;
      #endif
      vec2 hot=(q+vec2(.075,-.02))*vec2(1.7,1.0);
      float core=exp(-dot(hot,hot)*26.0);
      float reflection=exp(-pow((q.x+.10)*8.0,2.0)-pow(q.y*2.4,2.0))*.35;
      vec3 trough=uColor*vec3(.40,.43,.48)*(.75+flow*.5);
      vec3 waveColor=mix(uColor,vec3(1.0,.94,.73),.72);
      float waves=(crest*1.02+softCrest*.22+threads*.14*min(uDetail,1.4))*(.18+broken*.82);
      vec3 gold=trough+waveColor*waves;
      gold+=vec3(1.0,.96,.79)*(core*4.0+reflection*1.4);
      
      gl_FragColor=vec4(gold*(.8+.2*vFade),alpha);
    
    
  
    }
void vertex(){
vec3 aEnd = vec3(CUSTOM0.w,CUSTOM1.x,CUSTOM1.y);
vec3 aStart = vec3(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z);
vec2 aTime = vec2(CUSTOM1.z,CUSTOM1.w);
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
float vAge = float(0);
float vFade = float(0);
vec2 vRipple = vec2(0);
float vSeed = float(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aEnd, aStart, aTime, gl_Position, modelViewMatrix, position, projectionMatrix, vAge, vFade, vRipple, vSeed);
bridge_vRipple = vRipple;
bridge_vAge = vAge;
bridge_vFade = vFade;
bridge_vSeed = vSeed;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vAge = bridge_vAge;
float vFade = bridge_vFade;
vec2 vRipple = bridge_vRipple;
float vSeed = bridge_vSeed;
fs_main(gl_FragColor, vAge, vFade, vRipple, vSeed);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
