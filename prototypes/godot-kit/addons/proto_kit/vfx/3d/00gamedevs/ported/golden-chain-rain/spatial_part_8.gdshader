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
#define VARIANT 15
#define TOON 0
uniform float uSize;
uniform float uTime;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;
varying float bridge_vFade;
varying float bridge_vHeat;
varying float bridge_vGround;


    vec2 vs_gcCrackPoint(vec2 q,float seed){
      float radius=length(q),angle=seed*6.283185;
      q*=.88+.12*sin((radius>0.0?atan(q.y,q.x):0.0)*3.0+seed*37.0+radius*4.0);
      return mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)))*q;
    }
  
    
    
    void vs_main(inout vec3 aCrackA, inout vec3 aCrackB, inout vec3 aEnd, inout vec2 aTime, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout mat3 normalMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec4 seed, inout vec2 uv, inout float vFade, inout float vGround, inout float vHeat, inout vec2 vUv){
      float along=.15+seed.x*.70;
      vec2 q=mix(vs_gcCrackPoint(aCrackA.xy,aTime.y),vs_gcCrackPoint(aCrackB.xy,aTime.y),along);
      float reveal=mix(aCrackA.z,aCrackB.z,along)*.15+.03;
      float age=uTime-aTime.x-.35-reveal-seed.z*.42,drift=max(age,0.0);
      float angle=seed.w*6.283185;
      vec3 p=aEnd+vec3(q.x,.012,q.y)+vec3(cos(angle)*.14,(.48+seed.y*.38)*2.0,sin(angle)*.14)*drift;
      p.y+=.13*drift*drift*2.0;
      vFade=step(0.0,age)*smoothstep(0.0,.035,age)*(1.0-smoothstep(.22,.65,age));
      vHeat=1.0-clamp(age/.65,0.0,1.0);
      float scale=(.035+seed.y*.045)*(1.0-smoothstep(.25,.65,age)),spin=angle+drift*(seed.x-.5)*5.0;
      vec2 direction=vec2(cos(spin),sin(spin));
      vec2 offset=(direction*position.x*1.5+vec2(-direction.y,direction.x)*position.y*.58)*scale;
      float parentScale=length(modelViewMatrix[0].xyz);
      vec3 localOffset=vec3(dot(normalMatrix[0],vec3(offset,0)),dot(normalMatrix[1],vec3(offset,0)),dot(normalMatrix[2],vec3(offset,0)))*parentScale;
      vGround=p.y+localOffset.y;vec4 view=modelViewMatrix*vec4(p*uSize,1.0);
      view.xy+=offset*uSize*parentScale;vUv=uv;gl_Position=projectionMatrix*view;
    }


    void fs_main(inout vec4 gl_FragColor, inout float vFade, inout float vGround, inout float vHeat, inout vec2 vUv){
      if(vGround<0.0)discard;
      vec2 q=vUv*2.0-1.0;
      float edge=max(max(-q.y-.55,q.x*.92+q.y*.5-.30),-q.x*.75+q.y*.55-.34);
      float chip=1.0-smoothstep(-.045,.025,edge);
      float halo=exp(-pow(max(edge,0.0)*9.0,2.0))*.27*(1.0-smoothstep(.45,1.0,length(q)));
      float alpha=(chip*.85+halo)*vFade*min(1.0,uDetail);if(alpha<.004)discard;
      vec3 gold=uColor*(.85+vUv.y*.7)+vec3(.45,.34,.10)*exp(-abs(edge)*60.0)*vHeat;
      gl_FragColor=vec4(gold,alpha);
    
    
  }
void vertex(){
vec3 aCrackA = vec3(CUSTOM1.x,CUSTOM1.y,CUSTOM1.z);
vec3 aCrackB = vec3(CUSTOM1.w,CUSTOM2.x,CUSTOM2.y);
vec3 aEnd = vec3(CUSTOM3.y,CUSTOM3.z,CUSTOM3.w);
vec2 aTime = vec2(UV2.x,UV2.y);
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
mat3 normalMatrix = MODELVIEW_NORMAL_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec4 seed = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
vec2 uv = UV;
float vFade = float(0);
float vGround = float(0);
float vHeat = float(0);
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aCrackA, aCrackB, aEnd, aTime, gl_Position, modelViewMatrix, normalMatrix, position, projectionMatrix, seed, uv, vFade, vGround, vHeat, vUv);
bridge_vUv = vUv;
bridge_vFade = vFade;
bridge_vHeat = vHeat;
bridge_vGround = vGround;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vFade = bridge_vFade;
float vGround = bridge_vGround;
float vHeat = bridge_vHeat;
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vFade, vGround, vHeat, vUv);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
