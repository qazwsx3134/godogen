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
#define KIND 7
#define VARIANT 1
#define TOON 0
#define UTILITY 3
uniform float uSize;
uniform float uTime;
uniform float uLifeStart;
uniform float uLifeEnd;
uniform float uLifeOrigin;
uniform float uStopTime;
uniform float uEndDuration;
uniform float uStretch;
uniform float uQuantity;
uniform float uSpread;
uniform float uDetail;
uniform vec3 uColor;
varying vec3 bridge_vN;
varying float bridge_vAlpha;
varying float bridge_vTone;


    
    float vs_sat(float a){return clamp(a,0.0,1.0);}
    float vs_ease(float a){a=vs_sat(a);return 1.0-pow(1.0-a,3.0);}
    float vs_fadeEnd(){return 1.0-smoothstep(.58,1.0,uLifeEnd);}
    float vs_grow(){return smoothstep(0.0,1.0,uLifeStart);}
    mat2 vs_turn(float a){return mat2(vec2(cos(a),-sin(a)),vec2(sin(a),cos(a)));}
    float vs_rand(float n){return fract(sin(n*127.1+311.7)*43758.5453);}
  
    
    void vs_main(inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 normal, inout mat3 normalMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec4 seed, inout float vAlpha, inout vec3 vN, inout float vTone){
      vec3 p=vec3(0.0);float size=.009+seed.w*.016;float a=seed.x*6.283185;
      float t=uTime,age=0.0;vAlpha=1.0;vTone=seed.w;
      #if UTILITY == 0
        float f=vs_sat(t/.65);float spread=vs_ease(f/.7);float angle=-1.7+seed.x*2.7+spread*.9;
        p=vec3(cos(angle)*(1.15+seed.z*1.2),.1+(seed.y-.5)*.5,sin(angle)*(1.15+seed.z*1.2));
        p*=uSize;vAlpha=smoothstep(.02,.13,f)*(1.0-smoothstep(.25+seed.y*.3,1.0,f));size*=1.0-f*.6;
      #elif UTILITY == 1
        float x=-2.2+seed.x*4.4;age=t-(.1+seed.x*.62);
        p=vec3(x,.05+max(0.0,age)*(1.3+seed.y)-max(0.0,age)*max(0.0,age)*2.2,sin(seed.x*27.0)*.20+(seed.z-.5)*age*.8);
        p.yz*=uSize;vAlpha=smoothstep(0.0,.08,age)*(1.0-smoothstep(.3,.85,age))*(1.0-smoothstep(1.5,1.8,t));
      #elif UTILITY == 2 || UTILITY == 4
        float f=fract(seed.y+t*.30);float radial=1.1+seed.z*.28;
        #if UTILITY == 2
          p=vec3(.7+seed.z*.1,.9+cos(a)*radial,sin(a)*radial);
        #elif UTILITY == 4
          p=vec3((seed.z-.5)*.25,1.45+cos(a)*1.4,sin(a)*1.04);
        #endif
        p*=uSize;vAlpha=sin(f*3.14159)*vs_grow()*vs_fadeEnd()*(1.0-uLifeEnd)*.7;
      #elif UTILITY == 3
        float f=vs_sat(t/.55);float r=.15+vs_ease(f)*(.45+seed.y*.9);
        p=vec3(.6+f*seed.z,.9+cos(a)*r,sin(a)*r);p*=uSize;
        vAlpha=smoothstep(0.0,.07,f)*(1.0-smoothstep(.25+seed.z*.25,1.0,f));
      #elif UTILITY == 5 || UTILITY == 8
        float travel=.62,cycle=t/travel+seed.y,f=fract(cycle),birth=(floor(cycle)-seed.y)*travel;
        float live=step(0.0,birth)*(uStopTime<0.0?1.0:1.0-step(uStopTime+.00001,birth));
        #if UTILITY == 5
          float path=1.0-f,lane=floor(seed.z*3.0)*2.0944;p.x=2.4-f*4.8;p.y=sin(path*3.0+lane)*sin(f*3.14159)*.34;p.z=cos(path*3.0+lane)*sin(f*3.14159)*.34;size*=.6;
        #else
          p.x=-2.4+f*4.8;p.y=cos(a)*(.08+f*.46)*seed.z;p.z=sin(a)*(.08+f*.46)*seed.z;size*=1.2;
        #endif
        p.yz*=uSize;vAlpha=live*smoothstep(0.0,.08,f)*(1.0-smoothstep(.78,1.0,f))*vs_fadeEnd();
      #elif UTILITY == 6
        float f=vs_sat(t/2.2);float rise=vs_ease((f-seed.y*.22)/.7),r=(.2+seed.z*.9)*sin(rise*2.1);
        p=vec3(cos(a+rise)*r,rise*(1.5+seed.y*1.2),sin(a+rise)*r)*uSize;
        vAlpha=smoothstep(seed.y*.15,seed.y*.15+.13,f)*(1.0-smoothstep(.48+seed.z*.15,1.0,f));
      #elif UTILITY == 7
        
        float cell=floor(seed.x*max(9.0,uQuantity)),phi=cell*2.39996,r=cell<.5?0.0:.55+.8*mod(cell,3.0)/2.0;
        age=t-(.43+cell/uQuantity*1.05);float f=vs_sat(age/.55);
        p=vec3(cos(phi)*r,0.0,sin(phi)*r)+vec3(cos(a)*f*.65,sin(f*3.14159)*(.2+seed.y*.5),sin(a)*f*.65)*uSize;
        p.xz+=(uSpread-1.0)*vec2(cos(phi)*r,sin(phi)*r);
        vAlpha=smoothstep(0.0,.03,age)*(1.0-smoothstep(.2,.55,age))*step(cell+.5,uQuantity);
      #endif
      vAlpha*=smoothstep(.42,.90,seed.w);
      #if UTILITY == 2 || UTILITY == 4
        size*=.52;vAlpha*=.38;
      #elif UTILITY == 5
        vAlpha*=.45;
      #elif UTILITY == 8
        vAlpha*=.55;
      #endif
      vec3 q=position*size*uSize;
      #if UTILITY == 0
        q.x*=3.2;q.y*=.35;q.z*=.65;q.xz=vs_turn(-1.7+seed.x*2.7+vs_ease(vs_sat(uTime/.65)/.7)*.9+1.5708)*q.xz;
      #elif UTILITY == 1
        q.xz*=.55;q.y*=2.2;
      #elif UTILITY == 3 || UTILITY == 7
        q.y*=2.0;
      #elif UTILITY == 6
        q.xz*=.6;q.y*=1.6;
      #endif
      #if UTILITY == 5 || UTILITY == 8
        q.x/=max(uStretch,.001);
      #endif
      p+=q;vN=normalize(normalMatrix*normal);gl_Position=projectionMatrix*modelViewMatrix*vec4(p,1.0);
    }


    void fs_main(inout vec4 gl_FragColor, inout float vAlpha, inout vec3 vN){if(vAlpha<.003)discard;float light=dot(normalize(vN),normalize(vec3(-.4,.8,.55)))*.5+.5;
      vec3 color=mix(uColor*.65,mix(uColor,vec3(1.0),.65),step(.48,light));
      gl_FragColor=vec4(color,vAlpha*.82);
    
    
  }
  
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 normal = NORMAL;
mat3 normalMatrix = MODELVIEW_NORMAL_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec4 seed = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
float vAlpha = float(0);
vec3 vN = vec3(0);
float vTone = float(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelViewMatrix, normal, normalMatrix, position, projectionMatrix, seed, vAlpha, vN, vTone);
bridge_vN = vN;
bridge_vAlpha = vAlpha;
bridge_vTone = vTone;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vAlpha = bridge_vAlpha;
vec3 vN = bridge_vN;
fs_main(gl_FragColor, vAlpha, vN);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
