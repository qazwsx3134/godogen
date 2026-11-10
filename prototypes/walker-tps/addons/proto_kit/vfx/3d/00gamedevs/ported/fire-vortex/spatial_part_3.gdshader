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
#define KIND 4
#define VARIANT 2
#define TOON 1
uniform float uLifeStage;
uniform float uLifeStart;
uniform float uLifeEnd;
uniform float uLifeOrigin;
uniform float uSize;
uniform float uTime;
uniform float uStopTime;
uniform float uImpact;
uniform float uDetail;
uniform vec3 uColor;
varying vec3 bridge_vStagePosition;
varying float bridge_vStagePart;
varying vec2 bridge_vUv;
varying float bridge_vFade;

    
    
    
    vec3 vs_stageShape(vec3 p,float s,float e,float part){
      float grow=s*s*(3.0-2.0*s),curl=(1.0-grow);
      #if KIND == 0
        float tail=1.0-smoothstep(-1.4,.25,p.x);
        #if VARIANT == 0
          p.yz*=mix(.22,1.0,grow);p.x=mix(p.x*.38-.16,p.x,grow);
          p.y+=sin(p.x*4.5+s*7.0)*curl*.15;
        #elif VARIANT == 1
          p.x*=mix(1.3,1.0,grow);p.yz*=mix(.08,1.0,grow);
        #elif VARIANT == 2 || VARIANT == 4
          float assemble=ceil((atan(p.z,p.y)+3.14159)*3.0)*.028;
          p.yz*=1.0+curl*(.8+assemble);p.x-=curl*(.2+assemble);
        #elif VARIANT == 3
          p.yz*=1.0+curl*.8;p.x+=sin(p.y*7.0)*curl*.4;
        #elif VARIANT == 5
          p.z+=sin(p.x*4.0)*curl*.75;p.x-=curl*.5;
        #else
          p.yz*=1.0+curl*.85;float turn=curl*2.4;
          p.yz=mat2(vec2(cos(turn),-sin(turn)),vec2(sin(turn),cos(turn)))*p.yz;
        #endif
        p.x-=e*tail*1.6;p.yz*=1.0-e*.75;
      #elif KIND == 1
        
        p.yz*=mix(.35,1.0,grow)*(1.0-e*.7);
      #elif KIND == 2
        float r=length(p.xz),a=atan(p.z,p.x);
        float cell=floor((a+3.14159)*3.0);float stagger=smoothstep(.04+fract(part*.37+cell*.13)*.2,.9,e);
        #if VARIANT == 0
          p.y+=curl*(.15+sin(a*5.0)*.08);float returnTime=smoothstep(.0,.72,e);float turn=returnTime*.8;p.xz=mat2(vec2(cos(turn),-sin(turn)),vec2(sin(turn),cos(turn)))*p.xz;p.xz*=1.0-returnTime*.95;p.y=mix(p.y,.06,returnTime)+sin(returnTime*3.14159)*.32;
        #elif VARIANT == 1
          p.y*=grow*(1.0-stagger*.8);p.y+=sin(stagger*3.14159)*.16;p.xz*=1.0+stagger*.1;
        #elif VARIANT == 2
          vec2 cellCenter=(floor(p.xz*2.5)+.5)/2.5;vec2 local=p.xz-cellCenter;float tumble=stagger*(1.0+fract(cell*.71)*2.0);p.xz=cellCenter*(1.0+stagger*.65)+local*cos(tumble);p.y+=local.x*sin(tumble)+sin(stagger*3.14159)*(.25+fract(cell*.71)*.45)-stagger*stagger*.35;p.xz*=mix(.7,1.0,grow);
        #elif VARIANT == 3
          p.y*=grow;float release=smoothstep(fract(cell*.37)*.2,.72,e);p*=1.0+release*.4;p.y+=release*(.12+max(0.0,p.y)*.4);
        #elif VARIANT == 4
          p.y*=grow;p.xz*=1.0+stagger*.32;p.y-=stagger*stagger*max(0.0,p.y)*.9;p.x+=sin(part*3.1)*stagger*.18;
        #elif VARIANT == 5
          p.y*=grow;float release=smoothstep(.02+fract(part*.31)*.2,.72,e);float loosen=release*(.4+max(0.0,p.y)*.7);p.xz+=vec2(cos(part*2.4),sin(part*2.4))*loosen;p.y+=sin(release*3.14159)*.28-release*release*.55;
        #elif VARIANT == 6
          float height=max(0.0,p.y);float retract=smoothstep(.0,.9,e);float bend=retract*height*2.1;float turn=curl*2.7+retract*.4;
          p.xz=mat2(vec2(cos(turn),-sin(turn)),vec2(sin(turn),cos(turn)))*p.xz;p.xz*=1.0-retract*.3;p.xz+=vec2(cos(a),sin(a))*(cos(bend)-1.0)*height*.45;
          p.y=grow*(height*cos(bend)*(1.0-retract*.5)+min(p.y,0.0));
        #elif VARIANT == 7
          float slide=smoothstep(.04+(.5+.5*sin(a*3.0))*.25,.9,e);p.y*=grow*(1.0-slide);p.y+=sin(slide*3.14159)*(.08+.06*sin(a*2.0));p.xz*=1.0-slide*.83;
        #else
          float pop=smoothstep(.08+fract(part*.41)*.25,.65+fract(part*.41)*.25,e);p.y*=grow*(1.0-pop*.85);p.xz*=mix(.55,1.0,grow)*(1.0+sin(pop*3.14159)*.65);
        #endif
      #elif KIND == 3
        float radius=length(p.xz),angle=atan(p.z,p.x);
        #if VARIANT == 2
          float crest=sin(radius*5.0-e*5.0+sin(angle*5.0));p.y+=crest*sin(e*3.14159)*.18;p.xz*=1.0+e*.12;
        #elif VARIANT == 4
          float h=max(0.0,p.y+1.3);p.z+=sin(h*4.0-e*6.0)*e*.4;p.y+=cos(h*3.5-e*5.0)*e*.24;p.x*=1.0+e*.2;
        #elif VARIANT == 5
          p.x+=sin(p.y*25.0+floor(e*17.0))*e*.07;p.z+=sin(p.y*18.0-floor(e*13.0))*e*.06;
        #elif VARIANT == 6
          float h=max(0.0,p.y+1.3);float roll=e*3.8+radius*2.0;p.y+=sin(roll)*h*.7;p.xz*=1.0+sin(roll)*h*.15;
        #elif VARIANT == 7
          float ray=length(p);p*=1.0-e*.22;p.y+=sin(ray*7.0+e*8.0)*e*.04;
        #endif
      #elif KIND == 4
        float h=clamp((p.y+1.4)/3.4,0.0,1.0);
        
        float gather=curl*(1.0-smoothstep(0.0,.6,e));
        p.y=-1.4+(p.y+1.4)*(1.0+gather*.10);
        float turn=gather*(1.0-h)*.55-e*.45;p.xz=mat2(vec2(cos(turn),-sin(turn)),vec2(sin(turn),cos(turn)))*p.xz;p.xz*=1.0+gather*.45+e*.18;
        #if VARIANT == 1
          p.y=max(-1.38,p.y-e*e*h*.7);
        #endif
      #elif KIND == 5
        #if VARIANT == 1
          p.xz*=mix(.18,1.0,grow)*(1.0+e*.18);
        #else
          p.y=-1.4+(p.y+1.4)*mix(.2,1.0,grow);
        #endif
      #endif
      return p;
    }
  

      void vs_steadyMain(inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec4 seed, inout vec2 uv, inout float vFade, inout vec2 vUv){vUv=uv;float life=uStopTime<0.0?fract(seed.y+uTime*.16):min(1.0,fract(seed.y+uStopTime*.16)+(uTime-uStopTime)*.6),a=seed.x*6.28318-uTime*2.4,r=0.25+life*1.9;

        #if TOON == 1
          r+=.22*(1.0-smoothstep(.08,.55,life));
        #endif
        vec3 p=vec3(cos(a)*r,-1.25+life*3.1,sin(a)*r);vec4 mv=modelViewMatrix*vec4(p,1.0);
        float spin=a+uTime;mat2 rot=mat2(vec2(cos(spin),-sin(spin)),vec2(sin(spin),cos(spin)));vec2 card=position.xy;
        #if VARIANT == 0
          card*=vec2(1.0,0.45);
        #elif VARIANT == 1
          card*=0.5;
        #elif VARIANT == 2
          card*=vec2(0.4,1.4);
        #endif
        mv.xy+=rot*card*(VARIANT==3?(.14+seed.w*.15):(.08+seed.w*.13))*length(modelMatrix[1].xyz);vFade=sin(life*3.14159);gl_Position=projectionMatrix*mv;}
        void vs_main(inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec4 seed, inout mat4 uClipToGroup, inout mat4 uGroupToClip, inout vec2 uv, inout float vFade, inout float vStagePart, inout vec3 vStagePosition, inout vec2 vUv){vs_steadyMain(gl_Position, modelMatrix, modelViewMatrix, position, projectionMatrix, seed, uv, vFade, vUv);vStagePosition=vec3(0.0);vStagePart=seed.x*37.0;if(uLifeStage==1.0)return;
          vec4 p=uClipToGroup*gl_Position;p/=p.w;vStagePosition=p.xyz;
          gl_Position=uGroupToClip*vec4(vs_stageShape(p.xyz,uLifeStart,uLifeEnd,vStagePart),1.0);
        }

    
    
    float fs_phaseCoverage(vec3 p, inout float vStagePart){
      float s=uLifeStart,e=uLifeEnd;
      float a=atan(p.z,p.x),r=length(p.xz);
      float start=1.0,end=1.0;
      #if KIND == 0
        #if VARIANT == 0
          float curl=sin(p.x*6.0+p.y*5.0+s*9.0)*.06;
          start=smoothstep(0.0,.18,s)*smoothstep(-.12,.12,s-(.15+clamp(-p.x,0.0,3.0)*.2+curl));
        #elif VARIANT == 1
          start=smoothstep(.0,.12,s)*smoothstep(-.1,.1,s-abs(p.x)*.24);
        #elif VARIANT == 2 || VARIANT == 4
          start=smoothstep(-.08,.08,s-(.12+fract(atan(p.z,p.y)*1.7)*.56));
        #elif VARIANT == 3
          start=smoothstep(-.12,.12,s-(.1+fract(p.x*.8+p.y)*.55));
        #elif VARIANT == 5
          start=smoothstep(-.13,.13,s-(.15+clamp(-p.x,0.0,2.0)*.25));
        #else
          start=smoothstep(-.13,.13,s-(.1+fract(atan(p.z,p.y)*.5-p.x*.3)*.6));
        #endif
        end=1.0-smoothstep(0.0,uImpact>.5?.28:.9,e);
      #elif KIND == 1
        float x=clamp((p.x+2.4)/4.8,0.0,1.0);
        start=smoothstep(-.08,.08,s*1.16-.08-x);
        end=smoothstep(-.14,.05,x-e*1.22+.12)*(1.0-smoothstep(.78,1.0,e));
      #elif KIND == 2
        float pattern=0.0;
        #if VARIANT == 0
          pattern=.1+r*.25+sin(a*5.0)*.08;
        #elif VARIANT == 1
          pattern=.12+fract(a/6.28318*5.0)*.22+r*.2;
        #elif VARIANT == 2
          pattern=.1+r*.25+abs(sin(a*3.0))*.1;
        #elif VARIANT == 3
          pattern=.12+max(abs(p.x),abs(p.z))*.27+max(0.0,p.y)*.18;
        #elif VARIANT == 4
          pattern=.1+fract(floor(p.x*3.0)+floor(p.z*3.0)*.38)*.35+max(0.0,p.y)*.2;
        #elif VARIANT == 5
          pattern=.14+fract(a/6.28318*3.0)*.3+max(0.0,p.y)*.2;
        #elif VARIANT == 6
          pattern=.08+r*.18+max(0.0,p.y)*.25;
        #elif VARIANT == 7
          pattern=.1+(1.7-r)*.25+abs(sin(a*1.5))*.12;
        #else
          pattern=.12+r*.2+sin(a*3.0)*.1;
        #endif
        pattern=clamp(pattern,.08,.75);
        start=smoothstep(-.08,.08,s-pattern);
        end=1.0-smoothstep(-.12,.12,e-(.18+pattern*.75));
        #if VARIANT == 0
          end=1.0-smoothstep(.64,.98,e);
        #elif VARIANT == 5 || VARIANT == 6 || VARIANT == 7
          end=1.0-smoothstep(.55,.98,e);
        #endif
        if(e>0.0){
          #if VARIANT == 1
            float ash=.5+.5*sin(p.x*31.0+p.z*23.0+sin(p.x*17.0)*3.0);end*=smoothstep(e*.7-.1,e*.7+.12,ash);
          #elif VARIANT == 3
            float sector=fract(a*1.4324);float gap=smoothstep(.03,.38,e)*.22;end*=smoothstep(gap,gap+.025,sector)*(1.0-smoothstep(1.0-gap-.025,1.0-gap,sector));
          #elif VARIANT == 2 || VARIANT == 4
            vec2 tile=abs(fract(p.xz*2.5)-.5);float crack=max(tile.x,tile.y);end*=1.0-smoothstep(.5-e*.25,.51-e*.25,crack);
          #elif VARIANT == 7
            float grain=.5+.5*sin(p.x*19.0+sin(p.z*15.0)*2.0);end*=mix(1.0,smoothstep(e*.65-.12,e*.65+.15,grain),smoothstep(.5,.9,e));
          #elif VARIANT == 8
            float pop=smoothstep(.08+fract(vStagePart*.41)*.25,.65+fract(vStagePart*.41)*.25,e);end*=1.0-smoothstep(.015,.08,max(0.0,p.y)-(.9-pop*1.5));
          #endif
        }
      #elif KIND == 3
        if(e>0.0){
          #if VARIANT == 2
            float breakUp=.5+.5*sin(a*7.0+sin(a*3.0)+p.y*5.0);end=smoothstep(e*.6-.1,e*.6+.12,breakUp);
          #elif VARIANT == 4
            float flame=.5+.5*sin(p.x*7.0+sin(p.y*5.0-e*9.0)*2.0+p.z*3.0);end=smoothstep(e*.82-.08,e*.82+.09,flame);
          #elif VARIANT == 5
            float segment=floor(p.y*3.0);float discharge=.5+.5*sin(segment*4.7+floor(e*13.0)*2.9);end=mix(smoothstep(.32,.55,discharge)*(1.0-smoothstep(.1,.55,e)),1.0,1.0-smoothstep(-.9,-.3,p.y));
          #elif VARIANT == 6
            float foam=.5+.5*sin(a*11.0+sin(p.y*9.0+e*8.0)+r*4.0);end=smoothstep(e*.88-.08,e*.88+.12,foam);
          #elif VARIANT == 7
            float ray=length(p);float streak=.5+.5*sin(a*9.0+floor(e*9.0)*2.4);end=1.0-smoothstep((1.0-e)*3.0+.2,(1.0-e)*3.0+.5,ray);end*=mix(.2,1.0,streak);
          #endif
        }
      #elif KIND == 4
        float h=clamp((p.y+1.4)/3.4,0.0,1.0);
        start=smoothstep(0.0,.13,s);
        end=1.0-smoothstep(.45,1.0,e);
      #elif KIND == 5
        start=smoothstep(.0,.25,s);
        end=1.0-smoothstep(.35,1.0,e);
      #endif
      return start*end;
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
  
      void fs_steadyMain(inout vec4 gl_FragColor, inout float vFade, inout vec2 vUv){vec2 q=vUv*2.0-1.0;float a=1.0-smoothstep(0.65,0.95,abs(q.y)+q.x*q.x);vec3 c=uColor*(0.20+vUv.y*0.30);
        #if VARIANT == 0
          c=mix(vec3(0.08,0.12,0.04),uColor*0.45,vUv.y);a*=step(abs(q.y),0.7*(1.0-q.x*q.x));
        #elif VARIANT == 1
          a=step(abs(q.x)+abs(q.y)*0.7,0.9);c=uColor*(0.12+step(q.y,0.0)*0.18);
        #elif VARIANT == 2
          c=mix(uColor*0.04,uColor*2.5+vec3(0.35),pow(vUv.y,6.0));
        #else
          a=fs_band(abs(q.x)+abs(q.y)-0.65,0.09);c=uColor*1.8;
        #endif
        #if TOON == 1
          c=fs_styleColor(uColor*.65,.2+vUv.y*.65);
          #if VARIANT == 0
            c=fs_styleColor(mix(vec3(.2,.3,.08),uColor,.4),.22+vUv.y*.6);
          #elif VARIANT == 2
            c=fs_styleHeat(uColor,.16+vUv.y*.75);
          #elif VARIANT == 3
            c=fs_styleColor(uColor,.8);
          #endif
        #endif
        gl_FragColor=vec4(c,a*vFade*uDetail);
    
    
  }
        void fs_main(inout vec4 gl_FragColor, inout float vFade, inout float vStagePart, inout vec3 vStagePosition, inout vec2 vUv){fs_steadyMain(gl_FragColor, vFade, vUv);if(uLifeStage==1.0)return;
          float coverage=fs_phaseCoverage(vStagePosition, vStagePart);
          if(coverage<.004)discard;gl_FragColor.a*=coverage;
          #if KIND == 1 && VARIANT == 4
            float radius=length(vStagePosition.yz);float core=1.0-smoothstep(.04,.22,radius);float atEnd=smoothstep(1.65,2.05,abs(vStagePosition.x));
            float petal=floor((atan(vStagePosition.z,vStagePosition.y)+3.14159)*.955);float release=smoothstep(.15+fract(petal*.381)*.3,.85,uLifeEnd);
            gl_FragColor.rgb=mix(gl_FragColor.rgb,vec3(1.0,.97,.81),core*.75);
            gl_FragColor.a*=mix(.55+.45*core,1.0-release,atEnd);
            gl_FragColor.a*=1.0-atEnd*smoothstep(.35,.9,uLifeEnd)*smoothstep(.05,.55,radius);
          #elif KIND == 2 && VARIANT == 1
            gl_FragColor.rgb*=1.0-uLifeEnd*.75;
          #elif KIND == 4 && VARIANT == 2
            gl_FragColor.rgb*=1.0-uLifeEnd*.6;
          #elif KIND == 3 && VARIANT == 6
            gl_FragColor.rgb=mix(gl_FragColor.rgb,vec3(.8,.94,1.0),uLifeEnd*.65);
          #endif
        }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelMatrix = MODEL_MATRIX;
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec4 seed = vec4(CUSTOM0.x,CUSTOM0.y,CUSTOM0.z,CUSTOM0.w);
mat4 uClipToGroup = inverse(PROJECTION_MATRIX * VIEW_MATRIX * MODEL_MATRIX * inverse(source_to_group));
mat4 uGroupToClip = PROJECTION_MATRIX * VIEW_MATRIX * MODEL_MATRIX * inverse(source_to_group);
vec2 uv = UV;
float vFade = float(0);
float vStagePart = float(0);
vec3 vStagePosition = vec3(0);
vec2 vUv = vec2(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelMatrix, modelViewMatrix, position, projectionMatrix, seed, uClipToGroup, uGroupToClip, uv, vFade, vStagePart, vStagePosition, vUv);
bridge_vStagePosition = vStagePosition;
bridge_vStagePart = vStagePart;
bridge_vUv = vUv;
bridge_vFade = vFade;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vFade = bridge_vFade;
float vStagePart = bridge_vStagePart;
vec3 vStagePosition = bridge_vStagePosition;
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vFade, vStagePart, vStagePosition, vUv);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
