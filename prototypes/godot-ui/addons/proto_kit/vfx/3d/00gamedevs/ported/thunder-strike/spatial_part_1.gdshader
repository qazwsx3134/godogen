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
#define VARIANT 5
#define TOON 0
#define SPELL 3
uniform float uSize;
uniform float uTime;
uniform float uStopTime;
uniform float uQuantity;
uniform float uLifeEnd;
uniform float uLifeStart;
uniform float uStretch;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;
varying float bridge_vFade;
varying float bridge_vLight;


#if SPELL == 12 || SPELL == 9

#endif

    float vs_hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
    float vs_noise2(vec2 p){
      vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
      return mix(mix(vs_hash(i),vs_hash(i+vec2(1,0)),f.x),mix(vs_hash(i+vec2(0,1)),vs_hash(i+vec2(1)),f.x),f.y);
    }
    float vs_fbm(vec2 p){ return vs_noise2(p)*0.57+vs_noise2(p*2.07+3.1)*0.29+vs_noise2(p*4.13-1.7)*0.14; }
    float vs_band(float x,float width){ return 1.0-smoothstep(width,width+0.004,abs(x)); }
    #define SRC_PI 3.14159265359
  
      void vs_main(inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec4 seed, inout vec2 uv, inout float vFade, inout float vLight, inout vec2 vUv){vUv=uv;float life=clamp(uTime/2.6,0.0,1.0);float alive=smoothstep(0.0,.025,life)*(1.0-smoothstep(.70,1.0,life));float f=fract(seed.x+uTime*(.25+seed.w*.3)),a=seed.y*6.283;vec3 p=vec3(0);float scale=.035+seed.w*.055;vFade=sin(f*SRC_PI)*alive*.7;vLight=.45+seed.w*.4;
        #if SPELL == 0
          float t=max(0.0,uTime-seed.x*.6);p=vec3((seed.y-.5)*(1.0+t),-1.25+t*(1.4+seed.z)-t*t*.2,(seed.z-.5)*(.4+t*.5));scale*=.6;vFade*=1.0-smoothstep(.55,1.0,life);
        #elif SPELL == 1 || SPELL == 7 || SPELL == 11
          p=vec3(-.38*uSize-f*2.8,cos(a)*(f*.4+.1),sin(a)*(f*.4+.1));scale*=1.0-f*.5;
          #if SPELL == 11
            p.yz*=uSize;scale*=.23*uSize;
          #endif
        #elif SPELL == 2
          p=vec3((floor(seed.y*5.0)-2.0)*.65,f*1.2,(floor(seed.z*5.0)-2.0)*.65);scale*=.6;
        #elif SPELL == 3
          float t=max(0.0,uTime-.23-seed.x*.1),r=(1.0-exp(-t*4.0))*(.8+seed.z*2.8);p=vec3(cos(a)*r,-1.3+sin(min(t,1.0)*SRC_PI)*seed.z*1.35,sin(a)*r);vFade*=smoothstep(.0,.04,t)*(1.0-smoothstep(.35,.95,t))*(1.0-step(.13,seed.w));scale*=uSize*1.4;
        #elif SPELL == 4
          float end=seed.x<.5?-1.0:1.0;p=vec3(end*2.4+end*f*.2/max(uStretch,.001),cos(a)*(.3+f*.7)*uSize,sin(a)*(.3+f*.7)*uSize);vFade*=smoothstep(0.0,.25,uTime);
        #elif SPELL == 5
          p=vec3(cos(a+uTime*.3)*(.3+f),f*1.3,sin(a+uTime*.3)*(.3+f))*uSize;scale*=.42*uSize;vLight=.35;
        #elif SPELL == 6
          p=vec3(cos(a)*(.3+seed.z),f*1.8,sin(a)*(.3+seed.z));scale*=.7;
        #elif SPELL == 8
          float across=seed.y*2.0-1.0,delay=abs(across)*.17+sin(across*7.0)*.025;
          float born=(.34+delay)*3.2+seed.x*.26,t=max(0.0,uTime-born),r=.7+born/3.2*2.1+.4+t*1.2;
          p=vec3(sin(across*1.6)*r,max(-1.27,-.55+t*(.35+seed.z*.7)-t*t*2.4),cos(across*1.6)*r-.5);
          vLight=.8+seed.w*.18;vFade=smoothstep(.0,.06,t)*(1.0-smoothstep(.40,1.0,t))*.88;
          scale=seed.x<.18?.08+seed.w*.08:.035+seed.w*.045;scale*=1.0+step(p.y,-1.26)*.55;
        #elif SPELL == 9
          float bank=floor(seed.y*uQuantity),angle=bank*SRC_PI*2.0/uQuantity+.32+(seed.z-.5)*1.55;
          if(uQuantity>3.5)angle=bank*SRC_PI*2.0/uQuantity+.32+(seed.z-.5)*1.55*3.0/uQuantity;
          float cycle=fract((uStopTime<0.0?uTime:uStopTime)*.24+bank*.31);if(uStopTime>=0.0)cycle=min(.999,cycle+uLifeEnd*.90);
          float local=clamp((cycle-.10-seed.z*.25)*2.4,0.0,1.0),fall=smoothstep(.02,.88,local),crest=.82-.52*fall;
          float v=crest*(1.0-f),r=.10+v*1.23,bankHeight=pow(sin(seed.z*SRC_PI),.65)*(.17+smoothstep(.0,.16,cycle)*.25);
          p=vec3(cos(angle)*r*.72,.035+bankHeight*(1.0-f)*(1.0-fall*.85),sin(angle)*r*.72);
          scale=.025+seed.w*.025;vLight=.45+seed.w*.35;vFade*=smoothstep(.27,.4,cycle)*(1.0-smoothstep(.82,.99,cycle))*smoothstep(.0,.7,uLifeStart)*(1.0-smoothstep(.7,1.0,uLifeEnd));
        #elif SPELL == 10
          float outAge=max(.0,life-.36),r=life<.36?(1.0-life/.36)*1.6:outAge*(2.8+seed.w*2.1);
          float sy=seed.z*2.0-1.0,radial=sqrt(max(.0,1.0-sy*sy));a+=outAge*(.6+seed.w);
          p=vec3(cos(a)*radial*r,sy*r,sin(a)*radial*r);vLight=.72+seed.w*.25;vFade*=1.0-smoothstep(.64+seed.x*.13,.83+seed.x*.15,life);
        #elif SPELL == 12
          float bubble=floor(seed.y*uQuantity),ba=bubble*2.4,br=bubble<.5?0.0:.55+mod(bubble,2.0)*.35;
          if(abs(uQuantity-7.0)>.1)ba=(bubble-1.0)*SRC_PI*2.0/max(1.0,uQuantity-1.0);
          float flight=uStopTime<0.0?fract(uTime*.24+bubble*.238-.65):max(0.0,uLifeEnd*1.55-fract(bubble*1.4*.23)*.3-.62);
          float splash=flight*4.0,angle=seed.x*SRC_PI*2.0;p=vec3(cos(ba)*br+cos(angle)*splash*.3,max(.04,.16+splash*.5-splash*splash*.7),sin(ba)*br+sin(angle)*splash*.3);
          scale*=.6;vLight=.6+seed.w*.3;vFade=smoothstep(.0,.025,flight)*(1.0-smoothstep(.15,.28,flight))*smoothstep(.0,.3,uLifeStart)*(1.0-smoothstep(.85,1.0,uLifeEnd));
        #endif
        #if SPELL == 0 || SPELL == 3 || SPELL == 8 || SPELL == 10
          p.y=-1.3+(p.y+1.3)*uSize;p.xz*=uSize;
        #elif SPELL == 9
          p*=uSize;
        #endif
        vec4 mv=modelViewMatrix*vec4(p,1.0);vec2 card=position.xy*scale;
        #if SPELL == 3
          vec2 along=(modelViewMatrix*vec4(cos(a),.5,sin(a),0)).xy;along=length(along)<.0001?vec2(1,0):normalize(along);card=along*card.x*4.0+vec2(-along.y,along.x)*card.y*.8;
        #endif
        #if SPELL == 7 || SPELL == 11
          card.x*=2.5;
        #endif
        mv.xy+=card;gl_Position=projectionMatrix*mv;
      }


    float fs_toonStep(float edge,float x){float aa=max(fwidth(x),.008);return smoothstep(edge-aa,edge+aa,x);}
    vec3 fs_toonShade(vec3 tint,float light){
      vec3 c=mix(tint*.28,tint*1.08,fs_toonStep(.40,light));
      return mix(c,mix(tint,vec3(1.0),.53)*1.15,fs_toonStep(.69,light));
    }
  
      void fs_main(inout vec4 gl_FragColor, inout float vFade, inout float vLight, inout vec2 vUv){vec2 q=vUv*2.0-1.0;float a=1.0-smoothstep(.45,1.0,length(q));
        #if SPELL == 1 || SPELL == 2 || SPELL == 10
          a=1.0-smoothstep(.5,.9,abs(q.x)+abs(q.y));
        #elif SPELL == 3
          a=exp(-q.y*q.y*35.0)*(1.0-smoothstep(.4,1.0,abs(q.x)));
        #elif SPELL == 7 || SPELL == 11
          a=(1.0-smoothstep(.1,.7,abs(q.y)))*(1.0-smoothstep(.65,1.0,abs(q.x)));
        #endif
        vec3 color=fs_toonShade(uColor,vLight);
        #if SPELL == 3
          color=uColor*1.3+vec3(exp(-dot(q,q)*14.0)*1.8);
        #endif
        if(a*vFade<.003)discard;gl_FragColor=vec4(color,a*vFade*uDetail);
    
    
  }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec4 seed = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
vec2 uv = UV;
float vFade = float(0);
float vLight = float(0);
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelViewMatrix, position, projectionMatrix, seed, uv, vFade, vLight, vUv);
bridge_vUv = vUv;
bridge_vFade = vFade;
bridge_vLight = vLight;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vFade = bridge_vFade;
float vLight = bridge_vLight;
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vFade, vLight, vUv);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
