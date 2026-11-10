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
#define KIND 3
#define VARIANT 11
#define TOON 1
uniform float uSize;
uniform float uTime;
uniform vec3 uBurstOffset;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;
varying float bridge_vFade;
varying float bridge_vPart;
varying float bridge_vLong;


    
    
    vec3 vs_emberPath(float age,float isLong, inout vec4 seed){
      
      float launchAngle=seed.x*6.283185+uBurstOffset.x*.17;
      float launchY=seed.y*1.82-.91;
      float horizontal=sqrt(max(0.0,1.0-launchY*launchY));
      vec3 launchDirection=vec3(cos(launchAngle)*horizontal,launchY,sin(launchAngle)*horizontal);
      float outwardDistance=(1.0-exp(-age*mix(3.8,2.5,isLong)))*mix(2.7+seed.z*2.0,5.15+seed.w*.15,isLong);
      float gravityDrop=age*age*(1.1+seed.w*.2);
      return launchDirection*(.12+outwardDistance)-vec3(0,gravityDrop,0);
    }
    void vs_main(inout float aPart, inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec4 seed, inout vec2 uv, inout float vFade, inout float vLong, inout float vPart, inout vec2 vUv){
      vUv=uv;vPart=aPart;vLong=step(.90,seed.z);
      if(aPart<.5&&vLong<.5){vFade=0.0;gl_Position=vec4(2,2,2,1);return;}
      float age=max(0.0,uTime-.015-seed.w*.11);
      float life=mix(.55+seed.w*.5,1.38+seed.w*.28,vLong);
      vFade=smoothstep(0.0,.025,age)*(1.0-smoothstep(life*.54,life,age));
      vFade*=.88+.12*sin(age*(18.0+seed.y*15.0)+seed.x*11.0);
      float sampleAge=age;
      if(aPart<.5){sampleAge=max(0.0,age-(1.0-uv.x)*(.48+seed.w*.28));vFade*=smoothstep(0.0,.055,sampleAge)*vLong;}
      vec4 mv=modelViewMatrix*vec4(vs_emberPath(sampleAge,vLong, seed)*uSize,1.0);
      vec4 next=modelViewMatrix*vec4(vs_emberPath(sampleAge+.008,vLong, seed)*uSize,1.0);
      float scale=uSize*length(modelMatrix[1].xyz);
      
      vec4 clip=projectionMatrix*mv,nextClip=projectionMatrix*next;
      vec2 projectedDelta=(nextClip.xy/max(nextClip.w,.0001)-clip.xy/max(clip.w,.0001))/vec2(projectionMatrix[0][0],projectionMatrix[1][1]);
      float projectedSpeed=length(projectedDelta)*max(-mv.z,.0001)/max(.008*scale,.0001);
      float directionWeight=smoothstep(.02,.20,projectedSpeed);
      vec2 tangent=length(projectedDelta)>.000001?normalize(projectedDelta):vec2(1,0);
      vec2 side=vec2(-tangent.y,tangent.x);
      if(aPart>.5){
        float diameter=1.5*mix(.105+seed.w*.075,.36+seed.w*.12,vLong);
        float streak=1.0+(1.0-vLong)*(1.0-smoothstep(.025,.22,age))*1.7*directionWeight;
        mv.xy+=(tangent*position.x*diameter*streak+side*position.y*diameter)*scale;
      }else{
        float width=1.5*(.045+seed.w*.035)*(.25+.75*uv.x);
        mv.xy+=side*(uv.y-.5)*width*scale*directionWeight;
      }
      gl_Position=projectionMatrix*mv;
    }


    float fs_styleStep(float edge,float value){float aa=max(fwidth(value),.012);return smoothstep(edge-aa,edge+aa,value);}
    vec3 fs_styleColor(vec3 tint,float light){
      vec3 c=mix(tint*.22,tint*.72,fs_styleStep(.38,light));
      return mix(c,mix(tint,vec3(1.0),.38)*1.04,fs_styleStep(.70,light));
    }
    vec3 fs_styleHeat(vec3 tint,float heat){
      vec3 c=mix(tint*.24,tint*1.05,fs_styleStep(.38,heat));
      return mix(c,mix(tint,vec3(1.0,.88,.51),.62),fs_styleStep(.70,heat));
    }
  
    
    void fs_main(inout vec4 gl_FragColor, inout float vFade, inout float vLong, inout float vPart, inout vec2 vUv){
      float alpha;vec3 color;vec3 particleColor=uColor;
      if(vPart>.5){
        float r=length((vUv-.5)*2.0);
        float core=exp(-r*r*28.0),halo=exp(-r*r*4.0)*(1.0-smoothstep(.65,1.0,r));
        alpha=(core*.98+halo*.48)*vFade;
        color=particleColor*(.5*3.0);
      }else{
        if(vLong<.5)discard;
        float edge=abs(vUv.y-.5)*2.0;
        alpha=exp(-edge*edge*3.5)*smoothstep(0.0,.16,vUv.x)*(.35+.50*vUv.x)*vFade;
        color=mix(vec3(.30,.24,.18),particleColor,pow(vUv.x,10.0));
      }
      if(alpha<.003)discard;
      gl_FragColor=vec4(color,alpha);
    
    
  
    }
void vertex(){
float aPart = CUSTOM0.x;
vec4 gl_Position = vec4(0);
mat4 modelMatrix = MODEL_MATRIX;
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec4 seed = vec4(CUSTOM0.y,CUSTOM0.z,CUSTOM0.w,CUSTOM1.x);
vec2 uv = UV;
float vFade = float(0);
float vLong = float(0);
float vPart = float(0);
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aPart, gl_Position, modelMatrix, modelViewMatrix, position, projectionMatrix, seed, uv, vFade, vLong, vPart, vUv);
bridge_vUv = vUv;
bridge_vFade = vFade;
bridge_vPart = vPart;
bridge_vLong = vLong;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vFade = bridge_vFade;
float vLong = bridge_vLong;
float vPart = bridge_vPart;
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vFade, vLong, vPart, vUv);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
