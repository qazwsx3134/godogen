// 00GameDevs MIT, 2026 @00vchannel; native Godot port of original GLSL.
// Authoring source: tools/vfx/three_port; Compatibility spatial, no fragment texture loops.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, shadows_disabled, fog_disabled, blend_mix;
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
#define GC_ARROW 1
uniform float uSize;
uniform float uTime;
uniform float uDetail;
uniform vec3 uColor;
uniform float uTextureDensity;
varying vec3 bridge_vNormal;
varying vec3 bridge_vViewPosition;
varying vec3 bridge_vLocal;
varying vec3 bridge_vArrowSurface;
varying vec2 bridge_vRingUv;
varying float bridge_vAge;
varying float bridge_vRoute;
varying float bridge_vDissolve;
varying float bridge_vAlive;
varying float bridge_vSeed;
varying float bridge_vSourceDistance;
varying vec2 bridge_vChainClip;
varying vec2 bridge_vSpritePlane;
varying vec2 bridge_vSpriteHeading;
varying float bridge_vSpriteWidth;


    float vs_gcPenetration(float age){float t=clamp((age-.35)/.08,0.0,1.0);return .32*(1.0-pow(1.0-t,3.0));}
    float vs_gcTipDistance(float age,float span){return pow(clamp(age/.35,0.0,1.0),1.5)*span+vs_gcPenetration(age);}
  
    
    
    
    void vs_main(inout vec3 aEnd, inout vec3 aStart, inout vec2 aTime, inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 normal, inout mat3 normalMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout float vAge, inout float vAlive, inout vec3 vArrowSurface, inout float vDissolve, inout vec3 vLocal, inout vec3 vNormal, inout vec2 vRingUv, inout float vRoute, inout float vSeed, inout float vSourceDistance, inout vec3 vViewPosition){
      float age=uTime-aTime.x;
      vec3 delta=aEnd-aStart;float span=length(delta);vec3 forward=delta/span;
      vec3 right=normalize(cross(forward,vec3(0,1,0))),side=normalize(cross(right,forward));
      vec3 local=aStart+forward*(vs_gcTipDistance(age,span)-.32+position.y)+right*position.x+side*position.z;
      vLocal=local;vNormal=normalize(normalMatrix*(forward*normal.y+right*normal.x+side*normal.z));
      vec4 view=modelViewMatrix*vec4(local*uSize,1.0);vViewPosition=-view.xyz;
      vArrowSurface=position;vRingUv=uv;vAge=age;vRoute=clamp(dot(local-aStart,forward)/span,0.0,1.0);vDissolve=clamp((age-1.10)/.75,0.0,1.0);vSeed=aTime.y;
      vSourceDistance=vs_gcTipDistance(age,span)-.32+position.y;
      vAlive=step(0.0,age)*(1.0-step(1.85,age));
      gl_Position=projectionMatrix*view;
    }


    #ifndef GC_ARROW
      
    #endif
    
    
    
    
    #ifdef GC_SPRITE
      
    #endif
    #ifdef GC_ARROW
      
    #endif
    float fs_gcHash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
    float fs_gcLiquidHash(vec3 p){p=fract(p*.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
    float fs_gcLiquidNoise(vec3 p){
      vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
      return mix(mix(mix(fs_gcLiquidHash(i),fs_gcLiquidHash(i+vec3(1,0,0)),f.x),mix(fs_gcLiquidHash(i+vec3(0,1,0)),fs_gcLiquidHash(i+vec3(1,1,0)),f.x),f.y),
        mix(mix(fs_gcLiquidHash(i+vec3(0,0,1)),fs_gcLiquidHash(i+vec3(1,0,1)),f.x),mix(fs_gcLiquidHash(i+vec3(0,1,1)),fs_gcLiquidHash(i+vec3(1,1,1)),f.x),f.y),f.z);
    }
    void fs_main(inout vec4 gl_FragColor, inout bool isOrthographic, inout float vAge, inout float vAlive, inout vec3 vArrowSurface, inout vec2 vChainClip, inout float vDissolve, inout vec3 vLocal, inout vec3 vNormal, inout vec2 vRingUv, inout float vRoute, inout float vSeed, inout float vSourceDistance, inout vec2 vSpriteHeading, inout vec2 vSpritePlane, inout float vSpriteWidth, inout vec3 vViewPosition){
      if(vAlive<.5||vLocal.y<0.0)discard;
      #ifndef GC_ARROW
        if(min(vChainClip.x,vChainClip.y)<0.0)discard;
      #endif
      vec2 ringUv=vRingUv;vec3 surfaceNormal=vNormal;float spriteHalo=1.0;
      #ifdef GC_SPRITE
        vec2 ellipse=vSpritePlane/vec2(.095,.17);
        float ellipseRadius=length(ellipse);
        vec2 radial=ellipse/max(ellipseRadius,.00001);
        float tubeDistance=(ellipseRadius-1.0)/max(length(radial/vec2(.095,.17)),.00001);
        float tube=clamp(tubeDistance/.031,-1.0,1.0);
        #ifdef GC_HALO
          if(abs(tubeDistance)<.031||abs(tubeDistance)>.054)discard;
          spriteHalo=1.0-smoothstep(.031,.054,abs(tubeDistance));
        #else
          if(abs(tubeDistance)>.031)discard;
        #endif
        ringUv=vec2(fract(atan(ellipse.y,ellipse.x)/6.283185),acos(tube)/6.283185);
        vec2 radialNormal=normalize(radial/vec2(.095*vSpriteWidth,.17));
        vec2 lateral=vec2(vSpriteHeading.y,-vSpriteHeading.x);
        surfaceNormal=vec3((lateral*radialNormal.x+vSpriteHeading*radialNormal.y)*tube,sqrt(max(0.0,1.0-tube*tube)));
      #endif
      #ifdef GC_ARROW
        if(vSourceDistance<0.0)discard;
      #endif
      float grain=fs_gcHash(floor(ringUv*vec2(24.0,6.0))+vSeed*83.0);
      float threshold=vRoute*.78+grain*.22;
      if(vDissolve>threshold)discard;
      float edge=step(.001,vDissolve)*(1.0-smoothstep(0.0,.045,threshold-vDissolve));
      #ifdef GC_HALO
        gl_FragColor=vec4(uColor*1.10,(.035+edge*.18)*uDetail*spriteHalo);
      #else
        vec3 n=normalize(surfaceNormal),viewDirection=isOrthographic?vec3(0,0,1):normalize(vViewPosition),light=normalize(vec3(-.35,.8,.65));
        float diffuse=clamp(dot(n,light)*.65+.35,0.0,1.0);
        float shine=pow(max(0.0,dot(n,normalize(light+viewDirection))),38.0);
          
          
          vec3 gold=mix(uColor*vec3(.075,.065,.025),uColor*vec3(.32,.28,.12),smoothstep(.13,.82,diffuse));
          gold+=uColor*shine*.22;
          #ifdef GC_ARROW
            
            vec3 liquid=vArrowSurface*13.5*.65*uTextureDensity;
          #else
          vec2 angle=ringUv*6.283185;
          float radius=2.2+.45*cos(angle.y);
          vec3 liquid=vec3(cos(angle.x)*radius,sin(angle.x)*radius,.45*sin(angle.y))*.65*uTextureDensity;
          #endif
          liquid+=vec3(-vAge*.58*uTextureDensity,vSeed*3.7,vAge*.26*uTextureDensity);
          vec3 warp=vec3(fs_gcLiquidNoise(liquid*.73+vec3(0,0,vAge*.16)),
            fs_gcLiquidNoise(liquid*.73+vec3(13.7,5.2,-vAge*.19)),fs_gcLiquidNoise(liquid*.73+vec3(2.4,19.1,8.3)));
          float field=fs_gcLiquidNoise(liquid+warp*2.1)*.88+fs_gcLiquidNoise(liquid*2.07+warp)*.12;
          float stream=pow(.5+.5*sin(field*36.0),5.0);
          float filament=pow(.5+.5*sin(field*72.0+warp.x*2.0),12.0);
          float water=(stream*1.38+filament*.34)*(.6+.4*diffuse)*min(uDetail,1.4);
          gold+=uColor*vec3(.90,.80,.40)*water;
        float impact=exp(-max(0.0,vAge-.35)*18.0)*step(.35,vAge);
        gold+=uColor*impact*.08;
        gold+=mix(uColor,vec3(1.0,.97,.85),.4)*edge*.85*min(uDetail,1.3);
        gl_FragColor=vec4(gold,1.0);
      #endif
      
    
    
  
    }
void vertex(){
vec3 aEnd = vec3(CUSTOM0.w,CUSTOM1.x,CUSTOM1.y);
vec3 aStart = vec3(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z);
vec2 aTime = vec2(CUSTOM1.z,CUSTOM1.w);
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 normal = NORMAL;
mat3 normalMatrix = MODELVIEW_NORMAL_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
float vAge = float(0);
float vAlive = float(0);
vec3 vArrowSurface = vec3(0);
float vDissolve = float(0);
vec3 vLocal = vec3(0);
vec3 vNormal = vec3(0);
vec2 vRingUv = vec2(0);
float vRoute = float(0);
float vSeed = float(0);
float vSourceDistance = float(0);
vec3 vViewPosition = vec3(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aEnd, aStart, aTime, gl_Position, modelViewMatrix, normal, normalMatrix, position, projectionMatrix, uv, vAge, vAlive, vArrowSurface, vDissolve, vLocal, vNormal, vRingUv, vRoute, vSeed, vSourceDistance, vViewPosition);
bridge_vNormal = vNormal;
bridge_vViewPosition = vViewPosition;
bridge_vLocal = vLocal;
bridge_vArrowSurface = vArrowSurface;
bridge_vRingUv = vRingUv;
bridge_vAge = vAge;
bridge_vRoute = vRoute;
bridge_vDissolve = vDissolve;
bridge_vAlive = vAlive;
bridge_vSeed = vSeed;
bridge_vSourceDistance = vSourceDistance;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
bool isOrthographic = PROJECTION_MATRIX[3][3] > 0.5;
float vAge = bridge_vAge;
float vAlive = bridge_vAlive;
vec3 vArrowSurface = bridge_vArrowSurface;
vec2 vChainClip = bridge_vChainClip;
float vDissolve = bridge_vDissolve;
vec3 vLocal = bridge_vLocal;
vec3 vNormal = bridge_vNormal;
vec2 vRingUv = bridge_vRingUv;
float vRoute = bridge_vRoute;
float vSeed = bridge_vSeed;
float vSourceDistance = bridge_vSourceDistance;
vec2 vSpriteHeading = bridge_vSpriteHeading;
vec2 vSpritePlane = bridge_vSpritePlane;
float vSpriteWidth = bridge_vSpriteWidth;
vec3 vViewPosition = bridge_vViewPosition;
fs_main(gl_FragColor, isOrthographic, vAge, vAlive, vArrowSurface, vChainClip, vDissolve, vLocal, vNormal, vRingUv, vRoute, vSeed, vSourceDistance, vSpriteHeading, vSpritePlane, vSpriteWidth, vViewPosition);
ALBEDO = gl_FragColor.rgb; 
}
