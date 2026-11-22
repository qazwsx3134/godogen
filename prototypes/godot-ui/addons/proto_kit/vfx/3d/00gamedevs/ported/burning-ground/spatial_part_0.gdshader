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
#define VARIANT 1
#define TOON 0
#define CLOUD 0
uniform float uLifeStage;
uniform float uLifeStart;
uniform float uLifeEnd;
uniform float uLifeOrigin;
uniform float uSize;
uniform float uStopTime;
uniform float uEndDuration;
uniform float uQuantity;
uniform float uSpread;
uniform float uTime;
uniform float uStretch;
uniform float uImpact;
uniform float uDetail;
uniform vec3 uColor;
varying vec3 bridge_vStagePosition;
varying float bridge_vStagePart;
varying vec2 bridge_vUv;
varying float bridge_vAlpha;
varying float bridge_vSeed;
varying float bridge_vLife;
varying float bridge_vLight;
varying vec3 bridge_vKeyLight;

    
    
    
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
  

    
    
    
    
    
    
    
    
    
    
    float vs_hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
    float vs_noise2(vec2 p){
      vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
      return mix(mix(vs_hash(i),vs_hash(i+vec2(1,0)),f.x),mix(vs_hash(i+vec2(0,1)),vs_hash(i+vec2(1)),f.x),f.y);
    }
    float vs_fbm(vec2 p){ return vs_noise2(p)*0.57+vs_noise2(p*2.07+3.1)*0.29+vs_noise2(p*4.13-1.7)*0.14; }
    float vs_band(float x,float width){ return 1.0-smoothstep(width,width+0.004,abs(x)); }
    #define SRC_PI 3.14159265359
  
    
    vec3 vs_noiseGradient(vec2 p){
      vec2 i=floor(p),f=fract(p),u=f*f*(3.0-2.0*f),du=6.0*f*(1.0-f);
      float a=vs_hash(i),b=vs_hash(i+vec2(1,0)),c=vs_hash(i+vec2(0,1)),d=vs_hash(i+vec2(1,1));
      return vec3(mix(mix(a,b,u.x),mix(c,d,u.x),u.y),du.x*mix(b-a,d-c,u.y),du.y*mix(c-a,d-b,u.x));
    }
    vec3 vs_curlFlow(vec3 p,float t){
      
      vec3 ax=vs_noiseGradient(p.yz+vec2(7.3-t*0.22,1.7+t*0.11));
      vec3 ay=vs_noiseGradient(p.zx+vec2(13.1+t*0.13,5.4-t*0.19));
      vec3 az=vs_noiseGradient(p.xy+vec2(2.9-t*0.16,17.2+t*0.14));
      return vec3(az.z-ay.y,ax.z-az.y,ay.z-ax.y)*0.65;
    }
  
    
    void vs_steadyMain(inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec4 seed, inout vec2 uv, inout float vAlpha, inout vec3 vKeyLight, inout float vLife, inout float vLight, inout float vSeed, inout vec2 vUv, inout mat4 viewMatrix){
      vKeyLight=normalize(mat3(viewMatrix)*vec3(-0.45,0.8,0.55));
      vUv=uv;vSeed=seed.w;vLight=1.0;
      float t=uTime,a=seed.x*SRC_PI*2.0,r=sqrt(seed.z);
      float life=fract(seed.y+t*0.35);
      vec3 p=vec3(0.0);vec2 shape=vec2(1.0);
      float size=0.05+seed.w*0.06;
      vAlpha=0.8;vLife=life;
      #if CLOUD == 1
        #if KIND == 3
          float age=clamp(t/2.8,0.0,1.0);
          float rise=1.0-exp(-t*4.0);
          float crown=step(0.35,seed.y);
          float expansion=(0.25+rise*1.2)*(0.25+seed.z*0.75);
          p=vec3(cos(a)*expansion*crown,-1.36+rise*(0.5+seed.y*2.45)+age*0.3,sin(a)*expansion*crown);
          p.xz+=vec2(sin(t*1.5+a),cos(t*1.7+a))*age*0.25;
          size=(0.3+rise*0.85)*(0.6+seed.w*0.7);
          vAlpha=smoothstep(0.02,0.18,t)*pow(1.0-age,1.2)*0.72;
          vLife=age;vLight=max(0.0,1.0-t*0.65)*(1.0-crown*seed.y*0.5);
          #if VARIANT == 1
            p=vec3(cos(a)*r*(0.3+age*1.5),-1.3+rise*(seed.y*0.6)+age*0.4,sin(a)*r*(0.3+age*1.5));size*=0.6;vAlpha*=0.28;
            #if TOON == 1
              float expand=smoothstep(.02,.34,t);p=vec3(cos(a)*r*expand*2.2,-1.24+seed.y*.35*expand,sin(a)*r*expand*2.2);p.y=-1.2+(p.y+1.2)*uSize;p.xz*=uSize;
              size=.6+seed.w*.8;shape=vec2(1.4,.65);vAlpha=smoothstep(.01,.13,t)*(1.0-smoothstep(.3,.85,t))*.12;
            #endif
          #elif VARIANT == 2
            float front=(1.0-exp(-t*2.3))*2.55;float scatter=front*(0.35+seed.z*0.7);p=vec3(cos(a)*scatter,-1.35+sin(age*SRC_PI)*(0.12+seed.y*0.40),sin(a)*scatter);size*=0.65;shape=vec2(1.7,0.65);vAlpha*=0.42;
          #elif VARIANT == 3
            p.xz*=1.5;p.y=-1.3+age*0.6+seed.y*0.35;size*=0.75;vAlpha*=0.55;
          #endif
        #else
          float h=uStopTime<0.0?fract(seed.y+t*0.15):min(1.0,fract(seed.y+uStopTime*0.15)+(t-uStopTime)/uEndDuration);
          float spread=0.18+pow(h,0.8)*0.7;
          p=vec3(cos(a+h*4.0)*r*spread+sin(h*5.0+t*0.4)*0.25,h*3.5-1.4,sin(a+h*4.0)*r*spread);
          size=(0.48+h*0.95)*(0.75+seed.w*0.45);
          vAlpha=sin(h*SRC_PI)*0.5;vLife=h;
          #if VARIANT == 1
            p=vec3(cos(a+t*0.08)*r*2.0,-1.12+seed.y*0.45,sin(a+t*0.08)*r*1.6);
            size=0.9+seed.w*1.0;shape=vec2(1.5,0.6);vAlpha=0.23;vLife=seed.y;
          #elif VARIANT == 2
            h=uStopTime<0.0?fract(seed.y+t*0.48):min(1.0,fract(seed.y+uStopTime*0.48)+(t-uStopTime)/uEndDuration);
            p=vec3(cos(a+h*7.0)*h*h*0.85,h*3.6-1.4,sin(a+h*7.0)*h*h*0.65);
            size=0.18+h*0.9;shape=vec2(1.0,1.25);vAlpha=sin(h*SRC_PI)*0.34;vLife=h;
          #elif VARIANT == 3
            float age=clamp(t/3.5,0.0,1.0),expand=1.0-exp(-t*3.2);
            p=vec3(cos(a)*r*expand*1.55,-0.8+seed.y*expand*1.6+age*0.6,sin(a)*r*expand*1.55);
            size=(0.3+expand*0.85)*(0.6+seed.w*0.6);
            vAlpha=smoothstep(0.0,0.15,t)*pow(1.0-age,1.5)*0.6;vLife=age;
          #endif
        #endif
      #else
        #if KIND == 0
          life=fract(seed.y+t*0.65);
          p=vec3(0.85-life*3.6,sin(a)*r*(0.05+life*0.38),cos(a)*r*(0.05+life*0.38));
          size=0.04+seed.w*0.1;vAlpha=pow(1.0-life,1.5);shape=vec2(2.6,0.6);
          #if VARIANT == 0
            p=vec3(0.65-life*(2.8+seed.z*0.7),sin(a)*r*(0.16+life*0.50),cos(a)*r*(0.16+life*0.50));p.y+=sin(life*9.0-t*5.0+a)*life*0.24;size=0.018+seed.w*0.052;vAlpha=sin(life*SRC_PI)*pow(1.0-life,1.2)*0.65;shape=vec2(2.3,0.45);
          #elif VARIANT == 1
            p.yz*=0.9;shape=vec2(4.8,0.3);p.yz+=vec2(cos(a),sin(a))*sin(life*SRC_PI)*0.14;vAlpha*=0.2+0.8*step(0.45,sin(life*24.0+t*12.0+seed.z*9.0));
          #elif VARIANT == 2
            shape=vec2(2.2,0.6);p.yz*=1.25;p.y-=life*life*0.4;size*=0.42;vAlpha*=0.35+0.35*pow(max(0.0,sin(t*4.0+seed.z*31.0)),6.0);
          #else
            float spiral=life*12.0-t*3.0+(uQuantity==3.0?floor(seed.x*3.0)*2.094:floor(seed.x*uQuantity)*6.283185307/uQuantity);
            p.yz=vec2(cos(spiral),sin(spiral))*((0.26*mix(uSize,1.0,smoothstep(0.0,0.35,life))+life*0.16)*uSpread)+p.yz*0.07;
            shape=vec2(2.0,0.6);
          #endif
        #elif KIND == 1
          float phase=fract(seed.y+t*1.7);
          if(seed.x<0.26){
            p=vec3(-2.4+phase*0.45/uStretch,cos(a)*phase*0.4,sin(a)*phase*0.4);
            vAlpha=1.0-phase;size=0.04;shape=vec2(2.0,0.65);
          }else if(seed.x>0.58){
            float spread=phase*(0.3+seed.z*0.8);
            p=vec3(2.4-phase*(0.2+seed.w*0.65)/uStretch,cos(a)*spread,sin(a)*spread);
            vAlpha=pow(1.0-phase,1.3);shape=vec2(1.0,3.0);size=0.025+seed.w*0.045;
          }else{
            p=vec3((phase-0.5)*4.8,cos(a+t*4.0)*0.12*r,sin(a+t*4.0)*0.12*r);
            vAlpha=0.6;shape=vec2(2.7,0.5);
          }
          #if VARIANT == 2
            float cycle=t,charge=min(cycle/1.52,1.0),release=smoothstep(1.52,1.60,cycle);
            if(seed.x<0.58){float incoming=fract(seed.y+t*(0.45+charge*0.6));float radius=(1.0-incoming)*(0.35+seed.z*0.75);float angle=a-t*2.0;p=vec3(-2.4-(1.0-incoming)*0.7/uStretch,cos(angle)*radius*uSize,sin(angle)*radius*uSize);vAlpha=sin(incoming*SRC_PI)*(0.25+charge*0.75)*(1.0-release*0.4);shape=vec2(2.2,0.5);}
            else{vAlpha*=release;size*=0.7+release*0.6;p.yz*=1.0+release*0.35;}
          #elif VARIANT == 3
            
            float end=seed.x<.32?-1.0:1.0;
            phase=fract(seed.y+t*(1.1+seed.w*.8));
            float travel=phase*(.45+seed.z*.75)*uSize;
            p=vec3(end*2.4-end*travel*.28/uStretch,cos(a)*travel,sin(a)*travel);
            size=(.025+seed.z*.045)*uSize;shape=vec2(.38,4.2);
            vAlpha=pow(1.0-phase,2.0)*smoothstep(.0,.055,phase)*(1.0-step(.10,seed.w));
          #endif
      #elif KIND == 2
          float spin=a+t*0.15;
          p=vec3(cos(spin)*r*1.85,life*1.4,sin(spin)*r*1.85);
          vAlpha=sin(life*SRC_PI)*0.55;size=0.04+seed.w*0.055;
          #if VARIANT == 1
            p.y=life*(0.3+r*0.7);p.xz+=vec2(sin(t*2.0+a),cos(t*2.3+a))*life*0.12;shape=vec2(0.8,3.6);size=0.07+seed.w*0.10;
          #elif VARIANT == 2
            p.y=0.08+life*0.4;p.xz*=0.88+0.12*sin(life*SRC_PI);shape=vec2(1.0);vAlpha*=0.5+0.5*pow(max(0.0,sin(t*2.0+seed.z*29.0)),4.0);
          #elif VARIANT == 3
            p=vec3(cos(spin)*sin(seed.y*SRC_PI*0.5),cos(seed.y*SRC_PI*0.5),sin(spin)*sin(seed.y*SRC_PI*0.5))*1.85;
            vAlpha=0.25+0.2*sin(t*2.0+seed.z*6.0);
          #endif
        #elif KIND == 3
          float age=clamp(t/2.8,0.0,1.0);
          float dt=max(0.0,t-seed.w*0.1);
          float speed=0.4+seed.z*1.6;
          p=vec3(cos(a)*speed*dt,-1.35+(2.5+seed.y*3.3)*dt-2.5*dt*dt,sin(a)*speed*dt);
          p.y=max(-1.36,p.y);vAlpha=pow(1.0-age,1.7)*0.65;size=0.018+seed.w*0.045;shape=vec2(0.6,2.5);
          #if VARIANT == 1
            float ray=floor(seed.x*8.0)/8.0*SRC_PI*2.0;p=vec3(cos(ray)*dt*speed*0.8,-1.35+dt*(3.0+seed.y*3.5),sin(ray)*dt*speed*0.8);shape=vec2(0.3,6.0);vAlpha*=1.0-smoothstep(0.35,1.25,t);
            #if TOON == 1
              vec3 discharge=normalize(vec3(cos(a),.6+seed.y*1.8,sin(a)));
              p=discharge*(.15+(1.0-exp(-dt*4.0))*(.8+seed.z*2.4))*uSize;p.y-=1.2;vAlpha*=1.0-step(.16,seed.w);
              shape=vec2(3.2,.3);size*=uSize;vAlpha*=smoothstep(.06,.13,t);
            #endif
          #elif VARIANT == 2
            p.xz*=1.7;p.y=-1.35+(1.2+seed.y*2.2)*dt-2.5*dt*dt;p.y=max(-1.36,p.y);size*=0.8;shape=vec2(1.0);vAlpha*=0.4;
          #elif VARIANT == 3
            size*=0.85;shape=vec2(0.7,1.8);
          #endif
        #elif KIND == 4
          float h=uStopTime<0.0?fract(seed.y+t*.3):min(1.0,fract(seed.y+uStopTime*.3)+(t-uStopTime)*.55),spin=h*9.6-t*5.28+a;
          float radius=0.09+pow(h,1.45)*1.05+pow(h,4.0)*0.65;
          #if TOON == 1
            radius+=.22*(1.0-smoothstep(.08,.55,h));
          #endif
          p=vec3(cos(spin)*radius,h*3.6-1.4,sin(spin)*radius);
          p.x+=sin(h*2.6+t*0.5)*h*0.35;
          size=0.025+seed.w*0.04;shape=vec2(4.0,0.45);vAlpha=sin(h*SRC_PI)*0.5;
          #if VARIANT == 0
            shape=vec2(7.0,0.23);size*=0.8;vAlpha*=0.65;
          #elif VARIANT == 1
            radius+=seed.z*0.4;p.xz=vec2(cos(spin),sin(spin))*radius;size=0.012+seed.w*0.035;shape=vec2(1.0,0.8);vAlpha*=0.75;
          #elif VARIANT == 2
            spin=a-t*2.4;float drift=pow(h,3.0)*(0.3+seed.z*0.8);p=vec3(cos(spin)*(radius+drift),h*3.8-1.4,sin(spin)*(radius+drift));size=0.016+seed.w*0.04;shape=vec2(0.8,2.7);vAlpha=sin(h*SRC_PI)*(0.45+0.45*sin(t*13.0+seed.z*19.0));
          #else
            h=floor(seed.y*6.0)/6.0+0.08;spin=a-t*2.4;radius=0.15+pow(h,1.2)*1.8;p=vec3(cos(spin)*radius,h*3.5-1.4+sin(spin*3.0)*0.07,sin(spin)*radius);size=0.018+seed.w*0.03;shape=vec2(1.0);vAlpha=0.25+pow(max(0.0,sin(seed.z*20.0+t*3.0)),4.0)*0.6;
          #endif
        #endif
      #endif
      #if KIND == 4 || KIND == 5
        vec3 field=vs_curlFlow(vec3(p.x,p.y+1.4,p.z)*1.1,t);
        p+=field*(KIND==4?0.12:0.16)*smoothstep(0.0,0.25,p.y+1.4);
      #endif
      #if CLOUD == 1
        size*=uSize;
      #endif
      #if KIND == 4
        p.xz*=uSize;p.y=(p.y+1.4)*uSize-1.4;
      #endif
      vLife=clamp(vLife,0.0,1.0);
      vec4 mv=modelViewMatrix*vec4(p,1.0);
      float scale=length(modelMatrix[1].xyz);
      #if KIND == 0 && VARIANT == 2
        float spin=t*(1.0+seed.z*3.0)+a;vec3 shard=position*vec3(2.0,.55,.65)*size;
        shard.xy=mat2(vec2(cos(spin),-sin(spin)),vec2(sin(spin),cos(spin)))*shard.xy;
        mv=modelViewMatrix*vec4(p+shard,1.0);
      #elif TOON == 1 && KIND == 3 && VARIANT == 1 && CLOUD == 0
        vec3 direction=normalize(vec3(cos(a),.6+seed.y*1.8,sin(a)));
        vec2 along=normalize((modelViewMatrix*vec4(direction,0.0)).xy+vec2(.0001));
        mv.xy+=(along*position.x*shape.x+vec2(-along.y,along.x)*position.y*shape.y)*size*scale;
      #elif KIND == 4
        vec2 tangent=normalize((modelViewMatrix*vec4(-sin(spin),0.1,cos(spin),0.0)).xy);vec2 crossFlow=vec2(-tangent.y,tangent.x);
        mv.xy+=(tangent*position.x*shape.x+crossFlow*position.y*shape.y)*size*scale;
      #else
        mv.xy+=position.xy*size*shape*scale;
      #endif
      gl_Position=projectionMatrix*mv;
    }
  
        void vs_main(inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec4 seed, inout mat4 uClipToGroup, inout mat4 uGroupToClip, inout vec2 uv, inout float vAlpha, inout vec3 vKeyLight, inout float vLife, inout float vLight, inout float vSeed, inout float vStagePart, inout vec3 vStagePosition, inout vec2 vUv, inout mat4 viewMatrix){vs_steadyMain(gl_Position, modelMatrix, modelViewMatrix, position, projectionMatrix, seed, uv, vAlpha, vKeyLight, vLife, vLight, vSeed, vUv, viewMatrix);vStagePosition=vec3(0.0);vStagePart=seed.x*37.0;if(uLifeStage==1.0)return;
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
  

    
    
    
    float fs_hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
    float fs_noise2(vec2 p){
      vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
      return mix(mix(fs_hash(i),fs_hash(i+vec2(1,0)),f.x),mix(fs_hash(i+vec2(0,1)),fs_hash(i+vec2(1)),f.x),f.y);
    }
    float fs_fbm(vec2 p){ return fs_noise2(p)*0.57+fs_noise2(p*2.07+3.1)*0.29+fs_noise2(p*4.13-1.7)*0.14; }
    float fs_band(float x,float width){ return 1.0-smoothstep(width,width+0.004,abs(x)); }
  
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
  
    vec3 fs_flameErosion(vec2 uv,float t,float seed){
      vec2 p=vec2(uv.x+uv.y*0.65,uv.y);
      float warp=fs_noise2(p*vec2(3.1,2.7)+vec2(seed,t*-0.31));
      p.x+=(warp-0.5)*0.6;
      float broad=fs_noise2(p*vec2(4.0,2.2)+vec2(seed*3.7,-t*0.85));
      float fine=fs_noise2(p*vec2(10.5,5.0)+vec2(seed*7.1,-t*1.35));
      float erosion=broad*0.72+fine*0.28;
      float interior=1.0-abs(uv.x*2.0-1.0);
      float shape=interior-(1.0-erosion)*0.67;
      float aa=max(fwidth(shape)*0.8,0.018);
      float mask=smoothstep(-aa,aa+0.07,shape);
      float heat=clamp(shape*0.9+broad*0.25,0.0,1.0);
      float edge=exp(-abs(shape)*24.0)*smoothstep(0.28,0.58,erosion);
      return vec3(mask,heat,edge);
    }
    vec3 fs_flameColor(vec3 tint,float heat){
      vec3 c=mix(tint*0.065,tint*1.35,smoothstep(0.06,0.48,heat));
      return mix(c,tint*1.6+vec3(1.0,0.85,0.50),smoothstep(0.48,0.84,heat));
    }
  
    
    
    void fs_steadyMain(inout vec4 gl_FragColor, inout float vAlpha, inout vec3 vKeyLight, inout float vLight, inout float vSeed, inout vec2 vUv){
      vec2 q=vUv*2.0-1.0;float d=length(q);
      #if !(KIND == 0 && VARIANT == 2)
        if(d>1.0)discard;
      #endif
      float alpha=exp(-d*d*5.0)*(1.0-smoothstep(0.65,1.0,d));
      vec3 color=mix(uColor,vec3(1.0),pow(1.0-d,8.0)*0.35);
      #if CLOUD == 1
        vec2 original=q;
        float angle=vSeed*6.28+uTime*0.18;
        mat2 rotation=mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)));q=rotation*q;
        vec3 coarse=fs_noiseGradient(q*2.8+vec2(vSeed*17.0,-uTime*0.18));
        #if TOON == 1
          vec3 fine=coarse;
        #else
          vec3 fine=fs_noiseGradient(q*5.7+vec2(vSeed*31.0,-uTime*0.31));
        #endif
        float n=coarse.x*0.72+fine.x*0.28;
        vec2 gradient=mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)))*(coarse.yz*2.8*0.72+fine.yz*5.7*0.28);
        float puff=1.0-smoothstep(0.43,1.0,d+(n-0.5)*0.43);
        float body=smoothstep(0.14,0.76,n+(1.0-d)*0.55);
        vec2 optics=fs_smokeOptics(original,gradient,n,vKeyLight);
        float light=optics.x;
        color=uColor*light*1.15;
        alpha=puff*body*optics.y*1.35;
        #if KIND == 3
          float hot=vLight*(0.4+body*0.6);
          #if VARIANT == 0
            color=mix(uColor*(0.06+light*0.13),uColor*(1.8+hot*2.4)+vec3(pow(hot,3.0)*0.8),smoothstep(0.10,0.65,hot));
          #elif VARIANT == 1
            color=mix(uColor*0.35,uColor*1.7,hot);
          #elif VARIANT == 2
            color=uColor*(0.10+light*0.85);
          #else
            color=uColor*(0.18+light*0.95);
          #endif
        #else
          #if VARIANT == 2
            color=uColor*(0.40+light*0.65);
          #endif
        #endif
        #if TOON == 1
          color=styleColor(uColor,.20+light*.65+n*.18);
          alpha=(1.0-smoothstep(.68,.98,d+(n-.5)*.35))*smoothstep(.18,.42,n+(1.0-d)*.35)*.82;
          #if VARIANT == 0
            color=mix(styleColor(uColor*.28,light),styleHeat(uColor,hot*.65+n*.3),smoothstep(.10,.65,hot));
            #if KIND == 3
              color=mix(vec3(.04,.05,.065),vec3(.20,.22,.25),clamp(light,0.0,1.0));
            #endif
          #elif VARIANT == 1
            alpha=exp(-d*d*5.0)*(1.0-smoothstep(.7,1.0,d));color=uColor*(.6+body*.4);
          #endif
        #endif
      #elif KIND == 2
        #if VARIANT == 0
          float crossShape=min(max(abs(q.x)-0.20,abs(q.y)-0.66),max(abs(q.x)-0.66,abs(q.y)-0.20));
          alpha=1.0-smoothstep(-0.02,0.08,crossShape);color=uColor*1.2;
        #elif VARIANT == 1
          vec3 burn=fs_flameErosion(vec2(vUv.x,vUv.y*1.3),uTime*1.8,vSeed*9.0);
          alpha=burn.x*pow(max(0.0,1.0-vUv.y),0.7)*smoothstep(0.0,0.2,vUv.y);color=fs_flameColor(uColor,burn.y*0.7+(1.0-vUv.y)*0.3);
        #elif VARIANT == 2
          float a=atan(q.y,q.x);float spoke=pow(abs(cos(a*3.0)),28.0);
          alpha=(spoke*(1.0-smoothstep(0.4,0.85,d))+exp(-d*d*45.0))*0.85;
        #else
          alpha=fs_band(max(abs(q.x),abs(q.y))-0.52,0.07);color=uColor*1.3;
        #endif
      #elif KIND == 0 && VARIANT == 3
        alpha=fs_band(abs(q.x)+abs(q.y)-0.64,0.05)+exp(-d*d*35.0)*0.4;
      #elif KIND == 0 && VARIANT == 2
        alpha=0.8;color*=0.35+0.65*vUv.y;
      #elif (KIND == 3 && VARIANT == 3) || (KIND == 4 && VARIANT == 3)
        alpha=1.0-smoothstep(0.7,1.0,abs(q.x)+abs(q.y));
        color*=0.7+step(q.x,0.0)*0.5;
      #endif
      #if KIND == 0
        color=toonShade(uColor,.46+(1.0-d)*.4);
      #endif
      #if TOON == 1 && CLOUD == 0
        color=styleColor(uColor,.28+(1.0-d)*.5+vLight*.1);
        #if KIND == 3 && VARIANT == 1
          alpha=exp(-q.y*q.y*35.0)*(1.0-smoothstep(.6,1.0,abs(q.x)));color=uColor*1.3+vec3(pow(1.0-d,3.0)*1.4);
        #elif KIND == 4 && VARIANT == 1
          color=styleColor(uColor*.55,.3+vSeed*.5);
        #elif (KIND == 3 && VARIANT == 0) || (KIND == 4 && VARIANT == 2)
          color=styleHeat(uColor,.50+(1.0-d)*.35);
        #endif
      #endif
      gl_FragColor=vec4(color,alpha*vAlpha*uDetail);
      
    
    
  
    }
  
        void fs_main(inout vec4 gl_FragColor, inout float vAlpha, inout vec3 vKeyLight, inout float vLight, inout float vSeed, inout float vStagePart, inout vec3 vStagePosition, inout vec2 vUv){fs_steadyMain(gl_FragColor, vAlpha, vKeyLight, vLight, vSeed, vUv);if(uLifeStage==1.0)return;
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
float vAlpha = float(0);
vec3 vKeyLight = vec3(0);
float vLife = float(0);
float vLight = float(0);
float vSeed = float(0);
float vStagePart = float(0);
vec3 vStagePosition = vec3(0);
vec2 vUv = vec2(0);
mat4 viewMatrix = VIEW_MATRIX;
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelMatrix, modelViewMatrix, position, projectionMatrix, seed, uClipToGroup, uGroupToClip, uv, vAlpha, vKeyLight, vLife, vLight, vSeed, vStagePart, vStagePosition, vUv, viewMatrix);
bridge_vStagePosition = vStagePosition;
bridge_vStagePart = vStagePart;
bridge_vUv = vUv;
bridge_vAlpha = vAlpha;
bridge_vSeed = vSeed;
bridge_vLife = vLife;
bridge_vLight = vLight;
bridge_vKeyLight = vKeyLight;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vAlpha = bridge_vAlpha;
vec3 vKeyLight = bridge_vKeyLight;
float vLight = bridge_vLight;
float vSeed = bridge_vSeed;
float vStagePart = bridge_vStagePart;
vec3 vStagePosition = bridge_vStagePosition;
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vAlpha, vKeyLight, vLight, vSeed, vStagePart, vStagePosition, vUv);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
