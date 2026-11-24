extends RefCounted
## The HD-2D look as resources: `const Hd2dLook = preload("res://addons/proto_kit/hd2d_look.gd")`. Call these from a
## headless authoring script and save the results (materials/stage_environment.tres, ...) so they are tuned in the
## editor afterwards; the defaults are hero-horde-idle's dusk stage, which the author approved.
##   environment()        background, cool ambient, linear tonemap (the pixel art keeps its painted palette; only
##                        HDR highlights such as motes, flashes and fire bloom), screen glow, depth fog that greys the
##                        far set, a slight lift in brightness, contrast and saturation
##   camera_attributes()  far depth of field: the near field stays sharp, the backdrop goes soft (the tilt-shift read)
##   vignette_material()  for a full-screen ColorRect between the 3D view and the HUD (hd2d_vignette.gdshader):
##                        cool dark corners and a faint warm wash from the top
## Overrides: environment({"fog_depth_begin": 12.0, "background_color": Color.BLACK}) sets any Environment property.
## Depth of field needs the Forward+ or Mobile renderer; Compatibility skips it (the stage then looks sharper).

const VIGNETTE := preload("res://addons/proto_kit/hd2d_vignette.gdshader")

const ENVIRONMENT := {
	"background_mode": Environment.BG_COLOR,
	"background_color": Color(0.18, 0.16, 0.24),
	"ambient_light_source": Environment.AMBIENT_SOURCE_COLOR,
	"ambient_light_color": Color(0.6, 0.64, 0.9),
	"ambient_light_energy": 0.85,
	"tonemap_mode": Environment.TONE_MAPPER_LINEAR,
	"glow_enabled": true,
	"glow_intensity": 0.5,
	"glow_strength": 1.0,
	"glow_bloom": 0.0,
	"glow_hdr_threshold": 1.05,
	"glow_blend_mode": Environment.GLOW_BLEND_MODE_SCREEN,
	"fog_enabled": true,
	"fog_mode": Environment.FOG_MODE_DEPTH,
	"fog_light_color": Color(0.78, 0.64, 0.62),
	"fog_density": 0.55,
	"fog_depth_begin": 17.0,
	"fog_depth_end": 34.0,
	"fog_sky_affect": 0.0,
	"adjustment_enabled": true,
	"adjustment_brightness": 1.06,
	"adjustment_contrast": 1.06,
	"adjustment_saturation": 1.12,
}

const CAMERA_ATTRIBUTES := {
	"dof_blur_far_enabled": true,
	"dof_blur_far_distance": 19.0,
	"dof_blur_far_transition": 6.0,
	"dof_blur_amount": 0.08,
}


static func environment(overrides: Dictionary = {}) -> Environment:
	var e := Environment.new()
	_set_all(e, ENVIRONMENT, overrides)
	return e


static func camera_attributes(overrides: Dictionary = {}) -> CameraAttributesPractical:
	var a := CameraAttributesPractical.new()
	_set_all(a, CAMERA_ATTRIBUTES, overrides)
	return a


## A ShaderMaterial of the vignette; `overrides` sets its uniforms (corner_color, strength, radius, softness,
## sun_wash, sun_wash_strength).
static func vignette_material(overrides: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = VIGNETTE
	for key: String in overrides:
		m.set_shader_parameter(key, overrides[key])
	return m


static func _set_all(target: Object, defaults: Dictionary, overrides: Dictionary) -> void:
	for key: String in defaults:
		target.set(key, overrides.get(key, defaults[key]))
	for key: String in overrides:
		if not defaults.has(key):
			if not key in target:
				push_error("hd2d_look: %s has no property %s" % [target.get_class(), key])
				continue
			target.set(key, overrides[key])
