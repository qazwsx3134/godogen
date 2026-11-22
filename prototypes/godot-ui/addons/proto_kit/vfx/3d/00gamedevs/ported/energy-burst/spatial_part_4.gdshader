// 00GameDevs MIT, 2026 @00vchannel; native Godot port of original GLSL.
// Authoring source: tools/vfx/three_port; Compatibility spatial, no fragment texture loops.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_premul_alpha;
uniform mat4 source_to_group;
uniform float source_draw_start = 0.0;
uniform float source_draw_count = -1.0;
uniform int source_vertices_per_instance = 1;
uniform float source_instance_count = 1.0;
varying flat float source_draw;
varying flat float source_instance;
#define KIND 3
#define VARIANT 1
#define TOON 1
uniform float uSize;
uniform float uTime;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;


        void vs_main(inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout vec2 vUv){vUv=uv;vec4 mv=modelViewMatrix*vec4(0,-1.20+uSize*0.12,0,1);mv.xy+=position.xy*uSize*(1.1+min(uTime,.25)*3.6)*length(modelMatrix[1].xyz);gl_Position=projectionMatrix*mv;}


    float fs_styleStep(float edge,float value){float aa=max(fwidth(value),.012);return smoothstep(edge-aa,edge+aa,value);}
    vec3 fs_styleColor(vec3 tint,float light){
      vec3 c=mix(tint*.22,tint*.72,fs_styleStep(.38,light));
      return mix(c,mix(tint,vec3(1.0),.38)*1.04,fs_styleStep(.70,light));
    }
    vec3 fs_styleHeat(vec3 tint,float heat){
      vec3 c=mix(tint*.24,tint*1.05,fs_styleStep(.38,heat));
      return mix(c,mix(tint,vec3(1.0,.88,.51),.62),fs_styleStep(.70,heat));
    }
  
    float fs_hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
    float fs_noise2(vec2 p){
      vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
      return mix(mix(fs_hash(i),fs_hash(i+vec2(1,0)),f.x),mix(fs_hash(i+vec2(0,1)),fs_hash(i+vec2(1)),f.x),f.y);
    }
    float fs_fbm(vec2 p){ return fs_noise2(p)*0.57+fs_noise2(p*2.07+3.1)*0.29+fs_noise2(p*4.13-1.7)*0.14; }
    float fs_band(float x,float width){ return 1.0-smoothstep(width,width+0.004,abs(x)); }
    #define SRC_PI 3.14159265359
  
        void fs_main(inout vec4 gl_FragColor, inout vec2 vUv){vec2 p=vUv*2.0-1.0;float r=length(p),a=atan(p.y,p.x),t=uTime;float hot=exp(-r*r*160.0),inner=exp(-r*r*40.0),halo=exp(-r*r*5.0);float spokes=pow(abs(cos(a*3.0)),35.0)*exp(-r*6.0)+exp(-p.y*p.y*1500.0-abs(p.x)*4.0);float fade=smoothstep(0.0,0.035,t)*(1.0-smoothstep(.18,.52,t));vec3 c=mix(uColor,pow(uColor,vec3(.55))*vec3(.65,1.4,1.0),inner)+vec3(hot*2.0);
          gl_FragColor=vec4(c,(hot+inner*.6+halo*.22+spokes*.32)*fade);
    
    
  
          #if TOON == 1
            gl_FragColor.rgb*=min(1.0,gl_FragColor.a);gl_FragColor.a=min(1.0,gl_FragColor.a)*.6;
          #endif
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
