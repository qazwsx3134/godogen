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
#define VARIANT 7
#define TOON 0
#define SPELL 10
uniform float uSize;
uniform float uRetire;
uniform float uOpening;
uniform float uStopTime;
uniform float uQuantity;
uniform float uTime;
uniform float uStretch;
uniform float uDetail;
uniform vec3 uColor;
varying float bridge_vPart;
varying vec2 bridge_vUv;
varying vec3 bridge_vN;
varying vec3 bridge_vP;
varying float bridge_vFade;
varying float bridge_vPhase;
varying float bridge_vSandMass;
varying vec2 bridge_vStroke;
varying float bridge_vHalfLength;


    float vs_hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
    float vs_noise2(vec2 p){
      vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
      return mix(mix(vs_hash(i),vs_hash(i+vec2(1,0)),f.x),mix(vs_hash(i+vec2(0,1)),vs_hash(i+vec2(1)),f.x),f.y);
    }
    float vs_fbm(vec2 p){ return vs_noise2(p)*0.57+vs_noise2(p*2.07+3.1)*0.29+vs_noise2(p*4.13-1.7)*0.14; }
    float vs_band(float x,float width){ return 1.0-smoothstep(width,width+0.004,abs(x)); }
    #define SRC_PI 3.14159265359
  
      mat2 vs_rot(float a){return mat2(vec2(cos(a),-sin(a)),vec2(sin(a),cos(a)));}
      #if SPELL == 3
        
        float vs_lightningNoise(float h,float cells,float seed){float f=h*cells,i=floor(f);return mix(vs_hash(vec2(i,seed)),vs_hash(vec2(i+1.0,seed)),fract(f))*2.0-1.0;}
        vec3 vs_thunderMain(float h){float f=floor(uTime*18.0);vec2 bend=vec2(vs_lightningNoise(h,7.0,f),vs_lightningNoise(h,6.0,f+17.0))*.42+vec2(vs_lightningNoise(h,83.0,f+31.0),vs_lightningNoise(h,79.0,f+49.0))*.045;return vec3(bend.x*sin(h*SRC_PI),4.05-h*5.4,bend.y*sin(h*SRC_PI));}
        vec3 vs_thunderGround(float h,float id){float a=id*2.39996,f=floor(uTime*(13.0+mod(id,3.0)))+id*17.0,j=vs_lightningNoise(h,27.0,f)*sin(h*SRC_PI),reach=2.15+vs_hash(vec2(id,7.0))*1.2;return vec3(cos(a)*h*reach,-1.30+sin(h*SRC_PI)*(.16+vs_hash(vec2(id,11.0))*.8),sin(a)*h*reach)+vec3(-sin(a),.3,cos(a))*j*.14;}
        vec3 vs_thunderPoint(float h,float id){
          if(id<.5)return vs_thunderMain(h);
          float a=id*2.39996,f=floor(uTime*16.0)+id*17.0,j=vs_lightningNoise(h,31.0,f)*sin(h*SRC_PI);
          if(id<2.5)return vs_thunderMain(h)+vec3(cos(a),.12,sin(a))*sin(h*SRC_PI)*(.22+.25*sin(h*8.0+id))+vec3(j*.10,0,-j*.08);
          if(id<10.5){float root=(18.0+(id-3.0)*7.0)/96.0,reach=1.2+vs_hash(vec2(id,2.0))*1.5;return vs_thunderMain(root)+vec3(cos(a)*h*reach,-h*(.7+reach*.4),sin(a)*h*reach)+vec3(-sin(a),.3,cos(a))*j*.18;}
          if(id<22.5)return vs_thunderGround(h,id);
          return vs_thunderGround(.5,id-12.0)+vec3(cos(a+.8)*h*.8,sin(h*SRC_PI)*.25,sin(a+.8)*h*.8)+vec3(-sin(a),.4,cos(a))*j*.11;
        }
        float vs_lightningPulse(float t,float begin,float end){return smoothstep(begin,begin+.025,t)*(1.0-smoothstep(end-.065,end,t));}
      #endif
      void vs_main(inout float aPart, inout float aPhase, inout float aUnit, inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 normal, inout mat3 normalMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout float vFade, inout float vHalfLength, inout vec3 vN, inout vec3 vP, inout float vPart, inout float vPhase, inout float vSandMass, inout vec2 vStroke, inout vec2 vUv, inout mat4 viewMatrix){vUv=uv;vPhase=aPhase;vPart=aPart;vSandMass=1.0;vec3 p=position;vec3 n=normal;float life=clamp(uTime/3.4,0.0,1.0);float alive=smoothstep(0.0,.025,life)*(1.0-smoothstep(.70,1.0,life));vFade=alive;
        
        if(aUnit>=uQuantity){vFade=0.0;vP=vec3(0);vN=vec3(0,1,0);gl_Position=vec4(2,2,2,1);return;}
        #if SPELL == 0
          if(aPart>1.5){
            float seed=fract(aPhase*.618034),age=max(0.0,life-seed*.10),grow=smoothstep(.0,.20,age);
            float lane=mod(aPhase,4.0)-1.5,h=.25+floor(aPhase/4.0)*.22;
            if(abs(uQuantity-5.0)>.1)lane=uQuantity<1.5?0.0:(aUnit/(uQuantity-1.0)*2.0-1.0)*1.5;
            float turn=h*(1.5+age*1.0)+age*.12;
            p=vec3(lane*(.18+h*.64)*grow,-1.25+sin(turn)*1.35*grow+h*.3*grow,(1.0-cos(turn))*.95*grow+age*.65);
            p.y+=smoothstep(.55,.98,age)*.48;p.y=-1.3+(p.y+1.3)*uSize;p.xz*=uSize;
            vec4 mv=modelViewMatrix*vec4(p,1.0);float width=(.15+grow*.66)*(1.0-smoothstep(.62,.99,age)*.55);
            mv.xy+=(uv-.5)*width*uSize*vec2(1.15,1.25)*length(modelMatrix[1].xyz);
            vFade=smoothstep(.0,.07,age)*(1.0-smoothstep(.82,1.0,age));vP=p;vN=normalize(mat3(viewMatrix)*vec3(-.45,.8,.55));gl_Position=projectionMatrix*mv;return;
          }
          float seed=fract(aPhase*.618034),lane=aPhase<3.0?aPhase-1.0:(aPhase-3.5)*1.5;
          if(abs(uQuantity-5.0)>.1)lane=uQuantity<1.5?0.0:aUnit/(uQuantity-1.0)*2.0-1.0;
          float age=max(0.0,life-seed*.10),grow=smoothstep(.0,.20,age),h=uv.x;
          float curl=h*(1.5+age*1.0)+age*.12,bulk=(aPhase<3.0?1.0:.66)*grow;
          float height=bulk*(1.30+seed*.25),width=pow(max(0.0,sin(h*SRC_PI)),.65)*(.36+seed*.12)*bulk;
          width*=1.0-smoothstep(.55,.96,age)*.7;
          float around=uv.y*SRC_PI*2.0,wrinkle=1.0+sin(h*13.0-age*8.0+around*3.0+aPhase)*.12;
          vec3 center=vec3(lane*(.38+h*.78)*grow,-1.26+sin(curl)*height+h*.3*grow,(1.0-cos(curl))*height*.70+age*.65);
          p=center+vec3(cos(around)*width*wrinkle,-sin(around)*sin(curl)*width*.55,sin(around)*cos(curl)*width*.55);
          p.y+=smoothstep(.60,.95,age)*h*.45;vFade=smoothstep(.0,.04,age)*(1.0-smoothstep(.90,1.0,age));
        #elif SPELL == 1
          p.xy=vs_rot(uTime*4.0)*p.xy;n.xy=vs_rot(uTime*4.0)*n.xy;p.yz=vs_rot(.15*sin(uTime*2.0))*p.yz;
        #elif SPELL == 2
          if(aPart>.5){
            if(abs(uQuantity-9.0)>.1){
              vec2 from=vec2(mod(aUnit,3.0)-1.0,floor(aUnit/3.0)-1.0)*.85;
              if(aUnit>8.5){float e=aUnit-9.0;from=e<.5?vec2(.425,.425):e<1.5?vec2(-.425,.425):e<2.5?vec2(.425,-.425):e<3.5?vec2(-.425,-.425):e<4.5?vec2(0,.425):e<5.5?vec2(0,-.425):e<6.5?vec2(.425,0):e<7.5?vec2(-.425,0):vec2(.425,.85);}
              float columns=ceil(sqrt(uQuantity)),rows=ceil(uQuantity/columns),row=floor(aUnit/columns),inRow=min(columns,uQuantity-row*columns);
              vec2 to=vec2(inRow<1.5?0.0:(mod(aUnit,columns)/(inRow-1.0)*2.0-1.0)*.85,rows<1.5?0.0:(row/(rows-1.0)*2.0-1.0)*.85);p.xz+=to-from;
            }
            p.y+=.18*sin(uTime*1.4+aPhase);float turn=uTime*.18;float angle=(floor(turn)+smoothstep(.25,.75,fract(turn)))*SRC_PI*.5;p.xz=vs_rot(angle)*p.xz;if(abs(uQuantity-9.0)>.1)n.xz=vs_rot(angle)*n.xz;
          }
        #elif SPELL == 3
          float h=mix(position.x,position.y,uv.x),id=aPhase,head=clamp((uTime-.08)/.16,0.0,1.0),primary=1.0-smoothstep(.64,.86,uTime);
          if(aPart>3.5){
            float sky=1.0-step(4.5,aPart),growth=smoothstep(0.0,.17,uTime);
            p=position*(sky>0.5?6.2:7.0)*(sky>0.5?.35+growth*.65:.6+smoothstep(.22,.55,uTime)*.4);p.y=sky>0.5?4.05+p.z*.42:-1.32;
            p.y=-1.35+(p.y+1.35)*uSize;p.xz*=uSize;
            vFade=sky>0.5?smoothstep(0.0,.06,uTime)*(1.0-smoothstep(.46,.88,uTime)):vs_lightningPulse(uTime,.22,.85);
            vP=p;vN=vec3(0,1,0);gl_Position=projectionMatrix*modelViewMatrix*vec4(p,1);return;
          }
          if(aPart>2.5){
            vFade=id<.5?vs_lightningPulse(uTime,.22,.72)+vs_lightningPulse(uTime,1.02,1.22)*.3+vs_lightningPulse(uTime,1.65,1.83)*.18:vs_lightningPulse(uTime,.015,.65);
            p=vec3(0,-1.35+(id<.5?.13:5.4)*uSize,0);vec4 mv=modelViewMatrix*vec4(p,1);
            mv.xy+=position.xy*(id<.5?4.4:4.8)*uSize*length(modelMatrix[1].xyz);vP=p;vN=vec3(0,0,1);gl_Position=projectionMatrix*mv;return;
          }
          float root=(18.0+(id-3.0)*7.0)/96.0,reveal=step(aPart<.5?h:root,head)*step(.081,uTime);
          vFade=primary*reveal*(id<.5?1.0:id<2.5?.7:.48+.3*vs_hash(vec2(id,floor(uTime*17.0))));
          if(aPart>1.5){float delay=vs_hash(vec2(id,3.0));float growth=clamp((uTime-.17-delay*.025)*8.0,0.0,1.0);
            vFade=vs_lightningPulse(uTime,.23+delay*.035,.72+delay*.15);
            vFade+=vs_lightningPulse(uTime,.96+delay*.18,1.16+delay*.18)*.67+vs_lightningPulse(uTime,1.58+delay*.2,1.78+delay*.2)*.45;
            vFade*=step(h,growth)*(1.0-smoothstep(.7,1.0,h));
          }
          vec3 p0=vs_thunderPoint(position.x,id),p1=vs_thunderPoint(position.y,id);p0.y=-1.35+(p0.y+1.35)*uSize;p1.y=-1.35+(p1.y+1.35)*uSize;p0.xz*=uSize;p1.xz*=uSize;
          vec4 m0=modelViewMatrix*vec4(p0,1),m1=modelViewMatrix*vec4(p1,1);vec2 delta=m1.xy-m0.xy;float len=length(delta);vec2 along=len<.0001?vec2(1,0):delta/len;
          float mid=(position.x+position.y)*.5,width=id<.5?.40:id<2.5?.16:id<10.5?.12:id<22.5?.19:.065;width*=aPart<.5?.5+.5*sin(mid*SRC_PI):1.0-mid*.82;width*=uSize*length(modelMatrix[1].xyz);
          vec4 mv=mix(m0,m1,uv.x);mv.xy+=(along*(uv.x*2.0-1.0)+vec2(-along.y,along.x)*(uv.y*2.0-1.0))*width;
          vHalfLength=len/max(width,.00001)*.5;vStroke=vec2((uv.x*2.0-1.0)*(vHalfLength+1.0),uv.y*2.0-1.0);vP=mix(p0,p1,uv.x);vN=vec3(0,0,1);gl_Position=projectionMatrix*mv;return;
        #elif SPELL == 4
          if(aPart<.5||aPart>1.5){p.yz*=.92+.08*sin(uTime*3.0+position.x*4.0);p.yz*=uSize;}else{p.yz=vs_rot(uTime*.35)*p.yz*uSize;p.x=sign(p.x)*2.4+(p.x-sign(p.x)*2.4)*uSize/max(uStretch,.001);}vFade*=smoothstep(0.0,.25,uTime);
        #elif SPELL == 5
          float cycle=fract(uTime*.52+aPhase*.15915),tight=smoothstep(.05,.15,cycle)*(1.0-smoothstep(.38,.83,cycle));
          float release=smoothstep(.0,.66,uRetire),h=uv.x,a=aPhase/2.1*2.094395;
          if(abs(uQuantity-3.0)>.1)a=aUnit*SRC_PI*2.0/uQuantity;
          float hook=smoothstep(.70,1.0,h),b=a+h*1.1+hook*(2.7-release*2.1);
          float r=(.28+sin(h*SRC_PI)*1.04)*(1.0-tight*.63)+release*h*.85;
          float width=(.062+.045*sin(h*SRC_PI))*(1.0-smoothstep(.86,1.0,h)*.7),side=uv.y*SRC_PI*2.0;
          p=vec3(cos(b)*(r+cos(side)*width),.06+sin(h*SRC_PI)*1.55+hook*.25+sin(side)*width*.35,sin(b)*(r+cos(side)*width));
          p.y*=smoothstep(.0,.85,uOpening);p.y-=release*release*h*.45;
          vFade*=1.0-smoothstep(.62,.98,uRetire);
        #elif SPELL == 6
          float delay=fract(aPhase*.37)*.18;float retract=smoothstep(delay,.95,uRetire);float h=max(0.0,position.y);float root=aPhase*SRC_PI*.5;
          if(aUnit>=0.0&&abs(uQuantity-4.0)>.1){float original=aUnit*SRC_PI*2.0/(aUnit<3.5?4.0:8.0);root=aUnit*SRC_PI*2.0/uQuantity;p.xz=vs_rot(original-root)*p.xz;n.xz=vs_rot(original-root)*n.xz;}
          vec2 leafRadial=normalize(p.xz+vec2(.0001)),base=vec2(cos(root),sin(root))*.8;
          float bend=retract*(1.3+h*1.3),arc=h*max(.12,1.0-retract*.65);p.xz=base+(p.xz-base)*(1.0-retract*.55);
          p.xz+=vec2(cos(root),sin(root))*(1.0-cos(bend))*arc*.45;p.y=max(.025,arc*sin(bend+.001)/(bend+.001));
          if(aPart>1.5){float fold=smoothstep(.0,.7,retract);float attach=.35+floor(max(0.0,h-.35)/.43)*.43;float blade=uv.x*.55;vec2 radial=leafRadial;p.xz-=radial*blade*fold;p.y+=blade*sin(fold*SRC_PI*.8)*.35;}
          p.y*=smoothstep(.0,.85,uOpening);vFade*=1.0-smoothstep(.78,1.0,uRetire);
        #elif SPELL == 7
          p.yz=vs_rot(uTime*2.7-aPhase)*p.yz;n.yz=vs_rot(uTime*2.7-aPhase)*n.yz;if(aPart>.5){p.x-=aPart*.45;p.y+=sin(uTime*3.0-aPart)*.12;vFade*=.23*(1.0-aPart*.18);}
        #elif SPELL == 8
          float across=uv.x*2.0-1.0,a=across*1.6;
          float age=max(0.0,life-abs(across)*.12),grow=smoothstep(.0,.15,age),crash=smoothstep(.27,.58,age);
          float height=(.5+pow(max(0.0,1.0-across*across),.6)*.8)*grow;
          height*=1.0+sin(across*12.0-age*7.0)*.14+sin(across*23.0+age*4.0)*.07;
          float theta=position.y*SRC_PI*2.0,radial=.85+life*2.2;
          float roll=crash*1.35,yy=(1.0-cos(theta))*height*.5,rr=sin(theta)*(.25+height*.22);
          float y=yy*cos(roll)-rr*sin(roll),r=radial+yy*sin(roll)+rr*cos(roll);
          float breaking=smoothstep(.27+.04*sin(across*9.0),.61+.035*sin(across*13.0),age);
          float crown=pow(max(0.0,sin(position.y*SRC_PI)),2.0);y-=breaking*height*.95*crown;r+=breaking*crown*.35;vSandMass=max(0.0,y)/max(.01,height);
          p=vec3(sin(a)*r,-1.3+max(.025,y),cos(a)*r-.5);if(aPart>.5)p.y+=.016;
          n=normalize(vec3(sin(a)*sin(theta+roll),-cos(theta+roll),cos(a)*sin(theta+roll)));
          vFade*=1.0-smoothstep(.42,.67,age);
          if(aPart>1.5){
            float side=(aPhase/11.0)*2.0-1.0,born=.27+abs(side)*.12+sin(aPhase*2.4)*.025,local=max(0.0,life-born),on=smoothstep(.0,.055,local);
            float angle=side*1.6,rr=.85+life*2.2+local*.75;
            p=vec3(sin(angle)*rr,-1.3+max(.035,.82+local*.6-local*local*8.0),cos(angle)*rr-.5);
            p.y=-1.3+(p.y+1.3)*uSize;p.xz*=uSize;
            vec4 mv=modelViewMatrix*vec4(p,1.0);float width=(.42+local*.90)*on;
            mv.xy+=(uv-.5)*width*uSize*length(modelMatrix[1].xyz);vP=p;vN=normalize(mat3(viewMatrix)*vec3(-.45,.8,.55));vFade=on*(1.0-smoothstep(.32,.60,local));gl_Position=projectionMatrix*mv;return;
          }
        #elif SPELL == 9
          float bank=aUnit,origin=uStopTime<0.0?uTime:uStopTime;
          float cycle=fract(origin*.24+bank*.31);if(uRetire>0.0)cycle=min(.999,cycle+uRetire*.9);
          float packet=aUnit<2.5?step(2.5,aPhase):step(5.5,aPhase),side=pow(sin(uv.x*SRC_PI),.65);
          float local=clamp((cycle-.10-uv.x*.25)*2.4,0.0,1.0);
          float slide=smoothstep(.02,.88,local),build=smoothstep(.0,.16,cycle);
          float angle=bank*SRC_PI*2.0/uQuantity+.32+(uv.x-.5)*1.55;
          if(uQuantity>3.5)angle=bank*SRC_PI*2.0/uQuantity+.32+(uv.x-.5)*1.55*3.0/uQuantity;
          float crest=.82-slide*.52,radial=.12+uv.y*1.25;
          float profile=max(0.0,min(uv.y/max(.08,crest),(1.0-uv.y)/(1.0-crest)));
          float scar=exp(-pow((uv.y-crest)*6.0,2.0))*sin(slide*SRC_PI);
          float height=profile*side*(.17+build*.25)*(1.0-scar*.85)*(1.0-slide*.55);
          height+=sin(uv.x*19.0+bank)*.025*profile;
          if(packet>.5){radial=.18+(1.0-slide)*.66+(uv.y-.5)*.28;
            height=sin(uv.y*SRC_PI)*side*.20*sin(slide*SRC_PI);vFade*=sin(slide*SRC_PI);}
          p=vec3(cos(angle)*radial,.025+height*smoothstep(.0,.75,uOpening),sin(angle)*radial);
          float sink=smoothstep(.04+uv.y*.30,.86,uRetire);p.xz*=.72*(1.0-sink*(1.0-uv.y)*.85);vSandMass=height*(1.0-sink);p.y=.025+vSandMass;
          n=normalize(vec3(cos(angle)*(uv.y<crest?-1.3:1.0),1.0,sin(angle)*(uv.y<crest?-1.3:1.0)));
          vFade*=1.0-smoothstep(.74,.99,uRetire);
        #elif SPELL == 10
          if(aPart<1.5){float gather=1.0-smoothstep(0.0,.36,life)*.82;p*=gather;p.xz=vs_rot(uTime*(1.0+life*3.0))*p.xz;vFade*=1.0-smoothstep(.35,.50,life);}else{float start=.31+fract(aPhase*.37)*.065;float age=max(0.0,life-start);float release=smoothstep(.0,.08,age);float a=aPhase*4.8;vec3 direction=normalize(vec3(cos(a),sin(aPhase*4.0)*.8,sin(a)));
          if(abs(uQuantity-10.0)>.1){float y=uQuantity<1.5?0.0:((aUnit+.5)/uQuantity*2.0-1.0)*.8;float azimuth=aUnit*2.399963;float radial=sqrt(1.0-y*y);direction=vec3(cos(azimuth)*radial,y,sin(azimuth)*radial);}
          vec3 side=normalize(cross(direction,vec3(0,1,0))),up=cross(direction,side);if(abs(uQuantity-10.0)>.1)n=side*cos(uv.y*SRC_PI*2.0)+up*sin(uv.y*SRC_PI*2.0);
          float head=exp(-pow((uv.x-.86)*13.0,2.0));float radius=(head*.052+uv.x*.006)*(1.0-smoothstep(.12,.30,age));p=direction*(age*8.0+uv.x*(1.30-age*2.8))+(side*cos(uv.y*SRC_PI*2.0)+up*sin(uv.y*SRC_PI*2.0))*radius;vFade*=release*(1.0-smoothstep(.15,.34,age));}
        #elif SPELL == 11
          float turn=-uTime*2.4+aPhase*.1;p.yz=vs_rot(turn)*p.yz;n.yz=vs_rot(turn)*n.yz;p.yz*=1.0+.08*sin(uv.x*12.0-uTime*5.0+aPhase);
        #elif SPELL == 12
          if(abs(uQuantity-7.0)>.1){float r=aUnit<.5?0.0:.55+mod(aUnit,2.0)*.35;float angle=(aUnit-1.0)*SRC_PI*2.0/max(1.0,uQuantity-1.0);p.xz+=(vec2(cos(angle),sin(angle))-vec2(cos(aUnit*2.4),sin(aUnit*2.4)))*r;}
          float pop=uRetire>0.0?clamp(uRetire*1.55-fract(aPhase*.23)*.3,0.0,1.0):fract(uTime*.24+aPhase*.17);p.y*=.8+sin(pop*SRC_PI)*.5;p.y*=smoothstep(.0,.6,uOpening);vFade*=1.0-smoothstep(.91,1.0,pop);
        #endif
        #if SPELL != 4
          #if KIND == 3
            p.y=-1.3+(p.y+1.3)*uSize;p.xz*=uSize;
          #else
            p*=uSize;
          #endif
        #endif
        vP=p;vN=normalize(normalMatrix*n);gl_Position=projectionMatrix*modelViewMatrix*vec4(p,1.0);
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
  
    float fs_toonStep(float edge,float x){float aa=max(fwidth(x),.008);return smoothstep(edge-aa,edge+aa,x);}
    vec3 fs_toonShade(vec3 tint,float light){
      vec3 c=mix(tint*.28,tint*1.08,fs_toonStep(.40,light));
      return mix(c,mix(tint,vec3(1.0),.53)*1.15,fs_toonStep(.69,light));
    }
  
      #if SPELL == 3
        
      #endif
      void fs_main(inout vec4 gl_FragColor, inout float vFade, inout float vHalfLength, inout vec3 vN, inout vec3 vP, inout float vPart, inout float vPhase, inout float vSandMass, inout vec2 vStroke, inout vec2 vUv){
        #if SPELL == 3
          vec3 cyan=pow(uColor,vec3(.55))*vec3(.65,1.4,1.0);
          if(vPart>3.5){
            vec2 q=vUv*2.0-1.0;float r=length(q),a=atan(q.y,q.x),t=uTime,n=fs_noise2(vec2(cos(a),sin(a))*5.0+t*.8);
            float energy=0.0;
            if(vPart<4.5){
              float warped=r+(n-.5)*.10+(fs_noise2(vec2(cos(a),sin(a))*17.0-t*2.0)-.5)*.025;
              float flicker=.25+.75*smoothstep(.24,.72,fs_noise2(vec2(cos(a),sin(a))*4.0+floor(t*16.0)));
              float rim=(exp(-pow((warped-.68)*80.0,2.0))+exp(-pow((warped-.59)*110.0,2.0))*.65)*flicker;
              float swirl=pow(max(0.0,sin(a*3.0+log(max(.08,r))*13.0-t*11.0)),30.0)*(1.0-smoothstep(.12,.7,r));
              energy=rim*.8+swirl*.4+exp(-pow((warped-.63)*8.0,2.0))*(.08+n*.19)+exp(-r*r*12.0)*.16;
            }else{
              float front=.2+min(t,.75)*.75;
              float ripple=exp(-pow((r-front-(n-.5)*.04)*70.0,2.0));
              energy=exp(-r*r*9.0)*.25+ripple*.16+exp(-pow((r-front)*12.0,2.0))*.08;
            }
            gl_FragColor=vec4(cyan+vec3(pow(energy,3.0)),energy*vFade*(1.0-smoothstep(.82,1.0,r)));
    
    
  gl_FragColor.rgb*=min(1.0,gl_FragColor.a);gl_FragColor.a=min(1.0,gl_FragColor.a)*.6;return;
          }
          if(vPart>2.5){vec2 q=vUv*2.0-1.0;float r=length(q),hot=exp(-r*r*145.0),inner=exp(-r*r*35.0),halo=exp(-r*r*4.5),streak=exp(-q.y*q.y*1400.0-abs(q.x)*4.0);
            gl_FragColor=vec4(mix(uColor,cyan,inner)+vec3(hot*2.0),(hot+inner*.6+halo*.22+streak*.42)*vFade*(1.0-smoothstep(.8,1.0,r)));
    
    
  gl_FragColor.rgb*=min(1.0,gl_FragColor.a);gl_FragColor.a=min(1.0,gl_FragColor.a)*.6;return;}
          float edge=length(vec2(max(0.0,abs(vStroke.x)-vHalfLength),vStroke.y)),core=exp(-edge*edge*180.0),sheath=exp(-edge*edge*40.0),halo=exp(-edge*edge*6.0);
          gl_FragColor=vec4(mix(uColor,cyan,sheath)+vec3(core*1.5),(core+sheath*.65+halo*.18)*(1.0-smoothstep(.8,1.0,edge))*vFade);
    
    
  gl_FragColor.rgb*=min(1.0,gl_FragColor.a);gl_FragColor.a=min(1.0,gl_FragColor.a)*.6;return;
        #endif
        #if SPELL == 0
          if(vPart>1.5){
            float age=max(0.0,uTime/3.0-fract(vPhase*.618034)*.10);vec2 q=vUv*2.0-1.0;
            float spin=age*3.0+vPhase;q=mat2(vec2(cos(spin),-sin(spin)),vec2(sin(spin),cos(spin)))*q;
            vec3 n=fs_noiseGradient(q*2.5+vec2(vPhase*7.0,-age*2.0));float d=length(q)+(n.x-.5)*.30;
            vec2 lit=fs_smokeOptics(q,n.yz*2.5,n.x,vN);float burn=smoothstep(.45,.96,age);
            float alpha=(1.0-smoothstep(.76,.98,d))*smoothstep(.05+burn*.65,.20+burn*.65,n.x+(1.0-d)*.5)*vFade;
            float heat=.12+n.x*.39+(1.0-d)*.30+lit.x*.16;
            vec3 c=mix(uColor*.23,uColor*1.08,fs_toonStep(.4,heat));c=mix(c,vec3(1,.91,.53),fs_toonStep(.67,heat));
            if(alpha<.005)discard;gl_FragColor=vec4(c,alpha);
    
    
  return;
          }
        #endif
        #if SPELL == 8
          if(vPart>1.5){vec2 q=vUv*2.0-1.0;vec3 nn=fs_noiseGradient(q*2.7+vec2(vPhase*6.0,-uTime*.8));float d=length(q)+(nn.x-.5)*.32;
            float alpha=(1.0-smoothstep(.62,.98,d))*smoothstep(.05,.23,nn.x+(1.0-d)*.25)*vFade;
            vec2 optic=fs_smokeOptics(q,nn.yz*2.7,nn.x,vN);vec3 c=mix(uColor*.7,vec3(.83,.96,1),fs_toonStep(.42,optic.x*.5+nn.x*.3+.2));
            if(alpha<.004)discard;gl_FragColor=vec4(c,alpha);
    
    
  return;}
        #endif
        vec3 shadingNormal=normalize(vN);
        #if SPELL == 0 || SPELL == 5 || SPELL == 6 || SPELL == 11
          shadingNormal=normalize(cross(dFdx(vP),dFdy(vP)));
        #endif
        float shade=.25+.65*abs(dot(shadingNormal,normalize(vec3(-.4,.8,.5))));float alpha=vFade;float ink=0.0;
        #if SPELL == 0
          float age=max(0.0,uTime/3.0-fract(vPhase*.618034)*.10);
          float n=fs_noise2(vec2(vUv.x*6.0-age*4.0,vUv.y*3.0+vPhase*1.7));
          float curl=fs_noise2(vec2(vUv.x*12.0-age*6.0,vUv.y*5.0+vPhase));
          float burn=smoothstep(.43,.93,age)*(1.0-vUv.x*.4);
          float tear=n*.65+curl*.20+sin(vUv.x*SRC_PI)*.25-burn*1.35;
          alpha*=smoothstep(.01,.09,tear)*(1.0-smoothstep(.64,.86,age));
          shade=.13+n*.27+shade*.20+pow(max(0.0,sin(vUv.y*SRC_PI*2.0+vUv.x*4.0-age*3.0)),3.0)*.35;
        #elif SPELL == 3
          shade=.52+.35*pow(abs(cos(vUv.y*6.283)),3.0);
        #elif SPELL == 4
          float axial=pow(max(0.0,cos(vP.x*7.0-uTime*8.0)),10.0);shade=vPart<.5?.93:.6+axial*.3;
          alpha*=vPart>1.5?.16+.12*axial:vPart>.5?sin(vUv.x*3.14159)*(.55+.3*axial):.94;
        #elif SPELL == 5 || SPELL == 7
          #if SPELL == 5
            alpha*=1.0-smoothstep(.87,1.0,uRetire);
            float curse=fract(vUv.x*8.0-uTime*.9+vPhase*.17);
            float etch=1.0-smoothstep(.04,.13,abs(curse-.5));
            float stain=fs_noise2(vec2(vUv.x*5.0-uTime*1.1,vUv.y*2.0+vPhase));
            shade=mix(.14,.47,smoothstep(.51,.67,stain));shade=max(shade,etch*.77*pow(abs(sin(vUv.y*SRC_PI*2.0)),7.0));
            alpha*=smoothstep(uRetire*.8-.12,uRetire*.8+.08,stain+vUv.x*.18);
            alpha*=smoothstep(.0,.06,vUv.x);
          #endif
          #if SPELL == 7
            shade*=.64;
          #endif
          #if SPELL == 7
            shade+=.22*pow(max(0.0,sin(vUv.x*14.0-uTime*3.0)),8.0);
          #endif
        #elif SPELL == 8
          float foam=fs_noise2(vec2(vUv.x*23.0,vUv.y*5.0-uTime*1.8));float age=max(.0,uTime/3.2-abs(vUv.x*2.0-1.0)*.17);
          float crest=pow(vUv.y,5.0),breakup=smoothstep(.29,.62,age);
          alpha*=smoothstep(.0,.08,sin(vUv.x*SRC_PI))*smoothstep(.015,.10,vSandMass);
          shade=.16+.42*max(0.0,dot(shadingNormal,normalize(vec3(-.4,.8,.5))))+foam*.17;
          if(vPart>1.5){shade=.18+shade*.65;float top=sin(vUv.y*SRC_PI*2.0);shade=max(shade,smoothstep(.52,.8,top)*.93);alpha*=smoothstep(.0,.12,sin(vUv.x*SRC_PI));}
          else if(vPart>.5){shade=.94;alpha*=smoothstep(.35,.64,foam)*.88;}
          else{float torn=foam+(1.0-vUv.y)*.20;alpha*=smoothstep(breakup*.52-.08,breakup*.52+.08,torn);}
        #elif SPELL == 9
          float grain=fs_noise2(vec2(vUv.x*34.0,vUv.y*13.0+uTime*4.0));float slide=pow(.5+.5*sin(vUv.y*39.0+uTime*13.0+sin(vUv.x*28.0)*2.0),16.0);
          shade=.18+max(.0,dot(shadingNormal,normalize(vec3(-.65,.65,.35))))*.28+fs_noise2(vec2(vUv.x*10.0,vUv.y*14.0+uTime*4.0))*.20;alpha*=smoothstep(.015,.065,vSandMass);alpha*=smoothstep(.0,.12,sin(vUv.x*SRC_PI))*smoothstep(.0,.10,sin(vUv.y*SRC_PI));alpha*=1.0-smoothstep(.61+vUv.y*.15,.80+vUv.y*.15,uRetire);
        #elif SPELL == 10
          shade=vPart>1.5?mix(.44,.98,smoothstep(.72,.84,vUv.x)):.75;alpha*=vPart>1.5?pow(vUv.x,1.4)*.95:1.0;
        #elif SPELL == 11
          float flow=fs_noise2(vec2(vUv.x*8.0+uTime*1.6,vPhase*3.4+vUv.y*2.0));alpha*=smoothstep(.0,.06,vUv.x)*(1.0-smoothstep(.8,1.0,vUv.x))*smoothstep(.05,.20,flow)*.85;shade=.19+shade*.30+pow(max(0.0,sin(vUv.y*SRC_PI*2.0)),4.0)*.27+pow(max(0.0,sin(vUv.x*12.0+uTime*6.0+vPhase)),8.0)*.16;
        #endif
        #if SPELL == 12
          float pop=uRetire>0.0?clamp(uRetire*1.55-fract(vPhase*.23)*.3,0.0,1.0):fract(uTime*.24+vPhase*.17);float hole=smoothstep(.62,.81,pop);float edge=1.0-hole-vUv.y+sin(vUv.x*31.4+vPhase)*hole*.045;alpha*=smoothstep(-.015,.03,edge);float rim=1.0-smoothstep(.0,.07,abs(edge));float membrane=pow(1.0-abs(dot(shadingNormal,vec3(0,0,1))),2.0);shade=.10+shade*.30+max(rim,membrane)*.55;alpha*=.22+max(rim,membrane)*.65;
        #elif SPELL == 6
          if(vPart>1.5)alpha*=1.0-smoothstep(.48-uRetire*.42,.52-uRetire*.42,abs(vUv.y-.5));
        #endif
        #if SPELL != 0 && SPELL != 3 && SPELL != 4 && SPELL != 8 && SPELL != 9 && SPELL != 10 && SPELL != 11 && SPELL != 12
          float edge=abs(dot(normalize(vN),vec3(0,0,1)));ink=1.0-smoothstep(.04,.13+fwidth(edge),edge);
        #endif
        vec3 c=mix(fs_toonShade(uColor,shade),uColor*.09,ink*.8);
        #if SPELL == 0
          c=mix(uColor*.25,uColor*1.08,fs_toonStep(.36,shade));c=mix(c,vec3(1.0,.92,.58),fs_toonStep(.65,shade));
        #elif SPELL == 8
          if(vPart>.5&&vPart<1.5)c=vec3(.83,.96,1.0);
          if(vPart>1.5)c=mix(c,vec3(.83,.96,1.0),smoothstep(.55,.85,sin(vUv.y*SRC_PI*2.0)));
        #endif
        if(alpha<.003)discard;gl_FragColor=vec4(c,alpha);
    
    
  
      }
void vertex(){
float aPart = CUSTOM0.x;
float aPhase = CUSTOM0.y;
float aUnit = CUSTOM0.z;
vec4 gl_Position = vec4(0);
mat4 modelMatrix = MODEL_MATRIX;
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 normal = NORMAL;
mat3 normalMatrix = MODELVIEW_NORMAL_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
float vFade = float(0);
float vHalfLength = float(0);
vec3 vN = vec3(0);
vec3 vP = vec3(0);
float vPart = float(0);
float vPhase = float(0);
float vSandMass = float(0);
vec2 vStroke = vec2(0);
vec2 vUv = vec2(0);
mat4 viewMatrix = VIEW_MATRIX;
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(aPart, aPhase, aUnit, gl_Position, modelMatrix, modelViewMatrix, normal, normalMatrix, position, projectionMatrix, uv, vFade, vHalfLength, vN, vP, vPart, vPhase, vSandMass, vStroke, vUv, viewMatrix);
bridge_vPart = vPart;
bridge_vUv = vUv;
bridge_vN = vN;
bridge_vP = vP;
bridge_vFade = vFade;
bridge_vPhase = vPhase;
bridge_vSandMass = vSandMass;
bridge_vStroke = vStroke;
bridge_vHalfLength = vHalfLength;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
float vFade = bridge_vFade;
float vHalfLength = bridge_vHalfLength;
vec3 vN = bridge_vN;
vec3 vP = bridge_vP;
float vPart = bridge_vPart;
float vPhase = bridge_vPhase;
float vSandMass = bridge_vSandMass;
vec2 vStroke = bridge_vStroke;
vec2 vUv = bridge_vUv;
fs_main(gl_FragColor, vFade, vHalfLength, vN, vP, vPart, vPhase, vSandMass, vStroke, vUv);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
