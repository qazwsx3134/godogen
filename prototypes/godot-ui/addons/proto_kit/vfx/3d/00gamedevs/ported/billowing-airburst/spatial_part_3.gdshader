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
#define KIND 3
#define VARIANT 11
#define TOON 1
uniform float uSize;
uniform float uDetail;
uniform float uTime;
uniform vec3 uColor;
varying vec2 bridge_vLocal;

void vs_main(inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 vLocal){
      vLocal=position.xy*vec2(6.4,4.4);
      float scale=length(modelMatrix[1].xyz)*uSize;
      vec4 mv=modelViewMatrix*vec4(0,0,0,1);mv.z+=1.35*scale;
      mv.xy+=vLocal*scale;gl_Position=projectionMatrix*mv;
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
  
    void fs_main(inout vec4 gl_FragColor, inout vec2 vLocal){
      float t=uTime,r=length(vLocal);
      float burst=smoothstep(0.0,.012,t)*(1.0-smoothstep(.028,.090,t));
      float disk=exp(-pow(r/1.13,6.0));
      float halo=exp(-r*r*.8)*.16;
      float alpha=(disk+halo)*burst;
      if(alpha<.002)discard;
      vec3 color=mix(mix(uColor,vec3(1.0,.63,.18),.7),vec3(1.0,.98,.82),disk);
      gl_FragColor=vec4(color*1.65*0.5,clamp(alpha,0.0,1.0));
    
    
  
    }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelMatrix = MODEL_MATRIX;
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 vLocal = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelMatrix, modelViewMatrix, position, projectionMatrix, vLocal);
bridge_vLocal = vLocal;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
vec2 vLocal = bridge_vLocal;
fs_main(gl_FragColor, vLocal);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
