extends RefCounted
## Scene photo treatment from the approved UI options. The wash affects the photo only.
const PHOTO_SHADER: String = """
shader_type canvas_item;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
uniform int style_index = 0;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 rgb = source.rgb;
	vec3 wash;
	float alpha;
	if (style_index == 1) {
		vec3 sepia = vec3(dot(rgb, vec3(.393,.769,.189)), dot(rgb,vec3(.349,.686,.168)), dot(rgb,vec3(.272,.534,.131)));
		rgb = mix(rgb, clamp(sepia,0.0,1.0), .2);
		float gray = dot(rgb,vec3(.2126,.7152,.0722));
		rgb = mix(vec3(gray),rgb,.82)*.78;
		wash = vec3(77.0,46.0,28.0)/255.0;
		if (SCREEN_UV.y < .32) { alpha = mix(.42,.03,SCREEN_UV.y/.32); }
		else if (SCREEN_UV.y < .49) { alpha = mix(.03,.08,(SCREEN_UV.y-.32)/.17); }
		else if (SCREEN_UV.y < .76) { alpha = mix(.08,.36,(SCREEN_UV.y-.49)/.27); }
		else { alpha = mix(.36,.26,(SCREEN_UV.y-.76)/.24); }
	} else if (style_index == 2) {
		float gray = dot(rgb,vec3(.2126,.7152,.0722));
		rgb = ((vec3(gray)-.5)*.91+.5)*.8;
		wash = vec3(15.0,15.0,14.0)/255.0;
		if (SCREEN_UV.y < .30) { alpha = mix(.42,.03,SCREEN_UV.y/.30); }
		else if (SCREEN_UV.y < .49) { alpha = mix(.03,.08,(SCREEN_UV.y-.30)/.19); }
		else if (SCREEN_UV.y < .74) { alpha = mix(.08,.32,(SCREEN_UV.y-.49)/.25); }
		else { alpha = mix(.32,.22,(SCREEN_UV.y-.74)/.26); }
	} else {
		float gray = dot(rgb,vec3(.2126,.7152,.0722));
		rgb = mix(vec3(gray),rgb,.78)*.75;
		wash = vec3(7.0,16.0,26.0)/255.0;
		if (SCREEN_UV.y < .31) { alpha = mix(.5,.03,SCREEN_UV.y/.31); }
		else if (SCREEN_UV.y < .48) { alpha = mix(.03,.04,(SCREEN_UV.y-.31)/.17); }
		else if (SCREEN_UV.y < .70) { alpha = mix(.04,.38,(SCREEN_UV.y-.48)/.22); }
		else { alpha = mix(.38,.28,(SCREEN_UV.y-.70)/.30); }
	}
	COLOR = vec4(mix(rgb,wash,alpha),source.a) * vertex_tint;
}
"""

static func apply(photo: TextureRect, style_id: String) -> void:
	var shader_material: ShaderMaterial = photo.material as ShaderMaterial
	if shader_material == null:
		var shader: Shader = Shader.new()
		shader.code = PHOTO_SHADER
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		photo.material = shader_material
	shader_material.set_shader_parameter("style_index", {"cinema": 0, "ledger": 1, "manga": 2, "gintama": 0}.get(style_id, 0))
