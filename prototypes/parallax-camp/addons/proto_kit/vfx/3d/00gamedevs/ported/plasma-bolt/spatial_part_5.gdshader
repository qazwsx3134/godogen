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
varying float bridge_vFade;


    float vs_hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
    float vs_noise2(vec2 p){
      vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
      return mix(mix(vs_hash(i),vs_hash(i+vec2(1,0)),f.x),mix(vs_hash(i+vec2(0,1)),vs_hash(i+vec2(1)),f.x),f.y);
    }
    float vs_fbm(vec2 p){ return vs_noise2(p)*0.57+vs_noise2(p*2.07+3.1)*0.29+vs_noise2(p*4.13-1.7)*0.14; }
    float vs_band(float x,float width){ return 1.0-smoothstep(width,width+0.004,abs(x)); }
    #define SRC_PI 3.14159265359
  
        vec3 vs_bolt(float h,float id,float age){float a=id*2.399963,l=.8+vs_hash(vec2(id,3.0))*.8;
          float cell=h*6.0,tick=floor(age*24.0+id*.31),j=mix(vs_hash(vec2(floor(cell)+id*13.0,tick)),vs_hash(vec2(floor(cell)+1.0+id*13.0,tick)),fract(cell))-.5;
          float r=h*l;vec2 radial=vec2(cos(a),sin(a)),side=vec2(-sin(a),cos(a));
          return vec3(.025+h*(.12+vs_hash(vec2(id,5.0))*.35),radial*r+side*j*.48*sin(h*SRC_PI));}
        vec3 vs_pointAt(float h,float part,float age){float id=mod(part,12.0),growth=smoothstep(0.0,.08,age);
          if(part<12.0)return vs_bolt(h*growth,id,age);
          if(part<24.0){float root=.42+mod(id,3.0)*.09,a=id*2.399963+.65;return vs_bolt(root*growth,id,age)+vec3(h*.12,cos(a)*h*.58,sin(a)*h*.58)*growth;}
          float a=(part-24.0)*2.399963+.4,r=.15+age*3.5+h*.3;return vec3(.08+age*.4,cos(a)*r,sin(a)*r);}
        void vs_main(inout float aPart, inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout float vFade, inout vec2 vUv){vUv=uv;float age=uLifeEnd*.8,id=mod(aPart,12.0),scale=uSize*(.35+.65*uLifeOrigin),h=position.x;
          vec4 mv=modelViewMatrix*vec4(vs_pointAt(h,aPart,age)*scale,1.0);
          vec4 a=modelViewMatrix*vec4(vs_pointAt(max(0.0,h-.004),aPart,age)*scale,1.0),b=modelViewMatrix*vec4(vs_pointAt(min(1.0,h+.004),aPart,age)*scale,1.0);
          vec2 delta=b.xy-a.xy,side=length(delta)<.00001?vec2(0,1):normalize(vec2(-delta.y,delta.x));
          float width=(id<3.0?.22:.105)*(1.0-h*.8);if(aPart>=12.0)width*=.48;if(aPart>=24.0)width=.045*sin(h*SRC_PI)+.008;
          mv.xy+=side*position.y*width*scale*length(modelMatrix[1].xyz);
          float end=.42+vs_hash(vec2(id,7.0))*.34;
          vFade=smoothstep(0.0,.016,age)*(1.0-smoothstep(.35,end,age));
          if(aPart>=12.0)vFade*=.35+.65*step(.35,vs_hash(vec2(id,floor(age*25.0+id))));
          if(aPart>=24.0)vFade*=1.0-smoothstep(.12,.36,age);
          gl_Position=projectionMatrix*mv;}

void fs_main(inout vec4 gl_FragColor, inout float vFade, inout vec2 vUv){float d=abs(vUv.y*2.0-1.0),core=1.0-smoothstep(.12,.27,d),edge=exp(-d*d*13.0),halo=exp(-d*d*4.0);
        vec3 blue=pow(uColor,vec3(2.2))*vec3(.12,.65,2.2),c=mix(blue,vec3(.8,.96,1.0)*1.5,core);
        float alpha=max(core,edge*.65+halo*.3)*(1.0-smoothstep(.75,1.0,d))*vFade;
        gl_FragColor=vec4(c,alpha);
    
    
  }
void vertex(){
float aPart = CUSTOM0.x;
vec4 gl_Position = vec4(0);
mat4 modelMatrix = MODEL_MATRIX;
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
float vFade = float(0);
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aPart, gl_Position, modelMatrix, modelViewMatrix, position, projectionMatrix, uv, vFade, vUv);
bridge_vUv = vUv;
bridge_vFade = vFade;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vFade = bridge_vFade;
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vFade, vUv);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
