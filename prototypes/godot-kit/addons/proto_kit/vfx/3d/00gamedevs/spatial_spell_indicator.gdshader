// Port of 00GameDevs spell indicators, MIT (2026 @00vchannel).
// Original equations retained. Compatibility/Forward+, one draw and no texture reads.
// License: ../../licenses/00gamedevs-MIT.txt
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float effect_radius : hint_range(0.25, 20.0) = 3.0;
varying vec2 vPoint;
void vertex() { vPoint = VERTEX.xz; VERTEX.xz *= effect_radius; }

      uniform float uTime;
uniform float uProgress;
uniform float uHalfAngle;
uniform float uDetail;
uniform float uOpacity;
uniform float uFlash;
      uniform vec4 uColor : source_color = vec4(1.0, 0.188, 0.243, 1.0);
uniform vec4 uEdgeColor : source_color = vec4(1.0, 0.5, 0.5, 1.0);
      
      
      float rayDistance(vec2 p,vec2 direction){return length(p-direction*clamp(dot(p,direction),0.0,1.0));}
      void fragment(){
        vec2 p=vPoint;
        float radius=length(p);
        // Derivatives are evaluated for the whole quad before any discard.
        float aa=max(length(fwidth(p))*.65,.00015);
        float angle=atan(p.y,abs(p.x)+abs(p.y)<.000001?.000001:p.x);
        float boundary=1.0-radius;
        if(uHalfAngle<PI-.00001){
          vec2 ray=vec2(cos(uHalfAngle),sin(uHalfAngle));
          float side=min(rayDistance(p,ray),rayDistance(p,vec2(ray.x,-ray.y)));
          boundary=min(boundary,abs(angle)<=uHalfAngle?side:-side);
        }
        float coverage=smoothstep(-aa,aa,boundary);
        float edge=1.0-smoothstep(.007,.014+aa,boundary);
        float halo=1.0-smoothstep(.014,.075,boundary);
        float filled=(1.0-smoothstep(uProgress-aa,uProgress+aa,radius))*step(.000001,uProgress);
        float front=(1.0-smoothstep(.006,.020+aa,abs(radius-uProgress)))*step(.000001,uProgress)*(1.0-step(.99999,uProgress));
        // Sparse moving bands live inside the shape. They never displace a border.
        float wave=pow(.5+.5*sin(radius*28.0-angle*2.0-uTime*2.6),8.0);
        float flow=wave*(.35+.65*filled)*(.018*uDetail);
        float alpha=(.115+.19*filled+.12*halo+flow+.20*front+.54*edge)*coverage*uOpacity;
        vec3 color=uColor.rgb*(.65+.20*filled);
        color=mix(color,uEdgeColor.rgb,clamp(.30*halo+.75*edge+.44*front,0.0,1.0));
        color=mix(color,vec3(.055,.018,.023),.22*(1.0-edge)*halo);
        color=mix(color,mix(uEdgeColor.rgb,vec3(1.0),.35),uFlash*edge);
        alpha=min(1.0,alpha+uFlash*edge*.18*coverage*uOpacity);
        if(alpha<.001)discard;
        ALBEDO=color; ALPHA=alpha;
        
        
      }
