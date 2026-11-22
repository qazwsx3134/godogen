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
#define VARIANT 10
#define TOON 0
#define SWEEP_LAYER 1
uniform float uSize;
uniform float uTime;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vSweep;
varying float bridge_vTaper;
varying float bridge_vSeed;


    
    
    
    float vs_sweepHead(){return mix(.012,1.0,smoothstep(.08,.32,uTime));}
    float vs_sweepTail(){return smoothstep(.42,.85,uTime);}
    float vs_sweepTaper(float x){return pow(max(0.0,sin(x*3.14159265)),.45);}
  
    #if SWEEP_LAYER == 3
    
    #endif
    void vs_main(inout vec4 gl_Position, inout mat4 modelViewMatrix, inout mat4 projectionMatrix, inout vec4 seed, inout vec2 uv, inout float vSeed, inout vec2 vSweep, inout float vTaper){
      float tail=vs_sweepTail(),head=vs_sweepHead(),x=uv.x;
      float along=mix(tail,head,x),taper=vs_sweepTaper(x);
      float angle=-2.35+along*5.235987756;
      float radius=3.0;
      vSeed=0.0;
      #if SWEEP_LAYER == 0
        radius-=(1.0-uv.y)*.9*taper;
      #elif SWEEP_LAYER == 1
        radius+=(uv.y-.5)*.48*taper;
      #elif SWEEP_LAYER == 2
        radius+=(uv.y-.5)*.056*taper;
      #else
        vSeed=seed.x;
        radius-=(.09+seed.x*.68)*taper;
        radius+=(uv.y-.5)*(.012+seed.y*.018)*taper;
        radius+=sin(along*19.0+seed.z*6.283-uTime*4.0)*.012*taper;
      #endif
      vec3 p=vec3(cos(angle)*radius,1.0,sin(angle)*radius);
      #if SWEEP_LAYER == 0
        p.y+=sin(x*3.14159265)*(1.0-uv.y)*.045;
      #elif SWEEP_LAYER == 3
        p.y+=.025;
      #endif
      vSweep=vec2(x,uv.y);vTaper=taper;
      gl_Position=projectionMatrix*modelViewMatrix*vec4(p*uSize,1.0);
    }
  


    
    void fs_main(inout vec4 gl_FragColor, inout float vSeed, inout vec2 vSweep){
      float x=vSweep.x,y=vSweep.y;
      float fade=smoothstep(0.0,.04,uTime)*(1.0-smoothstep(.58,.85,uTime));
      float ends=smoothstep(0.0,.035,x)*(1.0-smoothstep(.985,1.0,x));
      float alpha=0.0;vec3 color=uColor;
      #if SWEEP_LAYER == 0
        float flow=y*49.0+x*8.0-uTime*5.0+sin(x*14.0)*.45;
        float grain=pow(.5+.5*sin(flow),10.0)*(1.0-smoothstep(.6,2.0,fwidth(flow)));
        float edge=smoothstep(0.0,.9,y);
        alpha=(.08+.35*edge+grain*.12*uDetail)*smoothstep(0.0,.22,y);
        color=mix(uColor*.68,uColor*1.1,edge);
      #elif SWEEP_LAYER == 1
        float d=abs(y-.5)*2.0;
        alpha=exp(-d*d*6.0)*(1.0-smoothstep(.72,1.0,d))*.34*uDetail;
        color=mix(uColor,vec3(.28,.85,1.0),.18);
      #elif SWEEP_LAYER == 2
        float d=abs(y-.5)*2.0;
        alpha=(1.0-smoothstep(.12,1.0,d))*.98;
        color=mix(uColor,vec3(.85,1.0,1.0),.80);
      #else
        float ribbon=1.0-smoothstep(.1,1.0,abs(y-.5)*2.0);
        float stream=smoothstep(.02+vSeed*.12,.25+vSeed*.12,x)*(1.0-smoothstep(.72+vSeed*.15,1.0,x));
        alpha=ribbon*stream*(.26+.16*uDetail);
        color=mix(uColor,vec3(.3,.8,1.0),.28);
      #endif
      alpha*=fade*ends;
      if(alpha<.002)discard;
      gl_FragColor=vec4(color,alpha);
    
    
  
    }
  
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec4 seed = vec4(0);
vec2 uv = UV;
float vSeed = float(0);
vec2 vSweep = vec2(0);
float vTaper = float(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelViewMatrix, projectionMatrix, seed, uv, vSeed, vSweep, vTaper);
bridge_vSweep = vSweep;
bridge_vTaper = vTaper;
bridge_vSeed = vSeed;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vSeed = bridge_vSeed;
vec2 vSweep = bridge_vSweep;
fs_main(gl_FragColor, vSeed, vSweep);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
