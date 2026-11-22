shader_type spatial;
#include "res://addons/proto_kit/vat_crowd.gdshaderinc"

uniform sampler2D albedo_map : source_color, hint_default_white;
uniform sampler2D marking_map : source_color, hint_default_black;
uniform vec4 armor_color : source_color = vec4(1.0);
uniform float metallic : hint_range(0, 1) = 0.5;
uniform float roughness : hint_range(0, 1) = 0.65;
uniform float idle_seconds = 1.0;
uniform float run_seconds = 1.0;

void vertex() {
	float duration = INSTANCE_CUSTOM.y == 0.0 ? idle_seconds : run_seconds;
	vat_pose(VERTEX_ID, INSTANCE_CUSTOM, TIME / max(duration, 0.001), VERTEX, NORMAL);
	vat_hit = INSTANCE_CUSTOM.w;
}

void fragment() {
	ALBEDO = texture(albedo_map, UV).rgb * armor_color.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = texture(marking_map, UV).rgb + vec3(1.0, 0.37, 0.11) * vat_hit;
}
