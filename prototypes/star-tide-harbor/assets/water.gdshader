shader_type canvas_item;
uniform float amplitude = 0.0018;
void fragment(){
    vec2 uv=UV;
    uv.x+=sin(uv.y*85.0+TIME*0.7)*amplitude;
    vec4 col=texture(TEXTURE,uv);
    float glimmer=pow(max(0.0,sin(uv.x*93.0+sin(uv.y*40.0+TIME)*2.0)),24.0);
    col.rgb+=vec3(0.14,0.16,0.09)*glimmer*0.2;
    COLOR=col;
}
