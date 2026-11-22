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
#define VARIANT 11
#define TOON 1
uniform float uSize;
uniform float uTime;
uniform vec3 uBurstOffset;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;
varying float bridge_vArc;


    
    vec3 vs_ribbon(float u,float t, inout float aArc){
      float phase=aArc*3.8+uBurstOffset.x*.11;
      float angle=u*(3.35-aArc*.45)+aArc*2.6+t*.55;
      float launch=1.0-exp(-max(0.0,t-.035)*24.0);
      float r=(2.02+aArc*.16+.20*sin(u*13.0-t*3.4+phase)+.10*sin(u*29.0+t*5.0))*launch;
      vec3 p=vec3(cos(angle)*r,sin(u*9.0-t*3.8+phase)*.30+sin(u*19.0+t*4.0)*.11,sin(angle)*r);
      float tilt=.35+aArc*.86;float y=p.y*cos(tilt)-p.z*sin(tilt);p.z=p.y*sin(tilt)+p.z*cos(tilt);p.y=y;
      p.y+=aArc*.16-(1.0-aArc)*(u-.5)*.85;return p;
    }
    void vs_main(inout float aArc, inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout mat4 projectionMatrix, inout vec2 uv, inout float vArc, inout vec2 vUv){
      vUv=uv;vArc=aArc;float t=max(0.0,uTime-aArc*.035);
      vec4 mv=modelViewMatrix*vec4(vs_ribbon(uv.x,t, aArc)*uSize,1.0);
      vec4 next=modelViewMatrix*vec4(vs_ribbon(uv.x+.004,t, aArc)*uSize,1.0);
      vec2 tangent=next.xy-mv.xy;tangent=length(tangent)>.0001?normalize(tangent):vec2(1,0);
      float width=(.10+.34*pow(max(0.0,sin(uv.x*3.141593)),.7))*(.68+.32*sin(uv.x*23.0-t*6.0+aArc));
      width*=1.0-smoothstep(.5,1.0,t)*.55;
      float twist=uv.x*10.0-t*4.0+aArc*.9;width*=(.65+.35*sin(twist))*mix(1.0,.24,aArc);
      mv.z+=(uv.y-.5)*width*sin(twist)*uSize*length(modelMatrix[1].xyz);
      mv.xy+=vec2(-tangent.y,tangent.x)*(uv.y-.5)*width*uSize*length(modelMatrix[1].xyz);
      gl_Position=projectionMatrix*mv;
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
  
    
    
    float fs_hash3(vec3 p){p=fract(p*.3183099+vec3(.11,.17,.23));p*=17.0;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
    float fs_noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
      return mix(mix(mix(fs_hash3(i),fs_hash3(i+vec3(1,0,0)),f.x),mix(fs_hash3(i+vec3(0,1,0)),fs_hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(fs_hash3(i+vec3(0,0,1)),fs_hash3(i+vec3(1,0,1)),f.x),mix(fs_hash3(i+vec3(0,1,1)),fs_hash3(i+vec3(1,1,1)),f.x),f.y),f.z);}
    float fs_billow(vec3 p){return fs_noise3(p)*.65+fs_noise3(p*2.07+7.3)*.25+fs_noise3(p*4.11-3.1)*.10;}
    float fs_flameHeat(float age,float pattern){
      return 1.0-smoothstep(.26,.59,age+(.5-pattern)*.24);
    }
    vec3 fs_heatColor(vec3 base,float heat){
      vec3 flame=mix(base*vec3(1.25,.75,.45),vec3(1.0,.34,.025),.45);
      return mix(flame,vec3(1.0,.96,.79),smoothstep(.72,1.12,heat));
    }
  
    void fs_main(inout vec4 gl_FragColor, inout float vArc, inout vec2 vUv){
      float t=uTime-vArc*.035;
      float folds=fs_noise3(vec3(vUv.x*15.0,vUv.y*1.9,uTime*1.8)+uBurstOffset+vArc*5.0);
      float tear=smoothstep(mix(.58,.34,vArc),mix(1.06,.85,vArc),t);
      float matter=folds*.65+sin(vUv.x*3.141593)*.35;
      float coverage=smoothstep(tear-.05,tear+.065,matter);
      float edge=abs(vUv.y-.5)*2.0;
      float alpha=(1.0-smoothstep(.62,1.0,edge))*pow(max(0.0,sin(vUv.x*3.141593)),.42)*coverage;
      alpha*=smoothstep(.055,.15,t)*(1.0-smoothstep(.75,1.08,t));
      if(alpha<.005)discard;
      float crease=pow(.5+.5*sin(vUv.x*33.0-uTime*7.0+vArc*4.0),2.0);
      vec3 tint=uColor;
      tint=mix(tint,vec3(1.0,.83,.37),crease*.55);
      gl_FragColor=vec4(tint*(1.25+folds*.65)*(1.0-vArc*.18)*0.5,alpha);
    
    
  
    }
void vertex(){
float aArc = CUSTOM0.x;
vec4 gl_Position = vec4(0);
mat4 modelMatrix = MODEL_MATRIX;
mat4 modelViewMatrix = MODELVIEW_MATRIX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
float vArc = float(0);
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aArc, gl_Position, modelMatrix, modelViewMatrix, projectionMatrix, uv, vArc, vUv);
bridge_vUv = vUv;
bridge_vArc = vArc;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vArc = bridge_vArc;
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vArc, vUv);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
