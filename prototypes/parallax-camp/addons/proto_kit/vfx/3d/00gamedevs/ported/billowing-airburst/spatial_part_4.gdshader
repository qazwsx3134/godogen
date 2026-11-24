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
uniform float uDetail;
uniform vec3 uBurstOffset;
varying vec2 bridge_vWave;


    void vs_main(inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 vWave){
      float t=max(0.0,uTime-.035),radius=1.5*min(5.8,.58+t*28.0);
      vWave=position.xy*2.0;vec4 mv=modelViewMatrix*vec4(0,0,0,1);
      mv.xy+=vWave*radius*uSize*length(modelMatrix[1].xyz);gl_Position=projectionMatrix*mv;
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
  
    void fs_main(inout vec4 gl_FragColor, inout vec2 vWave){
      float r=length(vWave);if(r<.70||r>1.02)discard;
      float a=atan(vWave.y,vWave.x);
      float contour=.88+sin(a*11.0+uBurstOffset.x)*.042+sin(a*19.0+uBurstOffset.y)*.021+sin(a*5.0+uBurstOffset.z)*.027;
      float width=(.027+.008*sin(a*7.0+uBurstOffset.y))/1.5;
      float band=1.0-smoothstep(width*.4,width,abs(r-contour));
      float life=smoothstep(.035,.055,uTime)*(1.0-smoothstep(.045,.250,uTime));
      float alpha=band*life*.50;
      if(alpha<.003)discard;
      gl_FragColor=vec4(vec3(.36,.33,.28),alpha);
    
    
  
    }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelMatrix = MODEL_MATRIX;
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 vWave = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelMatrix, modelViewMatrix, position, projectionMatrix, vWave);
bridge_vWave = vWave;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
vec2 vWave = bridge_vWave;
fs_main(gl_FragColor, vWave);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
