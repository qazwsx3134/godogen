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
#define VARIANT 0
#define TOON 1
uniform float uSize;
uniform float uTime;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;
varying float bridge_vHeat;
varying float bridge_vWide;


    
    void vs_main(inout vec4 aLobe, inout vec4 aSeed, inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout mat4 projectionMatrix, inout vec2 uv, inout float vHeat, inout vec2 vUv, inout float vWide){
      vUv=uv;float t=uTime,launch=1.0-exp(-t*56.0);vWide=step(17.5,aSeed.x);
      vec3 center=aLobe.xyz*vec3(1.0-exp(-t*32.0),launch,1.0-exp(-t*32.0));
      center.xz*=1.0+min(t,.9)*.12;center.y+=max(0.0,t-.3)*.65;
      center*=uSize;center.y-=1.35;
      vec4 mv=modelViewMatrix*vec4(center,1.0);
      float radius=aLobe.w*(1.0+min(t,.9)*.19)*launch;
      mv.z+=radius*.62*uSize*length(modelMatrix[1].xyz);
      mv.xy+=(uv-.5)*radius*3.6*uSize*length(modelMatrix[1].xyz);
      vHeat=1.0-t*1.8+(aLobe.y-1.2)*.18;
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
  
    
    void fs_main(inout vec4 gl_FragColor, inout float vHeat, inout vec2 vUv, inout float vWide){
      float d=length((vUv-.5)*2.0);
      float fade=smoothstep(.0,.018,uTime)*smoothstep(.0,.7,vHeat);
      float alpha=exp(-d*d*mix(5.5,4.8,vWide))*(1.0-smoothstep(.72,1.0,d))*fade*mix(.22,.36,vWide);
      if(alpha<.001)discard;
      gl_FragColor=vec4(min(uColor*2.8,vec3(1.0)),alpha);
    
    
  
    }
void vertex(){
vec4 aLobe = vec4(CUSTOM1.x,CUSTOM1.y,CUSTOM1.z,CUSTOM1.w);
vec4 aSeed = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
vec4 gl_Position = vec4(0);
mat4 modelMatrix = MODEL_MATRIX;
mat4 modelViewMatrix = MODELVIEW_MATRIX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
float vHeat = float(0);
vec2 vUv = vec2(0);
float vWide = float(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aLobe, aSeed, gl_Position, modelMatrix, modelViewMatrix, projectionMatrix, uv, vHeat, vUv, vWide);
bridge_vUv = vUv;
bridge_vHeat = vHeat;
bridge_vWide = vWide;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vHeat = bridge_vHeat;
vec2 vUv = bridge_vUv;
float vWide = bridge_vWide;
fs_main(gl_FragColor, vHeat, vUv, vWide);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
