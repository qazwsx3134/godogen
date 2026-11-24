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
#define VARIANT 2
#define TOON 1
uniform float uSize;
uniform float uTime;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;
varying float bridge_vFade;
varying float bridge_vSeed;
varying vec3 bridge_vKeyLight;


        void vs_main(inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout float vFade, inout vec3 vKeyLight, inout float vSeed, inout vec2 vUv, inout mat4 viewMatrix){vUv=uv;float id=position.z;vSeed=id;float seed=fract(id*.618034),t=max(.0,uTime-seed*.14);
          float a=id*2.39996-t*.25,grow=1.0-exp(-t*6.0),roll=t*(1.5+seed*.4);
          float r=.16+grow*(1.05+seed*.45)+t*.28;
          vec3 p=vec3(cos(a)*r,-1.35+(sin(min(roll,3.14159))*.58+.08)*grow,sin(a)*r);p.y=-1.35+(p.y+1.35)*uSize;p.xz*=uSize;
          vec4 mv=modelViewMatrix*vec4(p,1.0);mv.xy+=position.xy*vec2(1.15+seed*.5,.85+seed*.3)*grow*(1.0+t*.25)*uSize*length(modelMatrix[1].xyz);
          vFade=smoothstep(.0,.08,t)*(1.0-smoothstep(.80+seed*.25,1.65+seed*.2,t));vKeyLight=normalize(mat3(viewMatrix)*vec3(-.45,.8,.55));gl_Position=projectionMatrix*mv;
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
  
    float fs_hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
    float fs_noise2(vec2 p){
      vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
      return mix(mix(fs_hash(i),fs_hash(i+vec2(1,0)),f.x),mix(fs_hash(i+vec2(0,1)),fs_hash(i+vec2(1)),f.x),f.y);
    }
    float fs_fbm(vec2 p){ return fs_noise2(p)*0.57+fs_noise2(p*2.07+3.1)*0.29+fs_noise2(p*4.13-1.7)*0.14; }
    float fs_band(float x,float width){ return 1.0-smoothstep(width,width+0.004,abs(x)); }
    #define SRC_PI 3.14159265359
  
    vec3 fs_noiseGradient(vec2 p){
      vec2 i=floor(p),f=fract(p),u=f*f*(3.0-2.0*f),du=6.0*f*(1.0-f);
      float a=fs_hash(i),b=fs_hash(i+vec2(1,0)),c=fs_hash(i+vec2(0,1)),d=fs_hash(i+vec2(1,1));
      return vec3(mix(mix(a,b,u.x),mix(c,d,u.x),u.y),du.x*mix(b-a,d-c,u.y),du.y*mix(c-a,d-b,u.x));
    }
    vec3 fs_curlFlow(vec3 p,float t){
      
      vec3 ax=fs_noiseGradient(p.yz+vec2(7.3-t*0.22,1.7+t*0.11));
      vec3 ay=fs_noiseGradient(p.zx+vec2(13.1+t*0.13,5.4-t*0.19));
      vec3 az=fs_noiseGradient(p.xy+vec2(2.9-t*0.16,17.2+t*0.14));
      return vec3(az.z-ay.y,ax.z-az.y,ay.z-ax.y)*0.65;
    }
  
    vec2 fs_smokeOptics(vec2 q,vec2 densityGradient,float density,vec3 lightDir){
      float dome=sqrt(max(0.015,1.0-dot(q,q)));
      vec3 n=normalize(vec3(q-densityGradient*0.13,dome));
      float wrap=clamp(dot(n,lightDir)*0.7+0.3,0.0,1.0);
      float thickness=dome*(0.3+density*1.1);
      float transmission=exp(-thickness*1.7);
      float rim=pow(1.0-dome,2.0)*wrap*0.20;
      return vec2((0.16+wrap*0.70)*mix(0.55,1.0,transmission)+rim,1.0-exp(-thickness*1.8));
    }
  
        void fs_main(inout vec4 gl_FragColor, inout float vFade, inout vec3 vKeyLight, inout float vSeed, inout vec2 vUv){vec2 q=vUv*2.0-1.0;float turn=uTime*(.9+fract(vSeed*.37)) +vSeed*2.4;q=mat2(vec2(cos(turn),-sin(turn)),vec2(sin(turn),cos(turn)))*q;
          vec3 n=fs_noiseGradient(q*2.6+vec2(vSeed*17.0,-uTime*.65));float d=length(q)+(n.x-.5)*.30;vec2 optics=fs_smokeOptics(q,n.yz*2.6,n.x,vKeyLight);
          float a=(1.0-smoothstep(.68,.96,d))*smoothstep(.13,.40,n.x)*vFade;
          vec3 c=uColor*(.12+optics.x*.4);
          #if TOON == 1
            c=fs_styleColor(uColor*.52,.16+optics.x*.55+n.x*.18);
          #endif
          gl_FragColor=vec4(c,a*.86);
    
    
  
        }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelMatrix = MODEL_MATRIX;
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
float vFade = float(0);
vec3 vKeyLight = vec3(0);
float vSeed = float(0);
vec2 vUv = vec2(0);
mat4 viewMatrix = VIEW_MATRIX;
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelMatrix, modelViewMatrix, position, projectionMatrix, uv, vFade, vKeyLight, vSeed, vUv, viewMatrix);
bridge_vUv = vUv;
bridge_vFade = vFade;
bridge_vSeed = vSeed;
bridge_vKeyLight = vKeyLight;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vFade = bridge_vFade;
vec3 vKeyLight = bridge_vKeyLight;
float vSeed = bridge_vSeed;
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vFade, vKeyLight, vSeed, vUv);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
