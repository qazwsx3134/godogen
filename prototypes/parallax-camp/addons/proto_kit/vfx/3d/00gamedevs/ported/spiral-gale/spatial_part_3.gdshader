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
#define KIND 0
#define VARIANT 6
#define TOON 0
uniform float uSize;
uniform float uLifeEnd;
uniform float uLifeOrigin;
uniform vec3 uImpactUp;
uniform float uDetail;
uniform vec3 uColor;
varying vec3 bridge_vP;
varying vec3 bridge_vImpactNormal;
varying vec2 bridge_vFlow;
varying float bridge_vPart;


      #if VARIANT == 0
      
      #endif
      void vs_main(inout vec3 aCenter, inout float aPart, inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 normal, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout vec2 vFlow, inout vec3 vImpactNormal, inout vec3 vP, inout float vPart, inout mat4 viewMatrix){vFlow=uv;vImpactNormal=normal;float t=uLifeEnd;float open=1.0-exp(-t*7.0);vec3 p=position;vPart=aPart;
        #if VARIANT == 0
          float seed=fract(sin(aPart*17.13+2.8)*4375.3),level=fract(aPart*.381966),age=max(0.0,t-aPart*.006);
          float grow=1.0-exp(-age*12.0),spin=aPart*2.399963+age*(1.7+seed);
          vec3 up=normalize(uImpactUp),depth=vec3(1,0,0)-up*up.x;
          if(dot(depth,depth)<.01)depth=vec3(0,0,1)-up*up.z;
          depth=normalize(depth);vec3 across=cross(depth,up);
          
          float vertical=1.0-2.0*(aPart+.5)/12.0;
          float ring=sqrt(max(0.0,1.0-vertical*vertical));
          vec3 direction=up*vertical+depth*cos(spin)*ring+across*sin(spin)*ring;
          float radial=grow*(.67+seed*.26)+age*.12;
          vec3 center=direction*radial+up*smoothstep(.30,.95,age)*.32;
          center*=uSize*(.35+.65*uLifeOrigin);
          vec4 mv=modelViewMatrix*vec4(center,1.0);
          float width=(.20+grow*.95)*(.85+seed*.25)*(1.0-smoothstep(.65,1.0,age)*.22);
          mv.xy+=(uv-.5)*vec2(width,width*(1.05+level*.2))*uSize*(.35+.65*uLifeOrigin)*length(modelMatrix[1].xyz);
          vImpactNormal=normalize(mat3(viewMatrix)*vec3(-.45,.8,.55));vP=center;gl_Position=projectionMatrix*mv;return;
        #elif VARIANT == 1
          p*=.12+open*1.35;p.x+=sin(floor(t*22.0)+aPart*3.0)*.035;
        #elif VARIANT == 2 || VARIANT == 4
          p-=aCenter;float spin=t*(1.5+mod(aPart,3.0));p.yz=mat2(vec2(cos(spin),-sin(spin)),vec2(sin(spin),cos(spin)))*p.yz;
          p.xz=mat2(vec2(cos(spin*.7),-sin(spin*.7)),vec2(sin(spin*.7),cos(spin*.7)))*p.xz;p+=aCenter*(.25+open*2.0);p.x+=t*(.2+mod(aPart,4.0)*.25);p.y-=t*t*.7;
        #elif VARIANT == 3
          p-=aCenter;p*=.25+sin(t*3.14159)*.8;p+=aCenter*(.2+open*2.0);p.x+=t*.5;
        #elif VARIANT == 5
          float spin=t*1.4;p.yz=mat2(vec2(cos(spin),-sin(spin)),vec2(sin(spin),cos(spin)))*p.yz;p*=.35+open*1.1;p.x+=t*1.3;p.z+=(t-.35)*(1.1+aPart*.3);
        #else
          float age=max(0.0,t-aPart*.025),h=uv.x,spin=aPart*2.399963-age*(4.0+mod(aPart,3.0))+h*2.7;
          float pulse=sin(h*3.14159265),head=age*(3.4+mod(aPart,3.0)*.35);
          float radius=(.05+age*.95)*(.5+pulse*.5)*( .7+mod(aPart,3.0)*.17);
          float width=(.015+pulse*.07)*(1.0-smoothstep(.45,.95,age)),tube=uv.y*6.2831853;
          p=vec3(.04+head+h*(.35+age*.7)+cos(tube)*width,cos(spin)*(radius+sin(tube)*width),sin(spin)*(radius+sin(tube)*width));
        #endif
        p*=uSize*(.35+.65*uLifeOrigin);vP=p;
gl_Position=projectionMatrix*modelViewMatrix*vec4(p,1.0);
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
  
    float fs_toonStep(float edge,float x){float aa=max(fwidth(x),.008);return smoothstep(edge-aa,edge+aa,x);}
    vec3 fs_toonShade(vec3 tint,float light){
      vec3 c=mix(tint*.28,tint*1.08,fs_toonStep(.40,light));
      return mix(c,mix(tint,vec3(1.0),.53)*1.15,fs_toonStep(.69,light));
    }
  
      void fs_main(inout vec4 gl_FragColor, inout vec2 vFlow, inout vec3 vImpactNormal, inout vec3 vP, inout float vPart){float t=uLifeEnd;float fade=smoothstep(.0,.07,t)*(1.0-smoothstep(.52,1.0,t));
        vec3 n=normalize(cross(dFdx(vP),dFdy(vP)));

        float light=.35+abs(dot(n,normalize(vec3(.7,1,.5))))*.45;float mask=1.0;
        #if VARIANT == 0
          vec2 q=vFlow*2.0-1.0;float age=max(0.0,t-vPart*.006),seed=fract(vPart*.618034);
          float turn=age*(1.7+seed)+vPart*2.4;
          q=mat2(vec2(cos(turn),-sin(turn)),vec2(sin(turn),cos(turn)))*q;
          vec3 density=fs_noiseGradient(q*3.2+vec2(seed*17.0,-age*2.3));
          float fine=fs_noise2(q*7.0+density.x*1.4+seed*13.0);
          float n0=density.x*.76+fine*.24,d=length(q)+(n0-.5)*.35;
          vec2 optics=fs_smokeOptics(q,density.yz*3.2,n0,vImpactNormal);
          float burnout=smoothstep(.40+seed*.12,.96,age);
          mask=(1.0-smoothstep(.79,.94,d))*smoothstep(.18+burnout*.55,.40+burnout*.5,n0+(1.0-d)*.50);
          light=.20+n0*.55+(1.0-d)*.15+optics.x*.16-age*.13;
          fade=smoothstep(.0,.055,age)*(1.0-smoothstep(.65+seed*.08,.97,age))*.82;
        #elif VARIANT == 1
          float charge=.5+.5*sin(vPart*4.7+floor(t*16.0)*2.1);mask=mix(.2,1.0,smoothstep(.15,.45,charge));mask*=1.0-smoothstep(.35+mod(vPart,3.0)*.13,.6+mod(vPart,3.0)*.13,t);light=mod(vPart,3.0)<.5?.82:.57;
        #elif VARIANT == 3
          mask=1.0-smoothstep(.5,.9,t+vPart*.025);light=.65;
        #elif VARIANT == 5
          mask=1.0-smoothstep(.22,.85,t+vPart*.09);light=.2+light*.55;
        #elif VARIANT == 6
          float flow=fs_noise2(vec2(vFlow.x*8.0-t*5.0,vPart*2.3));mask=smoothstep(t*.6-.15,t*.6+.10,flow)*sin(vFlow.x*SRC_PI);fade*=1.0-smoothstep(.45,.96,t+vPart*.018);light=.35+.35*abs(dot(n,normalize(vec3(.4,.8,.5))))+.16*pow(vFlow.x,.6);
        #endif
        if(mask*fade<.006)discard;
        vec3 c=fs_toonShade(uColor,light);
        #if VARIANT == 0
          c=mix(uColor*vec3(.50,.18,.07),uColor*1.08,fs_toonStep(.46,light));c=mix(c,vec3(1.0,.92,.58),fs_toonStep(.68,light));
        #endif
        gl_FragColor=vec4(c,mask*fade);
    
    
  
      }
void vertex(){
vec3 aCenter = vec3(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z);
float aPart = CUSTOM0.w;
vec4 gl_Position = vec4(0);
mat4 modelMatrix = MODEL_MATRIX;
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 normal = NORMAL;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
vec2 vFlow = vec2(0);
vec3 vImpactNormal = vec3(0);
vec3 vP = vec3(0);
float vPart = float(0);
mat4 viewMatrix = VIEW_MATRIX;
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aCenter, aPart, gl_Position, modelMatrix, modelViewMatrix, normal, position, projectionMatrix, uv, vFlow, vImpactNormal, vP, vPart, viewMatrix);
bridge_vP = vP;
bridge_vImpactNormal = vImpactNormal;
bridge_vFlow = vFlow;
bridge_vPart = vPart;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
vec2 vFlow = bridge_vFlow;
vec3 vImpactNormal = bridge_vImpactNormal;
vec3 vP = bridge_vP;
float vPart = bridge_vPart;
fs_main(gl_FragColor, vFlow, vImpactNormal, vP, vPart);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
