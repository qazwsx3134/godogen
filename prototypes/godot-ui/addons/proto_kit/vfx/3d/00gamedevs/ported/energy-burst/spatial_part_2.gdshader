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
uniform float uQuantity;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vStroke;
varying float bridge_vHalfLength;
varying float bridge_vFade;


    float vs_hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
    float vs_noise2(vec2 p){
      vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
      return mix(mix(vs_hash(i),vs_hash(i+vec2(1,0)),f.x),mix(vs_hash(i+vec2(0,1)),vs_hash(i+vec2(1)),f.x),f.y);
    }
    float vs_fbm(vec2 p){ return vs_noise2(p)*0.57+vs_noise2(p*2.07+3.1)*0.29+vs_noise2(p*4.13-1.7)*0.14; }
    float vs_band(float x,float width){ return 1.0-smoothstep(width,width+0.004,abs(x)); }
    #define SRC_PI 3.14159265359
  
          vec3 vs_direction(float id){float a=id*2.39996;return normalize(vec3(cos(a),.12+pow(vs_hash(vec2(id,3.0)),2.0)*1.5,sin(a)));}
          vec3 vs_pointOnArc(float id,float h){vec3 dir=vs_direction(id);vec3 side=normalize(cross(dir,vec3(0,1,0)));vec3 up=cross(side,dir);
            float cell=h*8.0,i=floor(cell),f=fract(cell),frame=floor(uTime*18.0);
            float j=mix(vs_hash(vec2(id*3.0+frame,i)),vs_hash(vec2(id*3.0+frame,i+1.0)),f)-.5;
            float k=mix(vs_hash(vec2(id*7.0+frame,i+13.0)),vs_hash(vec2(id*7.0+frame,i+14.0)),f)-.5;
            float fine=h*64.0,fi=floor(fine);float micro=(mix(vs_hash(vec2(id+frame,fi)),vs_hash(vec2(id+frame,fi+1.0)),fract(fine))-.5)*.04;
            return dir*h*(2.4+vs_hash(vec2(id,9.0))*1.25)+(side*(j*.65+micro)+up*k*.40)*sin(h*SRC_PI*.9)+vec3(0,sin(h*SRC_PI)*(.25+vs_hash(vec2(id,12.0))*.55),0);}
          float vs_pulse(float t,float start,float end){return smoothstep(start,start+.035,t)*(1.0-smoothstep(end-.06,end,t));}
          vec3 vs_branchPoint(float id,float branch,float role,float h,float growth){
            if(role<.5)return vs_pointOnArc(id,h*growth);
            float fork=role<1.5?.3125:.625,offset=role<1.5?1.0:-1.0;vec3 dir=vs_direction(id),side=normalize(cross(dir,vec3(0,1,0))),split=normalize(dir*.5+side*offset*.85+vec3(0,.28,0));
            float child=clamp((growth-fork)/(1.0-fork),0.0,1.0),lengthBranch=.5+vs_hash(vec2(branch,7.0))*.85,cell=h*13.0,i=floor(cell),frame=floor(uTime*15.0)+branch;
            float jag=mix(vs_hash(vec2(frame,i)),vs_hash(vec2(frame,i+1.0)),fract(cell))-.5;
            return vs_pointOnArc(id,fork*growth)+split*h*lengthBranch*child+side*jag*.22*sin(h*SRC_PI)*child;
          }
          void vs_main(inout float aRole, inout float aUnit, inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout float vFade, inout float vHalfLength, inout vec2 vStroke){float branch=position.z,id=aUnit,h=(position.x+position.y)*.5,t=uTime;
            float delay=.035+vs_hash(vec2(id,5.0))*.085;float growth=clamp((t-delay)*6.5,0.0,1.0);
            vec3 p0=vs_branchPoint(id,branch,aRole,position.x,growth),p1=vs_branchPoint(id,branch,aRole,position.y,growth);float width=.17+vs_hash(vec2(id,2.0))*.08;
            if(aRole>.5)width*=.48*(1.0-h*.75);
            float main=vs_pulse(t,delay,.58+vs_hash(vec2(id,4.0))*.22);
            float echo=vs_pulse(t,.78+vs_hash(vec2(id,8.0))*.27,.93+vs_hash(vec2(id,8.0))*.27)*.8;
            echo+=vs_pulse(t,1.28+vs_hash(vec2(id,6.0))*.34,1.41+vs_hash(vec2(id,6.0))*.34)*.6;
            echo+=vs_pulse(t,1.85+vs_hash(vec2(id,11.0))*.12,1.97+vs_hash(vec2(id,11.0))*.12)*step(.72,vs_hash(vec2(id,12.0)))*.4;
            float flicker=aRole<.5?1.0:.45+.45*vs_hash(vec2(branch,floor(t*(14.0+aRole*3.0))));
            vFade=max(main,echo)*growth*step(aUnit,uQuantity-.5)*flicker*min(1.0,sqrt(12.0/uQuantity));width*=1.0-smoothstep(.88,1.0,h)*.78;
            p0*=uSize;p0.y-=1.20;p1*=uSize;p1.y-=1.20;vec4 m0=modelViewMatrix*vec4(p0,1),m1=modelViewMatrix*vec4(p1,1);vec2 delta=m1.xy-m0.xy;float len=length(delta);vec2 along=len<.0001?vec2(1,0):delta/len;
            width*=uSize*length(modelMatrix[1].xyz);vec4 mv=mix(m0,m1,uv.x);mv.xy+=(along*(uv.x*2.0-1.0)+vec2(-along.y,along.x)*(uv.y*2.0-1.0))*width;
            vHalfLength=len/max(width,.00001)*.5;vStroke=vec2((uv.x*2.0-1.0)*(vHalfLength+1.0),uv.y*2.0-1.0);
            gl_Position=projectionMatrix*mv;}


    float fs_styleStep(float edge,float value){float aa=max(fwidth(value),.012);return smoothstep(edge-aa,edge+aa,value);}
    vec3 fs_styleColor(vec3 tint,float light){
      vec3 c=mix(tint*.22,tint*.72,fs_styleStep(.38,light));
      return mix(c,mix(tint,vec3(1.0),.38)*1.04,fs_styleStep(.70,light));
    }
    vec3 fs_styleHeat(vec3 tint,float heat){
      vec3 c=mix(tint*.24,tint*1.05,fs_styleStep(.38,heat));
      return mix(c,mix(tint,vec3(1.0,.88,.51),.62),fs_styleStep(.70,heat));
    }
  
          void fs_main(inout vec4 gl_FragColor, inout float vFade, inout float vHalfLength, inout vec2 vStroke){float edge=length(vec2(max(0.0,abs(vStroke.x)-vHalfLength),vStroke.y)),core=exp(-edge*edge*180.0),sheath=exp(-edge*edge*40.0),halo=exp(-edge*edge*6.0);
            vec3 cyan=pow(uColor,vec3(.55))*vec3(.65,1.4,1.0),c=mix(uColor,cyan,sheath)+vec3(core*1.5);
            float alpha=(core+sheath*.65+halo*.18)*(1.0-smoothstep(.8,1.0,edge))*vFade;
            gl_FragColor=vec4(c,alpha);
    
    
  gl_FragColor.rgb*=min(1.0,gl_FragColor.a);gl_FragColor.a=min(1.0,gl_FragColor.a)*.6;}
void vertex(){
float aRole = CUSTOM0.y;
float aUnit = CUSTOM0.x;
vec4 gl_Position = vec4(0);
mat4 modelMatrix = MODEL_MATRIX;
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
float vFade = float(0);
float vHalfLength = float(0);
vec2 vStroke = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aRole, aUnit, gl_Position, modelMatrix, modelViewMatrix, position, projectionMatrix, uv, vFade, vHalfLength, vStroke);
bridge_vStroke = vStroke;
bridge_vHalfLength = vHalfLength;
bridge_vFade = vFade;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vFade = bridge_vFade;
float vHalfLength = bridge_vHalfLength;
vec2 vStroke = bridge_vStroke;
fs_main(gl_FragColor, vFade, vHalfLength, vStroke);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
