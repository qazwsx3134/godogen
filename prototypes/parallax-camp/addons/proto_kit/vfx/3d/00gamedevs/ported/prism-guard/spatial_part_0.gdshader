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
#define KIND 7
#define VARIANT 0
#define TOON 0
uniform float uSize;
uniform float uTime;
uniform float uLifeStart;
uniform float uLifeEnd;
uniform float uLifeOrigin;
uniform float uStopTime;
uniform float uEndDuration;
uniform float uStretch;
uniform float uQuantity;
uniform float uSpread;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;
varying vec3 bridge_vN;
varying vec3 bridge_vP;
varying float bridge_vAlpha;
varying float bridge_vTone;
varying float bridge_vPart;


    
    float vs_sat(float a){return clamp(a,0.0,1.0);}
    float vs_ease(float a){a=vs_sat(a);return 1.0-pow(1.0-a,3.0);}
    float vs_fadeEnd(){return 1.0-smoothstep(.58,1.0,uLifeEnd);}
    float vs_grow(){return smoothstep(0.0,1.0,uLifeStart);}
    mat2 vs_turn(float a){return mat2(vec2(cos(a),-sin(a)),vec2(sin(a),cos(a)));}
    float vs_rand(float n){return fract(sin(n*127.1+311.7)*43758.5453);}
  
      
      
      void vs_main(inout vec3 aCenter, inout vec4 aData, inout float aUnit, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 normal, inout mat3 normalMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout float vAlpha, inout vec3 vN, inout vec3 vP, inout float vPart, inout float vTone, inout vec2 vUv){
        vec3 p=position,c=aCenter,q=p-c;vec3 n=normal;
        vUv=uv;vAlpha=1.0;vTone=aData.w;vPart=aData.x;
        
      float start=smoothstep(aData.x*.38,aData.x*.38+.60,uLifeStart);
      float close=smoothstep(aData.x*.16,.83+aData.x*.16,uLifeEnd);
      float visible=start*(1.0-close);
      p=c+q*(.78+.22*visible);p.x+=(1.0-start)*.45+close*.32;
      p.y+=(1.0-start)*cos(aData.y)*.17;p.z+=(1.0-start)*sin(aData.y)*.17;
      p*=uSize;vAlpha=visible*vs_fadeEnd()*step(aUnit+.5,uQuantity);
    
        vP=p;vN=normalize(normalMatrix*n);gl_Position=projectionMatrix*modelViewMatrix*vec4(p,1.0);
      }


    
    float fs_sat(float a){return clamp(a,0.0,1.0);}
    float fs_ease(float a){a=fs_sat(a);return 1.0-pow(1.0-a,3.0);}
    float fs_fadeEnd(){return 1.0-smoothstep(.58,1.0,uLifeEnd);}
    float fs_grow(){return smoothstep(0.0,1.0,uLifeStart);}
    mat2 fs_turn(float a){return mat2(vec2(cos(a),-sin(a)),vec2(sin(a),cos(a)));}
    float fs_rand(float n){return fract(sin(n*127.1+311.7)*43758.5453);}
  
      
      void fs_main(inout vec4 gl_FragColor, inout float vAlpha, inout vec3 vN, inout vec3 vP, inout float vTone, inout mat4 viewMatrix){
        float light=dot(normalize(vN),normalize(mat3(viewMatrix)*vec3(-.4,.8,.55)))*.5+.5;
        float shade=mix(.28,.82,smoothstep(.38,.41,light));shade=mix(shade,1.16,smoothstep(.7,.73,light));
        vec3 color=mix(uColor*shade,mix(uColor,vec3(1.0),.7),clamp(vTone,0.0,1.0));
        if(vTone<0.0)color=mix(uColor*.13,vec3(.10,.12,.14),.65)*(.65+shade*.4);
        float alpha=vAlpha;
        float line=pow(.5+.5*sin((vP.y+vP.z*.6)*(10.0+uDetail*8.0)),24.0);color+=uColor*line*.10;
        if(alpha<.003)discard;
        gl_FragColor=vec4(color,clamp(alpha,0.0,1.0));
    
    
  
      }
void vertex(){
vec3 aCenter = vec3(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z);
vec4 aData = vec4(CUSTOM0.w,CUSTOM1.x,CUSTOM1.y,CUSTOM1.z);
float aUnit = CUSTOM1.w;
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 normal = NORMAL;
mat3 normalMatrix = MODELVIEW_NORMAL_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
float vAlpha = float(0);
vec3 vN = vec3(0);
vec3 vP = vec3(0);
float vPart = float(0);
float vTone = float(0);
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aCenter, aData, aUnit, gl_Position, modelViewMatrix, normal, normalMatrix, position, projectionMatrix, uv, vAlpha, vN, vP, vPart, vTone, vUv);
bridge_vUv = vUv;
bridge_vN = vN;
bridge_vP = vP;
bridge_vAlpha = vAlpha;
bridge_vTone = vTone;
bridge_vPart = vPart;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vAlpha = bridge_vAlpha;
vec3 vN = bridge_vN;
vec3 vP = bridge_vP;
float vTone = bridge_vTone;
mat4 viewMatrix = VIEW_MATRIX;
fs_main(gl_FragColor, vAlpha, vN, vP, vTone, viewMatrix);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
