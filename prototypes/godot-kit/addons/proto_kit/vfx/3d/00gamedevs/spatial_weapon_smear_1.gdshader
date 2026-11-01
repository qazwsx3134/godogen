// 00GameDevs MIT 2026 @00vchannel; original weapon-smear GLSL.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_add;
#define SMEAR_LAYER 1
varying vec2 vUv;varying float vAge;
void vertex(){vUv=UV;vAge=UV2.x;}
uniform vec4 uColor : source_color = vec4(0.157,0.47,1.0,1.0);uniform float uDetail = 1.0;uniform float uDensity = 0.5;
    void fragment(){float age=clamp(vAge,0.0,1.0),y=vUv.y;float fade=pow(1.0-age,1.35);float alpha;vec3 color=uColor.rgb;
    #if SMEAR_LAYER == 0
      float lines=0.0;for(int i=0;i<8;i++){float f=float(i);float center=.12+f*.105;float aa=max(fwidth(y),.002);lines+=(1.0-smoothstep(.005,.005+aa,abs(y-center)))*step(f+.5,uDensity*8.0);}
      // Make the fresh leading face readable across the blade, not just at its tip.
      // Retain the actual weapon endpoints and the existing width control.
      float head=1.0-smoothstep(0.0,.28,age);
      float body=mix(.12+.35*y,.42+.12*y,head);
      alpha=(body+lines*.13*uDetail)*smoothstep(0.0,.08,y)*fade;
    #elif SMEAR_LAYER == 1
      alpha=exp(-pow((1.0-y)*7.5,2.0))*.48*uDetail*fade;
    #else
      float aa=max(fwidth(y),.002);alpha=(1.0-smoothstep(.01,.022+aa,1.0-y))*.95*fade;color=mix(uColor.rgb,vec3(.86,1.,1.),.8);
    #endif
    if(alpha<.002)discard;ALBEDO=color;ALPHA=alpha;
    
    
    }
