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
#define KIND 0
#define VARIANT 1
#define TOON 0
uniform float uSize;
uniform float uLifeEnd;
uniform float uLifeOrigin;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;

void vs_main(inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout vec2 vUv){vUv=uv;vec4 mv=modelViewMatrix*vec4(0,0,0,1);mv.xy+=position.xy*uSize*(.35+.65*uLifeOrigin)*(.65+smoothstep(0.0,.1,uLifeEnd)*.35)*length(modelMatrix[1].xyz);gl_Position=projectionMatrix*mv;}

void fs_main(inout vec4 gl_FragColor, inout vec2 vUv){vec2 q=vUv*2.0-1.0;float age=uLifeEnd*.8,r=length(q),a=atan(q.y,q.x);
        float core=exp(-r*r*100.0),sheath=exp(-r*r*24.0),halo=exp(-r*r*5.0),spikes=pow(abs(cos(a*3.0+sin(a*5.0)*.4)),28.0)*exp(-r*7.0);
        float fade=smoothstep(0.0,.012,age)*(1.0-smoothstep(.06,.22,age));
        vec3 blue=pow(uColor,vec3(2.2))*vec3(.1,.65,2.2);gl_FragColor=vec4(mix(blue,vec3(.8,.97,1.0)*1.7,clamp(core+sheath,0.0,1.0)),(core+sheath*.6+halo*.3+spikes*.4)*fade);
    
    
  }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelMatrix = MODEL_MATRIX;
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelMatrix, modelViewMatrix, position, projectionMatrix, uv, vUv);
bridge_vUv = vUv;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vUv);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
