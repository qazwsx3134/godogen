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
#define VARIANT 1
#define TOON 1
uniform float uSize;
uniform float uDetail;
uniform vec3 uColor;
uniform float uTime;
varying vec2 bridge_vUv;


    
    void vs_main(inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout vec2 vUv){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}
  


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
  
      void fs_main(inout vec4 gl_FragColor, inout vec2 vUv){vec2 p=vUv*2.0-1.0;float r=length(p),t=uTime;float radius=(1.0-exp(-t*3.5))*0.82;float wave=exp(-pow((r-radius)*45.0,2.0));float dust=exp(-pow((r-radius+0.07)*14.0,2.0))*fs_fbm(p*8.0)*0.45;float fade=pow(max(0.0,1.0-t/2.4),2.0);float alpha=(wave*0.7+dust)*fade;
        #if VARIANT == 0
          alpha*=0.22;
        #elif VARIANT == 1
          alpha=(wave*.22+dust*.28+exp(-r*r*12.0)*.18)*smoothstep(.0,.08,t)*(1.0-smoothstep(.32,.8,t));
        #elif VARIANT == 2
          float corrugation=fs_noise2(p*14.0);float compress=pow(max(0.0,cos((r-radius)*110.0+corrugation*2.0)),12.0);
          float wake=exp(-pow((r-radius+0.055)*20.0,2.0));alpha=(wave*0.24+compress*wake*0.20)*fade*(1.0-smoothstep(0.4,1.1,t));
        #else
          float a=atan(p.y,p.x);alpha=(wave*0.35+fs_band(r-radius*0.55,0.004)*step(0.1,cos(a*12.0)))*fade;
        #endif
        vec3 c=uColor*(.7+wave);
        #if TOON == 1
          c=fs_styleColor(uColor,.35+wave*.5);
          #if VARIANT == 1
            c=pow(uColor,vec3(.55))*vec3(.65,1.4,1.0)+vec3(wave*.2);
          #endif
        #endif
        gl_FragColor=vec4(c,alpha);
    
    
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
