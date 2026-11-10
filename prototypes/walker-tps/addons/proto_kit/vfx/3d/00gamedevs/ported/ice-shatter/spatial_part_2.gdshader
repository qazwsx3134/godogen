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
#define VARIANT 3
#define TOON 1
uniform float uSize;
uniform float uTime;
uniform float uQuantity;
uniform float uDetail;
uniform vec3 uColor;
varying vec3 bridge_vN;
varying vec3 bridge_vCrystal;
varying float bridge_vFade;


        void vs_main(inout vec3 aCenter, inout float aSeed, inout float aUnit, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 normal, inout mat3 normalMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec3 vCrystal, inout float vFade, inout vec3 vN){vCrystal=position;float t=uTime,growth=smoothstep(0.0,0.16,t),flight=max(0.0,t-0.24);vec3 p=position*growth*uSize;float a=aSeed*6.28318;float spin=flight*(aSeed-0.5)*2.0;mat2 rot=mat2(vec2(cos(spin),-sin(spin)),vec2(sin(spin),cos(spin)));p.xy=rot*p.xy;vec3 n=normal;n.xy=rot*n.xy;vN=normalMatrix*n;
          p+=aCenter+vec3(cos(a)*flight*1.5,-1.35+flight*(1.3+aSeed)-flight*flight*2.0,sin(a)*flight*1.5);vFade=(1.0-smoothstep(0.8,1.7,t))*step(aUnit,uQuantity-.5);gl_Position=projectionMatrix*modelViewMatrix*vec4(p,1.0);}


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
  
        void fs_main(inout vec4 gl_FragColor, inout vec3 vCrystal, inout float vFade, inout vec3 vN){float light=0.3+max(dot(normalize(vN),normalize(vec3(-0.6,0.8,0.3))),0.0);
          float n=fs_noise2(vCrystal.xy*8.0+vCrystal.z*5.0);float crack=1.0-smoothstep(0.03,0.12,abs(sin(vCrystal.y*17.0+vCrystal.x*23.0+n*4.0)));
          #if TOON == 1
            crack=1.0-smoothstep(.04,.13,abs(sin(vCrystal.y*7.0+vCrystal.x*9.0+n)));
          #endif
          float fracture=smoothstep(0.10,0.35,uTime)*crack;float dissolve=smoothstep(0.0,0.14,n-(uTime-0.8)*0.65);
          vec3 c=uColor*(0.3+light*0.6+fracture*0.8)+vec3(pow(light,6.0)*0.3);
#if TOON == 1
            c=fs_styleColor(uColor,.14+light*.55+fracture*.22);
          #endif
          gl_FragColor=vec4(c,vFade*dissolve);
    
    
  }
void vertex(){
vec3 aCenter = vec3(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z);
float aSeed = CUSTOM0.w;
float aUnit = CUSTOM1.x;
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 normal = NORMAL;
mat3 normalMatrix = MODELVIEW_NORMAL_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec3 vCrystal = vec3(0);
float vFade = float(0);
vec3 vN = vec3(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aCenter, aSeed, aUnit, gl_Position, modelViewMatrix, normal, normalMatrix, position, projectionMatrix, vCrystal, vFade, vN);
bridge_vN = vN;
bridge_vCrystal = vCrystal;
bridge_vFade = vFade;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
vec3 vCrystal = bridge_vCrystal;
float vFade = bridge_vFade;
vec3 vN = bridge_vN;
fs_main(gl_FragColor, vCrystal, vFade, vN);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
