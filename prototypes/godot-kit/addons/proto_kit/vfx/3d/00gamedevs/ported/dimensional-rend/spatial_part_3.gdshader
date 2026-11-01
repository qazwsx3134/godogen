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
#define KIND 6
#define VARIANT 1
#define TOON 0
uniform float uSize;
uniform float uTime;
uniform float uQuantity;
uniform float uSpread;
uniform float uPanelCount;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vLocal;
varying float bridge_vAlpha;


      
      const float vs_constant_REND_RELEASE=1.0; const float vs_constant_REND_EXIT=1.2;
      
      float vs_rh(float n){return fract(sin(n*127.1+32.36308927)*43758.5453);}
      float vs_rl(float i){return 1.35+vs_rh(i+71.0)*2.05;}
      float vs_rw(float i){return .036+vs_rh(i+89.0)*.024;}
      
      
      vec2 vs_rendPanel(float i,float x,float side){
        float taper=(1.0-x)*.5;
        float height=(vs_rw(i)*18.0+.18)*mix(.117,.5,vs_rh(i+151.0));
        float skew=mix(-.65,1.65,vs_rh(i+173.0));
        return vec2(x+side*taper*skew,side*taper*height);
      }
      float vs_rb(float i){return .2+.36*i/max(1.0,uQuantity-1.0);}
      mat3 vs_rf(float i){
        float a=i<.5?.38:vs_rh(i+109.0)*6.283185;
        float tilt=i<.5?.12:(vs_rh(i+93.0)-.5)*2.4,twist=(vs_rh(i+19.0)-.5)*2.6;
        vec3 d=normalize(vec3(cos(a),sin(a),tilt)),s=normalize(cross(vec3(0.0,0.0,1.0),d)),n=cross(d,s);
        s=s*cos(twist)+n*sin(twist);return mat3(d,s,cross(d,s));
      }
      vec3 vs_rc(float i){
        vec3 c=vec3(vs_rh(i+11.0)-.5,0.0,vs_rh(i+57.0)-.5)*vec3(3.6,0.0,2.8)*uSpread;
        if(i<.5)c.xz=vec2(0.0);
        
        
        c.y=abs(vs_rf(i)[0].y)*vs_rl(i)*uSize+(i<.5?.04*uSize:.10*uSize+vs_rh(i+31.0)*.45*uSpread);
        return c;
      }
      
      vec3 vs_rendPanelCenter(float i){
        vec3 c=vec3((vs_rh(i+211.0)-.5)*3.6,0.0,(vs_rh(i+239.0)-.5)*2.8)*uSpread;
        c.y=abs(vs_rf(i)[0].y)*vs_rl(i)*uSize+(.03+vs_rh(i+263.0)*.42)*uSize;
        return c;
      }
      
      float vs_rendShardScale(vec4 seed){
        return seed.w<.58?mix(.9,1.2,seed.z):mix(.2,.4,seed.z);
      }
      vec3 vs_rendShardShape(vec4 seed){
        float lengthScale=mix(.65,2.4,vs_rh(seed.x*997.0+307.0));
        float widthScale=mix(.2,1.4,vs_rh(seed.y*997.0+331.0));
        float apex=mix(-1.4,1.4,vs_rh(seed.z*997.0+359.0))*.577350269*lengthScale;
        return vec3(lengthScale,widthScale,apex);
      }
      
      
      vec3 vs_rendShardVertex(vec2 corner,vec3 shape,vec4 seed){
        float top=step(0.0,corner.y);
        float topWidth=seed.x<.5?0.0:mix(.35,1.1,vs_rh(seed.w*997.0+383.0));
        return vec3(corner.x*shape.x*mix(1.0,topWidth,top)+top*shape.z,corner.y*shape.y,0.0);
      }
      float vs_rendShardRadius(vec3 shape,vec4 seed){
        float h=.577350269;
        return max(max(length(vs_rendShardVertex(vec2(-h,-h),shape,seed)),length(vs_rendShardVertex(vec2(h,-h),shape,seed))),
          max(length(vs_rendShardVertex(vec2(h,h),shape,seed)),length(vs_rendShardVertex(vec2(-h,h),shape,seed))));
      }
      vec3 vs_rendCenter(){
        vec3 center=vec3(0.0);
        
        
        for(int j=0;j<32;j++){float index=uQuantity-1.0-float(j);if(index<0.0)break;center+=vs_rc(index);}
        return center/max(1.0,uQuantity);
      }
    
      
      void vs_main(inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout float vAlpha, inout vec2 vLocal){
        vLocal=position.xy;
        vAlpha=smoothstep(vs_constant_REND_RELEASE,vs_constant_REND_RELEASE+.025,uTime)*(1.0-smoothstep(vs_constant_REND_RELEASE+.08,vs_constant_REND_RELEASE+.18,uTime));
        vec4 mv=modelViewMatrix*vec4(vs_rendCenter(),1.0);
        mv.xy+=position.xy*.8*uSize*length(modelViewMatrix[1].xyz);
        gl_Position=projectionMatrix*mv;
      }


      
      
      void fs_main(inout vec4 gl_FragColor, inout float vAlpha, inout vec2 vLocal){
        if(vAlpha<.003)discard;
        float diamond=abs(vLocal.x)+abs(vLocal.y)*1.15;
        float core=1.0-smoothstep(.03,.28,diamond);
        float halo=pow(max(0.0,1.0-diamond),2.0);
        float alpha=vAlpha*(core*.75+halo*.65)*(.75+.25*uDetail);
        vec3 color=mix(uColor,vec3(1.0),core*.86);
        if(alpha<.003)discard;gl_FragColor=vec4(color,clamp(alpha,0.0,1.0));
    
    
  
      }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
float vAlpha = float(0);
vec2 vLocal = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelViewMatrix, position, projectionMatrix, vAlpha, vLocal);
bridge_vLocal = vLocal;
bridge_vAlpha = vAlpha;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vAlpha = bridge_vAlpha;
vec2 vLocal = bridge_vLocal;
fs_main(gl_FragColor, vAlpha, vLocal);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
