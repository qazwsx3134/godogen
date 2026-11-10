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
#define VARIANT 15
#define TOON 0
#define GC_RIPPLE_GLOW 1
uniform float uSize;
uniform float uTime;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vRipple;
varying float bridge_vAge;
varying float bridge_vFade;
varying float bridge_vSeed;


    
    void vs_main(inout vec3 aEnd, inout vec3 aStart, inout vec2 aTime, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout float vAge, inout float vFade, inout vec2 vRipple, inout float vSeed){
      float age=uTime-aTime.x,localAge=age;
      vFade=smoothstep(0.0,.085,localAge)*(1.0-smoothstep(1.10,1.55,age));
      float open=1.0-pow(1.0-clamp(localAge/.16,0.0,1.0),3.0);
      float radius=.82*(.45+.55*open);
      vec3 forward=normalize(aEnd-aStart),right=normalize(cross(forward,vec3(0,1,0))),side=normalize(cross(right,forward));
      vec3 across=right,up=side,center=aStart;
      float extent=1.0;
      #ifdef GC_RIPPLE_GLOW
        extent=1.9;
        
        
        vec3 planeNormal=normalize(cross(across,up));
        vec3 viewNormal=mat3(modelViewMatrix)*planeNormal;
        vec3 viewCenter=(modelViewMatrix*vec4(center*uSize,1.0)).xyz;
        center+=planeNormal*.004*sign(dot(viewNormal,-viewCenter));
      #endif
      #ifdef GC_RIPPLE_FEATHER
        extent=1.2;
      #endif
      
      radius*=mix(.48,1.0,sqrt(vFade));
      vec3 p=center+(across*position.x+up*position.y)*radius*extent;
      vRipple=position.xy*extent;vAge=localAge;vSeed=aTime.y;
      gl_Position=projectionMatrix*modelViewMatrix*vec4(p*uSize,1.0);
    }


    float fs_grHash(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
    float fs_grNoise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
      return mix(mix(fs_grHash(i),fs_grHash(i+vec2(1,0)),f.x),mix(fs_grHash(i+vec2(0,1)),fs_grHash(i+vec2(1,1)),f.x),f.y);}
  
    
    void fs_main(inout vec4 gl_FragColor, inout float vAge, inout float vFade, inout vec2 vRipple, inout float vSeed){
      float r=length(vRipple);if(vFade<=0.0||r>=1.9)discard;
      float mist=fs_grNoise(vRipple*4.2+vec2(vAge*.17,-vAge*.13)+vSeed*11.0);
      float haze=.7+.3*mist;
      float bloom=exp(-r*r*1.05)*.54+exp(-r*r*5.0)*.18;
      float bloomSpread=.22+.78*smoothstep(.28,1.10,r);
      float alpha=bloom*haze*bloomSpread*(1.0-smoothstep(1.35,1.9,r))*vFade*(.8+.2*min(uDetail,1.5));
      if(alpha<.002)discard;
      vec3 color=mix(uColor,vec3(1.0,.88,.55),.25)*1.8;
      gl_FragColor=vec4(color,alpha);
    
    
  
    }
void vertex(){
vec3 aEnd = vec3(CUSTOM0.w,CUSTOM1.x,CUSTOM1.y);
vec3 aStart = vec3(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z);
vec2 aTime = vec2(CUSTOM1.z,CUSTOM1.w);
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
float vAge = float(0);
float vFade = float(0);
vec2 vRipple = vec2(0);
float vSeed = float(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aEnd, aStart, aTime, gl_Position, modelViewMatrix, position, projectionMatrix, vAge, vFade, vRipple, vSeed);
bridge_vRipple = vRipple;
bridge_vAge = vAge;
bridge_vFade = vFade;
bridge_vSeed = vSeed;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vAge = bridge_vAge;
float vFade = bridge_vFade;
vec2 vRipple = bridge_vRipple;
float vSeed = bridge_vSeed;
fs_main(gl_FragColor, vAge, vFade, vRipple, vSeed);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
