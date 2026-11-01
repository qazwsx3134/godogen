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
#define KIND 10
#define VARIANT 0
#define TOON 0
#define FLOWERS 0
uniform float uSize;
uniform float uTime;
uniform float uLifeStart;
uniform float uLifeEnd;
uniform float uDetail;
uniform vec3 uColor;
varying vec2 bridge_vUv;
varying float bridge_vShade;
varying float bridge_vSeed;
varying float bridge_vPetal;
varying float bridge_vGrowth;


    
    
    
    
    
 float vs_grassHash(float n){ return fract(sin(n * 127.1 + 311.7) * 43758.5453); }
 vec2 vs_windAt(vec2 root, float phase){
   float wave = sin(dot(root, vec2(1.1, .7)) - uTime * 1.45);
   float gust = .5 + .5 * sin(dot(root, vec2(.48, -.31)) - uTime * .63);
   float flutter = sin(uTime * 2.6 + phase + root.x * 3.0) * .025;
   return vec2(.12 + wave * .11 + gust * .13, .035 + wave * .045 + flutter);
 }

    void vs_main(inout vec4 gl_Position, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec4 seed, inout vec2 uv, inout float vGrowth, inout float vPetal, inout float vSeed, inout float vShade, inout vec2 vUv){
      vUv = uv; vSeed = seed.w; vPetal = 0.0;
      vGrowth = smoothstep(0.0, 1.0, uLifeStart) * (1.0 - smoothstep(0.0, 1.0, uLifeEnd));
      vec2 root = (seed.xy * 2.0 - 1.0) * 1.85;
      root *= sqrt(1.0 - .27 * root.yx * root.yx / 3.4225);
      float id = position.z, h = position.y;
      float angle = seed.w * 6.283185 + id * 2.39996;
      vec2 along = vec2(cos(angle), sin(angle));
      vec2 across = vec2(-along.y, along.x);
      vec3 p;
      float patchTone = .5 + .5 * sin(root.x * 2.3 + sin(root.y * 1.8) * 1.4);
      #if FLOWERS == 1
        float height = .48 + seed.z * .45;
        vec2 wind = vs_windAt(root, seed.w * 6.283185);
        if (id < .5) {
          p = vec3(across.x * position.x * .009, h * height, across.y * position.x * .009);
          p.xz += wind * h * h;
        } else {
          vPetal = 1.0;
          float a = (id - 1.0) * 1.256637 + seed.w * 6.283185;
          vec2 radial = vec2(cos(a), sin(a)), tangent = vec2(-radial.y, radial.x);
          float lengthPetal = .12 + vs_grassHash(id + seed.z * 91.0) * .085;
          vec2 petal = radial * (.012 + h * lengthPetal) + tangent * position.x * (.045 + seed.z * .025);
          p = vec3(petal.x, height + .018 + h * .035 + dot(petal, across) * .65, petal.y);
          p.xz += wind;
        }
        vShade = .4 + seed.z * .3;
      #else
        float shape = vs_grassHash(seed.z * 103.0 + id * 7.0);
        float height = (.30 + pow(seed.z, .7) * .82) * (.72 + shape * .38);
        float width = (.065 + vs_grassHash(seed.w * 53.0 + id) * .10) * mix(1.25, .72, seed.z);
        float taper = .22 + .78 * pow(max(0.0, sin(h * 2.85 + .23)), .72);
        float lean = (.12 + shape * .27) * h * h;
        vec2 leaf = across * position.x * width * taper + along * lean;
        leaf += vs_windAt(root, seed.w * 6.283185 + id * .23) * h * h;
        p = vec3(leaf.x, h * height - lean * .16, leaf.y);
        vShade = .12 + patchTone * .35 + shape * .28 + seed.z * .05;
      #endif
      p *= uSize * vGrowth;
      p.xz += root;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(p, 1.0);
    }
  


    
 float fs_brushStreak(float h, float seed){
   return sin(h * 23.0 + sin(h * 9.0 + seed * 11.0) * 2.2 + seed * 31.0);
 }

    
    
    
    void fs_main(inout vec4 gl_FragColor, inout float vGrowth, inout float vPetal, inout float vSeed, inout float vShade, inout vec2 vUv){
      if (vGrowth < .002) discard;
      float x = vUv.x * 2.0 - 1.0, h = vUv.y;
      vec3 color;
      if (vPetal > .5) {
        float edge = .74 + .09 * sin(h * 19.0 + vSeed * 17.0);
        float cap = pow(abs((h - .46) / .57), 4.0);
        if (x*x + cap > edge) discard;
        color = mix(vec3(.69,.74,.70), vec3(.86,.89,.82), step(.43, vShade + x * .09));
      } else {
        #if FLOWERS == 0
          float streak = fs_brushStreak(h, vSeed);
          float rim = .89 + streak * .028 * uDetail;
          float tip = 1.0 - smoothstep(.70, 1.03, h);
          if (abs(x + .12 * sin(h * 5.0 + vSeed * 9.0)) > rim * tip) discard;
          float notch = step(.94, sin(h * 21.0 + vSeed * 47.0)) * .065 * uDetail;
          if (abs(x) > rim * tip - notch && h > .2) discard;
        #endif
        float light = vShade + h * .16;
        color = mix(uColor * .37, uColor * .77, step(.36, light));
        color = mix(color, uColor * 1.13, step(.57, light));
        color = mix(color, mix(uColor, vec3(.70,.70,.22), .55), step(.76, light));
        float stroke = step(.64, sin(h * 10.0 + vSeed * 37.0 + x * 2.3));
        color *= 1.0 + (stroke - .5) * .10 * uDetail;
      }
      gl_FragColor = vec4(color, 1.0);
      
    
    
  
    }
  
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec4 seed = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
vec2 uv = UV;
float vGrowth = float(0);
float vPetal = float(0);
float vSeed = float(0);
float vShade = float(0);
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelViewMatrix, position, projectionMatrix, seed, uv, vGrowth, vPetal, vSeed, vShade, vUv);
bridge_vUv = vUv;
bridge_vShade = vShade;
bridge_vSeed = vSeed;
bridge_vPetal = vPetal;
bridge_vGrowth = vGrowth;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vGrowth = bridge_vGrowth;
float vPetal = bridge_vPetal;
float vSeed = bridge_vSeed;
float vShade = bridge_vShade;
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vGrowth, vPetal, vSeed, vShade, vUv);
ALBEDO = gl_FragColor.rgb; 
}
