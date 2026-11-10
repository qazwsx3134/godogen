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
#define FLOW_VARIANT 0
uniform float uSize;
uniform float uTime;
uniform float uRetire;
uniform float uOpening;
uniform float uStoppedAt;
uniform float uDetail;
uniform vec3 uColor;
uniform float uGlow;
varying float bridge_vVolume;
varying vec2 bridge_vUv;
varying float bridge_vLight;
varying float bridge_vSeed;
varying float bridge_vFade;
varying float bridge_vHeight;


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
  
      void vs_main(inout vec4 gl_Position, inout mat4 modelMatrix, inout mat4 modelViewMatrix, inout vec3 position, inout mat4 projectionMatrix, inout vec2 uv, inout float vFade, inout float vHeight, inout float vLight, inout float vSeed, inout vec2 vUv, inout float vVolume){vUv=uv;vVolume=0.0;float s=position.x,id=position.z;
        #if TOON == 1 && (FLOW_VARIANT == 1 || FLOW_VARIANT == 2)
          vVolume=id<22.0?1.0:0.0;id=mod(id,22.0);
        #endif
        vSeed=id;float t=uStoppedAt<0.0?uTime:uStoppedAt+1.4*(uRetire-.35*uRetire*uRetire);
        float r1=vs_hash(vec2(id,1.0)),r2=vs_hash(vec2(id,3.0)),r3=vs_hash(vec2(id,7.0));float phase=r1;
        #if TOON == 1 && (FLOW_VARIANT == 1 || FLOW_VARIANT == 2)
        if(vVolume>.5){ float born=fract(vs_hash(vec2(id,23.7))+(uStoppedAt<0.0?uTime:uStoppedAt)*(.14+r2*.035));
          float h=born,spin=id*2.399963-uTime*(2.0+r2*.3)+h*3.0;
          float radius=.30+pow(h,1.3)*1.45+.22*(1.0-smoothstep(.05,.55,h));
          vec3 p=vec3(cos(spin)*radius,h*3.5,sin(spin)*radius);
          float release=smoothstep(r2*.16,.95,uRetire);
          #if FLOW_VARIANT == 1
            p.y-=release*release*(1.7+h*2.4);p.xz*=1.0+release*.22;
          #else
            p.y+=release*(.8+h*.6);p.xz+=vec2(-sin(spin),cos(spin))*release*.6;
          #endif
          
          float gather=(1.0-smoothstep(.02,.78,uOpening))*(1.0-smoothstep(0.0,.6,uRetire));
          p.xz+=vec2(-sin(spin),cos(spin))*gather*(1.2+h*1.5);p.xz*=1.0+gather*.38;p.y+=gather*h*.35;
          p*=uSize;p.y-=1.4;
          float width=(.65+h*.75)*( .88+r3*.24)*(1.0+gather*.15);
          vec4 mv=modelViewMatrix*vec4(p,1.0);vec2 tangent=normalize((modelViewMatrix*vec4(-sin(spin),.48,cos(spin),0.0)).xy+vec2(.0001));
          mv.xy+=mat2(vec2(tangent.x,tangent.y),vec2(-tangent.y,tangent.x))*(uv-.5)*width*uSize*vec2(1.55,FLOW_VARIANT==2?.40:.56)*length(modelMatrix[1].xyz);
          vLight=spin;vHeight=h;vFade=smoothstep(0.0,.12,uOpening)*smoothstep(.0,.09,h)*(1.0-smoothstep(.88,1.0,h))*(1.0-smoothstep(.72,1.0,uRetire));
          #if FLOW_VARIANT == 1
            vFade*=smoothstep(-1.5,-1.12,p.y);
          #endif
          gl_Position=projectionMatrix*mv;return; }
        #endif
        #if FLOW_VARIANT == 1 || FLOW_VARIANT == 2
          float exitAge=smoothstep(.02+r2*.34,.92,uRetire);s=mix(s,.24+r3*.45,exitAge*(FLOW_VARIANT==1?.24:.12));
        #endif
        float life=fract(r1+t*(0.065+r2*0.055));
        float h=0.025+life*0.77+s*(0.12+r3*0.23);
        #if TOON == 1
          
          float family=id,lane=0.0;
          phase=fract(id*.6180339);
          #if FLOW_VARIANT != 0
            phase=vs_hash(vec2(id,23.7));
          #endif
          life=fract(phase+(uStoppedAt<0.0?t:uStoppedAt)*(.072+vs_hash(vec2(family,8.0))*.025));if(uStoppedAt>=0.0)life=min(1.0,life+uRetire*.27);
          h=.025+life*.68+s*(.18+r3*.13);
          #if FLOW_VARIANT != 0
            life=fract(phase+(uStoppedAt<0.0?t:uStoppedAt)*(.10+r2*.025));
            h=.02+life*.52+s*(.27+r3*.21);
            if(mod(id,5.0)<.5)h=.025+s*.40;
          #endif
        #endif
        float lean=sin(h*3.0+t*0.45)*h*0.22;
        #if TOON == 1 && FLOW_VARIANT == 3
          s=mix(s,.2+r2*.5,smoothstep(.02+r3*.12,.85,uRetire)*.80);
        #endif
        float pitch=1.2+r2*3.1;
        float a=r3*SRC_PI*2.0+s*pitch-t*(2.0+r2*0.65)+sin(s*5.0+t*0.7+id)*0.18;
        #if TOON == 1
          
          a=family*2.39996323+s*(3.5+r2*1.2)-t*(2.05+phase*.2)+lane*.16;
          a+=sin(h*5.0-t*.65)*.28+sin(s*SRC_PI)*sin(s*4.0-t*.8+phase*6.28)*.22;
          #if FLOW_VARIANT == 1 || FLOW_VARIANT == 2
            a-=exitAge*(.2+r3*1.3);
          #endif
        #endif
        float taper=pow(max(0.0,sin(s*SRC_PI)),0.55+r2*0.8);
        float width=(0.045+h*(0.10+r1*0.17))*taper;
        if(mod(id,6.0)<0.5)width*=1.8;
        #if TOON == 1
          width*=1.8+(.5+.5*sin(id*2.3))*.25;
          #if FLOW_VARIANT != 0
            width+=.08*taper*(1.0-h*.6);
          #endif
        #endif
        #if FLOW_VARIANT == 0
          width*=1.10;
        #elif FLOW_VARIANT == 1
          width*=1.2;
        #elif FLOW_VARIANT == 3
          width*=0.65;a+=sin(s*9.0+id)*0.12;
        #endif
        float tear=(sin(s*47.0+t*3.0+id)*0.022+sin(s*97.0-t*4.0)*0.008)*taper;
        float curl=sin(s*SRC_PI)*sin(s*6.0+t*0.8+id)*0.15;
        float y=h*3.55+curl+position.y*(width+tear*abs(position.y));
        float radius=(0.08+pow(h,1.35)*1.2+pow(h,4.0)*0.65)*(0.72+r3*0.40);
        radius+=sin(s*9.0-t*0.9+id)*0.07*h+position.y*width*0.4;
        #if TOON == 1
          radius+=.22*(1.0-smoothstep(.08,.55,h));
          #if FLOW_VARIANT != 0
            radius-=pow(h,4.0)*.25;
            radius+=sin(h*5.0-t*.9+id*.6)*.10*sin(s*SRC_PI);
          #endif
          
          float roll=sin(h*4.5-t*.9+phase*2.0)*.65+sin(s*SRC_PI)*.5;
          #if FLOW_VARIANT == 1 || FLOW_VARIANT == 2
            roll+=exitAge*(1.8+r3)*sin(s*SRC_PI);
          #endif
          float across=position.y*1.9+roll;
          float center=cos(roll),edge=cos(across);
          radius+=(edge-center)*width*.95+sin(h*7.0-t*.8)*.08*sin(s*SRC_PI);
          #if FLOW_VARIANT == 1 || FLOW_VARIANT == 2
            float roundExit=smoothstep(.04,.55,uRetire);
            radius=mix(radius,radius-(edge-center)*width*.95+cos(position.y*SRC_PI+roll)*width*.7,roundExit);
          #endif
          y=h*3.55+curl+(sin(across)-sin(roll))*width*1.3;
          #if FLOW_VARIANT == 1 || FLOW_VARIANT == 2
            y=mix(y,h*3.55+curl+sin(position.y*SRC_PI+roll)*width*.7,roundExit);
          #endif
          y+=sin(h*4.0-t*.9+phase*2.0)*.10*sin(s*SRC_PI);
          #if FLOW_VARIANT == 3
            radius+=(cos(position.y*SRC_PI)-1.0)*width*.42;
            y=h*3.55+curl+sin(position.y*SRC_PI)*width*.42;
          #endif
          a+=lane*.035*(1.0-smoothstep(.4,1.0,h));
        #endif
        vec3 p=vec3(cos(a)*radius+lean,y,sin(a)*radius);
        p.z+=sin(h*4.0+t*0.31)*h*0.10;
        vec3 eddy=vs_curlFlow(p*1.1,t);
        p+=eddy*(0.07+h*0.12);
        vLight=clamp(0.5+0.5*sin(a-0.8)+eddy.y*0.12,0.0,1.0);
        #if TOON == 1
          vec3 surfaceNormal=vec3(cos(a)*cos(across),-sin(across),sin(a)*cos(across));
          vLight=clamp(.45+dot(surfaceNormal,vec3(-.38,.58,.72))*.52+eddy.y*.08,0.0,1.0);
        #endif
        float peel=smoothstep(phase*.09,.85,uRetire);vec2 tangent=vec2(-sin(a),cos(a));
        #if FLOW_VARIANT == 1 || FLOW_VARIANT == 2
          p.xz+=tangent*exitAge*(.12+r2*.32);
        #else
          p.xz+=tangent*peel*(.8+h*1.15);p.xz*=1.0+peel*.38;p.y+=peel*h*.35;
        #endif
        #if FLOW_VARIANT == 1
          float collapse=exitAge;
          float sag=smoothstep(.0,.7,collapse)*(.35+.65*pow(s,1.5));
          p.y-=collapse*collapse*(2.4+r3*2.4)+sag*width;
          p.xz*=1.0+collapse*.12;p.y-=position.y*width*collapse*.5;
        #elif FLOW_VARIANT == 2
          p.y+=exitAge*(.85+phase*.9);p.xz*=1.0+exitAge*.12;
        #endif
        p.xz*=1.20;p.y*=1.08;vHeight=h;float gather=(1.0-smoothstep(.04,1.0,uOpening))*(1.0-smoothstep(0.0,.6,uRetire));
        
        p.xz+=tangent*gather*(.8+h*1.15);p.xz*=1.0+gather*.38;p.y+=gather*h*.35;
        p*=uSize;p.y-=1.4;
        vFade=smoothstep(0.0,.12,uOpening)*smoothstep(0.0,0.10,life)*(1.0-smoothstep(0.85,1.0,life));vFade*=1.0-smoothstep(.48+phase*.18,.88+phase*.1,uRetire);
        #if FLOW_VARIANT == 1
          vFade*=smoothstep(-1.4,-1.1,p.y);
        #endif
        gl_Position=projectionMatrix*modelViewMatrix*vec4(p,1.0);}


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
  
      void fs_main(inout vec4 gl_FragColor, inout bool source_front_facing, inout float vFade, inout float vHeight, inout float vLight, inout float vSeed, inout vec2 vUv, inout float vVolume){
        #if TOON == 1 && (VARIANT == 1 || VARIANT == 2)
        if(vVolume>.5){ vec2 q=vUv*2.0-1.0;float spin=-uTime*.8+vSeed*.7;q=mat2(vec2(cos(spin),-sin(spin)),vec2(sin(spin),cos(spin)))*q;
          vec3 n=fs_noiseGradient(q*2.4+vec2(vSeed*9.0,-uTime*.45));float d=length(q)+(n.x-.5)*.35;
          vec3 key=vec3(-.45,.8,.55);vec2 optics=fs_smokeOptics(q,n.yz*2.4,n.x,key);
          float a=(1.0-smoothstep(.73,.98,d))*smoothstep(.02,.18,n.x+(1.0-d)*.3)*vFade;
          vec3 c=fs_styleColor(uColor*.8,.20+optics.x*.44+n.x*.10);
          #if VARIANT == 2
            float burn=smoothstep(.08,.95,uRetire),heat=.16+optics.x*.15+n.x*.20+pow(max(0.0,1.0-abs(q.y)),1.4)*.43;
            a*=smoothstep(.10+burn*.50,.23+burn*.48,n.x+(1.0-d)*.35);
            c=fs_styleHeat(uColor,heat);c=mix(c,uColor*vec3(.26,.075,.03),burn*.65);
          #endif
          a*=VARIANT==2?.46:.42;if(a<.004)discard;gl_FragColor=vec4(c,a);
    
    
  return; }
        #endif
        float s=vUv.x,w=vUv.y;
        vec2 skew=vec2(s+w*0.28,w+s*0.16);
        float warp=fs_noise2(skew*vec2(8.0,3.0)+vec2(-uTime*0.55,vSeed*2.3));
        #if TOON == 1
          float family=vSeed;
          float n=fs_noise2(vec2(s*7.0-uTime*.95,w*2.1+family*3.7+warp*.6));
        #else
          float n=fs_fbm(vec2(s*25.0-uTime*(1.2+fract(vSeed*0.13)),w*5.0+vSeed*3.7+warp*1.5));
        #endif
        float fiber=fs_noise2(vec2(s*10.0-uTime*2.0,w*31.0+vSeed));
        float rim=abs(w*2.0-1.0);
        float silhouette=1.0-smoothstep(0.56+n*0.3,0.72+n*0.28,rim);
        float split=smoothstep(0.20,0.46,n+sin(w*29.0+s*7.0)*0.09);
        #if TOON == 1
          split=smoothstep(.18,.36,n);
          #if VARIANT == 1
            split=smoothstep(.28,.47,n);
          #endif
        #endif
        float tip=smoothstep(0.0,0.04,s)*(1.0-smoothstep(0.80,1.0,s));
        float departure=smoothstep(uRetire*.85-.15,uRetire*.85+.08,n*.55+(1.0-s)*.45);float alpha=silhouette*split*tip*vFade*departure;
        #if VARIANT == 2
          float delay=fract(vSeed*.381966)*.24+vHeight*.16;
          float exitBurn=smoothstep(.04+delay,.80+delay*.25,uRetire);
          float flameFront=n*.60+sin(s*SRC_PI)*.4-exitBurn*.82;alpha*=smoothstep(-.03,.10,flameFront);
          alpha*=1.0-smoothstep(.60,.95,uRetire+fract(vSeed*.23)*.15);
        #elif VARIANT == 1
          float grain=fs_noise2(vec2(s*21.0,w*34.0-uTime*2.0+vSeed));
          alpha*=mix(1.0,smoothstep(.18,.40,grain),smoothstep(.10,.55,uRetire));
          alpha*=smoothstep(uRetire*.55-.08,uRetire*.55+.12,n);
        #endif
        float crest=exp(-pow((w-0.68-(n-0.5)*0.32)*18.0,2.0));
        float streak=pow(max(0.0,sin(w*48.0+n*6.0+s*3.0)),16.0);
        vec3 c;float lum=0.25+vLight*0.75;
        #if VARIANT == 0
          c=uColor*(0.12+lum*0.6+crest*0.8);alpha*=0.6;
        #elif VARIANT == 1
          c=uColor*(0.09+lum*0.4+fiber*0.13);alpha*=0.85;
        #elif VARIANT == 2
          #if TOON == 1
            float fireNoise=fs_noise2(vec2(w*4.0+vSeed,s*11.0-uTime*2.4));
            vec3 burn=vec3(smoothstep(.20,.40,fireNoise),fireNoise,fs_styleStep(.68,fireNoise)*.5);
          #else
            vec3 burn=fs_flameErosion(vec2(w,s*2.0),uTime*1.3,vSeed*0.37);
          #endif
          alpha*=burn.x;
          c=fs_flameColor(uColor,burn.y*0.90+lum*0.08)*(0.40+lum*0.6);
          if(!source_front_facing)c*=0.38;
          c+=uColor*burn.z*0.55;
          crest=max(crest*0.45,burn.z*0.7);
        #else
          float gaps=step(0.12,fract(s*7.0+vSeed*0.3));
          #if TOON == 0
            alpha*=gaps;
          #endif
          c=uColor*(0.1+lum*0.7+crest*1.2);
        #endif
        #if TOON == 1
          c=fs_styleColor(uColor,.15+vLight*.6+n*.18+crest*.16);
          #if VARIANT == 1
            c=fs_styleColor(uColor*.82,.20+vLight*.37+n*.12+crest*.08);
          #elif VARIANT == 2
            float warmth=.19+vLight*.32+n*.33+crest*.11;
            c=fs_styleHeat(uColor,warmth);if(!source_front_facing)c*=.70;
          #elif VARIANT == 3
            float packet=pow(max(0.0,sin(s*12.0-uTime*4.5+vSeed*1.3)),6.0);
            c=fs_styleColor(uColor,.20+vLight*.36+packet*.33+crest*.12);
          #endif
        #endif
        if(uGlow>0.5){
          alpha*=crest*(0.25+lum*0.75)+streak*0.10;
          if(!source_front_facing)alpha*=0.3;
          #if VARIANT == 1
            alpha*=0.12;
          #elif VARIANT == 0
            alpha*=0.35;
          #endif
          c=uColor*1.7+vec3(0.3,0.19,0.07)*crest;alpha*=uDetail*0.8;
        }
        #if TOON == 1
          if(uGlow>.5){c=fs_styleColor(uColor,.82);alpha*=.28;}
          
          float contour=.65+n*.28-rim;
          contour=min(contour,min(s*5.0,(1.0-s)*2.0));
          float pixel=max(fwidth(contour),.002);
          float ink=1.0-smoothstep(pixel*.5,pixel*1.9,contour);
          float edgeCoverage=smoothstep(-pixel,pixel,contour);
          alpha*=edgeCoverage;
          vec3 inkColor=mix(vec3(.012,.016,.022),uColor*.055,.65);
          c=mix(c,inkColor,ink*(VARIANT==0?.55:.25)*(1.0-uRetire*.7));
          #if VARIANT == 2
            c=mix(c,uColor*vec3(.22,.045,.012),smoothstep(.35,.9,uRetire)*.82);
          #endif
        #endif
        #if TOON == 1 && (VARIANT == 1 || VARIANT == 2)
          alpha*=VARIANT==2?.90:.62;
        #endif
        #if TOON == 1 && VARIANT == 3
          
          float track=.49+.15*sin(s*5.0-uTime*.6+vSeed*1.3);
          float stripe=1.0-smoothstep(.035,.15,abs(w-track));
          float chargePhase=fract(s*2.4-uTime*.8+vSeed*.23);
          float pulse=smoothstep(.05,.24,chargePhase)*(1.0-smoothstep(.68,.94,chargePhase));
          float light=.29+vLight*.13+stripe*(.24+pulse*.33);
          c=fs_styleColor(uColor,light);
          float cut=smoothstep(.08,.8,uRetire);float islands=smoothstep(.15+cut*.40,.27+cut*.42,fs_noise2(vec2(s*9.0-uTime*.6,vSeed*2.7)));
          alpha=silhouette*split*tip*vFade*departure*(.84+stripe*.10)*islands;
        #endif
        gl_FragColor=vec4(c,alpha);
    
    
  }
void vertex(){
vec4 gl_Position = vec4(0);
mat4 modelMatrix = MODEL_MATRIX;
mat4 modelViewMatrix = MODELVIEW_MATRIX;
vec3 position = VERTEX;
mat4 projectionMatrix = PROJECTION_MATRIX;
vec2 uv = UV;
float vFade = float(0);
float vHeight = float(0);
float vLight = float(0);
float vSeed = float(0);
vec2 vUv = vec2(0);
float vVolume = float(0);
source_draw = float(VERTEX_ID % source_vertices_per_instance);
source_instance = float(VERTEX_ID / source_vertices_per_instance);
vs_main(gl_Position, modelMatrix, modelViewMatrix, position, projectionMatrix, uv, vFade, vHeight, vLight, vSeed, vUv, vVolume);
bridge_vVolume = vVolume;
bridge_vUv = vUv;
bridge_vLight = vLight;
bridge_vSeed = vSeed;
bridge_vFade = vFade;
bridge_vHeight = vHeight;
POSITION = gl_Position;
}
void fragment(){
if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;
vec4 gl_FragColor = vec4(0);
bool source_front_facing = FRONT_FACING;
float vFade = bridge_vFade;
float vHeight = bridge_vHeight;
float vLight = bridge_vLight;
float vSeed = bridge_vSeed;
vec2 vUv = bridge_vUv;
float vVolume = bridge_vVolume;
fs_main(gl_FragColor, source_front_facing, vFade, vHeight, vLight, vSeed, vUv, vVolume);
ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);
}
