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
#define VARIANT 3
#define TOON 0
uniform float uSize;
uniform float uLifeEnd;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;


      void vs_main(inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout vec2 vUv){vUv=uv;vec4 mv=modelViewMatrix*vec4(0,0,0,1);mv.xy+=position.xy*uSize*(.5+uLifeEnd*2.0);gl_Position=projectionMatrix*mv;}


      void fs_main(inout vec4 gl_FragColor, inout vec2 vUv){vec2 q=vUv*2.0-1.0;float t=uLifeEnd;float a=exp(-dot(q,q)*5.5)*(1.0-smoothstep(.0,.28,t))*smoothstep(.0,.025,t)*.24;
        gl_FragColor=vec4(uColor,a);
    
    
  }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelViewMatrix, position, projectionMatrix, uv, vUv);
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
