// 00GameDevs MIT 2026 @00vchannel. Full-frame shader, original equations.
// Compatibility canvas; original bounded 16-tap stroke sampling retained.
shader_type canvas_item;
render_mode unshaded;
varying vec2 vUv;
void vertex(){vUv=vec2(UV.x,1.0-UV.y);}

      
      
      uniform sampler2D tInput : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D tSubject : repeat_disable, filter_linear;
      uniform float hasSubject;
uniform float threshold;
uniform float softness;
uniform float intensity;
uniform float inverted;
uniform float strokeLength;
uniform float inkDensity;
uniform float frame;
uniform float backgroundSuppression;
uniform float starSize;
uniform float starStrength;
      uniform vec2 center;
uniform vec2 resolution;
uniform vec2 attackDirection;
      uniform vec4 stars[4];
      uniform float reverseStars[4];
      vec4 sample_scene(vec2 uv){return texture(tInput,vec2(uv.x,1.0-uv.y));}
vec4 sample_subject(vec2 uv){return texture(tSubject,vec2(uv.x,1.0-uv.y));}
float hash(float n){return fract(sin(n*127.1+311.7)*43758.5453);}
      float luma(vec2 uv){vec3 c=sample_scene(clamp(uv,vec2(0.0),vec2(1.0))).rgb;return dot(max(c,vec3(0.0)),vec3(.2126,.7152,.0722));}
      float classify(float l){return softness<=0.0?step(threshold,l):smoothstep(threshold-softness*.5,threshold+softness*.5,l);}
      float subject(vec2 uv){if(hasSubject<.5||any(lessThan(uv,vec2(0.0)))||any(greaterThan(uv,vec2(1.0))))return 0.0;return sample_subject(uv).r;}
      float mark(vec2 uv,vec2 scale){
        if(any(lessThan(uv,vec2(0.0)))||any(greaterThan(uv,vec2(1.0))))return 0.0;
        float l=luma(uv),focus=1.0-smoothstep(.06,.34,length((uv-center)*scale));
        float light=classify(l)*mix(1.0,clamp(smoothstep(1.1,2.8,l)+focus*.85,0.0,1.0),backgroundSuppression);
        return max(subject(uv),light);
      }
      // Interpolated, footprint-filtered fibers: fixed within a pose, never
      // screen-pixel hash teeth. All widths scale with the authored star.
      float fiberNoise(float x,float phase){
        float cell=floor(x),f=fract(x);f=f*f*(3.0-2.0*f);
        float n=mix(hash(cell+phase*113.0),hash(cell+1.0+phase*113.0),f);
        return mix(n,.5,smoothstep(.35,1.0,fwidth(x)));
      }
      float brushArm(vec2 p,float halfSpan,float phase,float inkWeight,float compact){
        float u=abs(p.x)/max(halfSpan,.0001);
        float grain=fiberNoise(p.x*240.0,phase);
        float groups=fiberNoise(p.x*47.0,phase+7.0);
        float taper=pow(max(0.0,1.0-u*u),1.7);
        float armThickness=mix(.03,.14,inkWeight)*compact,heartThickness=mix(.035,.09,inkWeight)*compact;
        float halfWidth=halfSpan*(armThickness+heartThickness*exp(-u*9.0))*taper;
        float fringeWidth=halfSpan*mix(.07,.14,inkWeight)*compact*taper*(.3+.7*grain)*(.8+.2*groups);
        float aa=max(fwidth(p.y),.5/max(1.0,min(resolution.x,resolution.y)));
        float across=abs(p.y);
        float solid=1.0-smoothstep(halfWidth*.55,halfWidth+aa,across);
        float fibers=(1.0-smoothstep(halfWidth*.5,halfWidth+fringeWidth+aa,across))*(.65+.35*grain);
        float tip=1.0-smoothstep(.82,1.0,u);
        return max(solid,fibers)*tip;
      }
      float fourPoint(vec2 p,float span,float phase,float inkWeight,float compact){
        float h=brushArm(p,span*.5,phase,inkWeight,compact),v=brushArm(p.yx,span*.5,phase+17.0,inkWeight,compact);
        return 1.0-(1.0-h)*(1.0-v);
      }
      float starInkPatch(vec2 p,float span,float phase){
        float r=length(p),angle=r>.00001?atan(p.y,p.x):0.0;
        // Periodic direction noise avoids a seam at atan's wrap.
        float groups=.5+.25*sin(angle*7.0+phase)+.25*sin(angle*13.0-phase);
        float fibers=.5+.5*sin(angle*45.0+sin(angle*19.0)*2.0+phase);
        fibers=mix(fibers,.5,smoothstep(.35,1.0,fwidth(angle)*45.0));
        float reach=span*(.44+.36*groups);
        float wash=1.0-smoothstep(span*.22,reach,r);
        float brush=1.0-smoothstep(span*.3,reach*(.7+.3*fibers),r);
        float density=wash*.55+brush*(.45+.65*fibers);
        return 1.0-exp(-density*3.8);
      }
      // Authored terminal poses: one full-screen draw, no particles or history.
      // Dimensions are in viewport-short-side units; every pose is stateless.
      float terminalBlast(vec2 p,vec2 scale,bool shock){
        float r=length(p),a=r>.00001?atan(p.y,p.x):0.0;
        float coreRadius=shock?.4:.275;
        float edge=coreRadius*(1.0+.025*sin(a*3.0+.7)+.018*sin(a*7.0-1.2));
        float aa=1.2/max(1.0,min(resolution.x,resolution.y));
        float core=1.0-smoothstep(edge-aa,edge+aa,r),rays=0.0;
        float expansion=shock?1.45:1.0;
        for(int i=0;i<8;i++){
          float seed=float(i),angle=seed*.785398+.11+(hash(seed+37.0)-.5)*.55;
          vec2 axis=vec2(cos(angle),sin(angle));
          float along=dot(p,axis),across=abs(dot(p,vec2(-axis.y,axis.x)));
          float length=(.85+.8*hash(seed+9.0))*max(scale.x,scale.y)*expansion;
          float width=(.035+.085*hash(seed+18.0))*expansion;
          float opening=mix(.2,1.0,clamp(along/.8,0.0,1.0));
          float halfWidth=width*opening*pow(clamp(1.0-along/length,0.0,1.0),.22);
          float beam=(1.0-smoothstep(halfWidth-aa,halfWidth+aa,across))*step(0.0,along)*(1.0-smoothstep(length-aa,length+aa,along));
          rays=max(rays,beam);
        }
        for(int i=0;i<12;i++){
          float seed=float(i),angle=seed*.523599+(hash(seed+82.0)-.5)*.45;
          vec2 axis=vec2(cos(angle),sin(angle));
          float along=dot(p,axis),across=abs(dot(p,vec2(-axis.y,axis.x)));
          float start=coreRadius*(.72+.25*hash(seed+24.0));
          float length=(.16+.25*hash(seed+61.0))*expansion;
          float t=clamp((along-start)/length,0.0,1.0);
          float width=(.009+.02*hash(seed+53.0))*expansion*(1.0-t);
          float chip=(1.0-smoothstep(width-aa,width+aa,across))*step(start,along)*(1.0-step(start+length,along));
          rays=max(rays,chip);
        }
        // The second pose opens a larger white core inside the black strokes.
        return shock?rays*(1.0-core):max(core,rays);
      }
      void source_fragment(inout vec4 out_color){
        vec4 source=sample_scene(vUv);
        if(intensity<=0.0){out_color=source;return;}
        vec2 scale=resolution/max(1.0,min(resolution.x,resolution.y));
        if(frame>6.5){
          // center is the projected gameplay hit, not a decorative star position.
          // Clip the blast at the viewport edge; never move its origin inwards.
          float graphic=terminalBlast((vUv-center)*scale,scale,frame>7.5);
          float body=subject(vUv);
          // The silhouette changes polarity locally, retaining coverage in light
          // and dark regions alike. Finale strength is independent of star knobs.
          float ink=mix(graphic,1.0-graphic,body);
          float bw=mix(1.0-ink,ink,inverted);
          out_color=vec4(mix(source.rgb,vec3(bw),intensity),source.a);return;
        }
        vec2 delta=(vUv-center)*scale;
        float radius=length(delta);
        vec2 direction=length(attackDirection)>.001?normalize(attackDirection*scale):delta/max(radius,.00001);
        // One target per authored pose keeps the subject's stroke field coherent.
        // Inverse radial sampling draws source edges closer to that star; the
        // solid source remains untouched. No nearest-star seams or long hair fans.
        bool hasPullStar=starStrength>0.0&&stars[0].z>0.0;
        vec2 pullAnchor=clamp(center*scale+stars[0].xy,vec2(.08),scale-vec2(.08));
        vec2 toward=pullAnchor-vUv*scale;
        float starDistance=length(toward);
        if(hasPullStar)direction=toward/max(starDistance,.00001);
        vec2 tangent=vec2(-direction.y,direction.x);
        float shape=frame<.5?.16:frame<1.5?.85:frame<2.5?1.0:frame<3.5?.1:frame<4.5?.32:0.0;
        float angle=hasPullStar?(starDistance>.00001?atan(toward.y,toward.x):0.0):radius>.00001?atan(delta.y,delta.x):0.0;
        float lane=hasPullStar||length(attackDirection)<.001?floor(angle*38.0):floor(dot(delta,tangent)*240.0);
        float group=hash(lane+frame*19.0);
        float fine=hash(floor(angle*190.0)+frame*71.0);
        float reach=strokeLength*.21*shape*(.2+.8*group)*(.78+.22*fine);
        float body=subject(vUv),base=mark(vUv,scale),ink=base;
        if(reach>.00001){{int i=1;
          float t=float(i)/16.0;
          vec2 uv=vUv-direction/scale*(reach*t);
          float taper=1.0-t*(.35+.4*fine);
          float cut=step(.3*(1.0-inkDensity),group);
          ink=max(ink,mark(uv,scale)*taper*cut);
        }{int i=2;
          float t=float(i)/16.0;
          vec2 uv=vUv-direction/scale*(reach*t);
          float taper=1.0-t*(.35+.4*fine);
          float cut=step(.3*(1.0-inkDensity),group);
          ink=max(ink,mark(uv,scale)*taper*cut);
        }{int i=3;
          float t=float(i)/16.0;
          vec2 uv=vUv-direction/scale*(reach*t);
          float taper=1.0-t*(.35+.4*fine);
          float cut=step(.3*(1.0-inkDensity),group);
          ink=max(ink,mark(uv,scale)*taper*cut);
        }{int i=4;
          float t=float(i)/16.0;
          vec2 uv=vUv-direction/scale*(reach*t);
          float taper=1.0-t*(.35+.4*fine);
          float cut=step(.3*(1.0-inkDensity),group);
          ink=max(ink,mark(uv,scale)*taper*cut);
        }{int i=5;
          float t=float(i)/16.0;
          vec2 uv=vUv-direction/scale*(reach*t);
          float taper=1.0-t*(.35+.4*fine);
          float cut=step(.3*(1.0-inkDensity),group);
          ink=max(ink,mark(uv,scale)*taper*cut);
        }{int i=6;
          float t=float(i)/16.0;
          vec2 uv=vUv-direction/scale*(reach*t);
          float taper=1.0-t*(.35+.4*fine);
          float cut=step(.3*(1.0-inkDensity),group);
          ink=max(ink,mark(uv,scale)*taper*cut);
        }{int i=7;
          float t=float(i)/16.0;
          vec2 uv=vUv-direction/scale*(reach*t);
          float taper=1.0-t*(.35+.4*fine);
          float cut=step(.3*(1.0-inkDensity),group);
          ink=max(ink,mark(uv,scale)*taper*cut);
        }{int i=8;
          float t=float(i)/16.0;
          vec2 uv=vUv-direction/scale*(reach*t);
          float taper=1.0-t*(.35+.4*fine);
          float cut=step(.3*(1.0-inkDensity),group);
          ink=max(ink,mark(uv,scale)*taper*cut);
        }{int i=9;
          float t=float(i)/16.0;
          vec2 uv=vUv-direction/scale*(reach*t);
          float taper=1.0-t*(.35+.4*fine);
          float cut=step(.3*(1.0-inkDensity),group);
          ink=max(ink,mark(uv,scale)*taper*cut);
        }{int i=10;
          float t=float(i)/16.0;
          vec2 uv=vUv-direction/scale*(reach*t);
          float taper=1.0-t*(.35+.4*fine);
          float cut=step(.3*(1.0-inkDensity),group);
          ink=max(ink,mark(uv,scale)*taper*cut);
        }{int i=11;
          float t=float(i)/16.0;
          vec2 uv=vUv-direction/scale*(reach*t);
          float taper=1.0-t*(.35+.4*fine);
          float cut=step(.3*(1.0-inkDensity),group);
          ink=max(ink,mark(uv,scale)*taper*cut);
        }{int i=12;
          float t=float(i)/16.0;
          vec2 uv=vUv-direction/scale*(reach*t);
          float taper=1.0-t*(.35+.4*fine);
          float cut=step(.3*(1.0-inkDensity),group);
          ink=max(ink,mark(uv,scale)*taper*cut);
        }{int i=13;
          float t=float(i)/16.0;
          vec2 uv=vUv-direction/scale*(reach*t);
          float taper=1.0-t*(.35+.4*fine);
          float cut=step(.3*(1.0-inkDensity),group);
          ink=max(ink,mark(uv,scale)*taper*cut);
        }{int i=14;
          float t=float(i)/16.0;
          vec2 uv=vUv-direction/scale*(reach*t);
          float taper=1.0-t*(.35+.4*fine);
          float cut=step(.3*(1.0-inkDensity),group);
          ink=max(ink,mark(uv,scale)*taper*cut);
        }{int i=15;
          float t=float(i)/16.0;
          vec2 uv=vUv-direction/scale*(reach*t);
          float taper=1.0-t*(.35+.4*fine);
          float cut=step(.3*(1.0-inkDensity),group);
          ink=max(ink,mark(uv,scale)*taper*cut);
        }{int i=16;
          float t=float(i)/16.0;
          vec2 uv=vUv-direction/scale*(reach*t);
          float taper=1.0-t*(.35+.4*fine);
          float cut=step(.3*(1.0-inkDensity),group);
          ink=max(ink,mark(uv,scale)*taper*cut);
        }}
        // A solid subject is never eroded by the brush pattern.
        ink=max(body,smoothstep(.18,.66,ink));
        if(frame>5.5&&frame<6.5){
          vec2 px=1.2/max(resolution,vec2(1.0));
          float gx=mark(vUv+vec2(px.x,0.0),scale)-mark(vUv-vec2(px.x,0.0),scale);
          float gy=mark(vUv+vec2(0.0,px.y),scale)-mark(vUv-vec2(0.0,px.y),scale);
          ink=smoothstep(.12,.7,length(vec2(gx,gy)))*.32;
        }
        if(starStrength>0.0){for(int i=0;i<4;i++){
          if(stars[i].z>0.0){
            bool hitStar=frame>5.5&&frame<6.5;
            vec2 anchor=hitStar?center*scale:clamp(center*scale+stars[i].xy,vec2(.08),scale-vec2(.08));
            vec2 p=vUv*scale-anchor;
            float span=stars[i].z*starSize,phase=float(i)+frame*3.0;
            // Dark authored stars have a broader ink body; inversion alone
            // still complements exactly. Release keeps its own compact profile.
            float inkWeight=frame>.5&&frame<1.5&&i==0?1.0:0.0;
            float bodyWeight=hitStar?.8:reverseStars[i]>.5?2.2:mix(1.7,1.0,smoothstep(.45,1.25,stars[i].z));
            float star=fourPoint(p/vec2(max(stars[i].w,.1),1.0),span,phase,inkWeight,bodyWeight);
            // An opposite-color star needs its own ink surround to read on paper.
            // This local cutout is independent of the global frame inversion.
            float composed=reverseStars[i]>.5?mix(max(ink,starInkPatch(p,span,phase)),0.0,star):max(ink,star);
            // The hit marker is deliberately on the subject, so let it remain
            // visible there; only decorative stars avoid covering the subject.
            ink=mix(ink,composed,starStrength*(hitStar?1.0:1.0-body));
          }
        }}
        float paper=1.0-clamp(ink,0.0,1.0);
        float bw=mix(paper,1.0-paper,inverted);
        out_color=vec4(mix(source.rgb,vec3(bw),intensity),source.a);
      }
    

void fragment(){vec4 out_color=vec4(0.0);source_fragment(out_color);COLOR=out_color;}
