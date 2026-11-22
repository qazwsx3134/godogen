extends Node3D
## The root of an HD-2D diorama (Octopath / RO style: pixel-art sprites and cards in a lit 3D set). Everything static
## lives in the stage scene: WorldEnvironment (hd2d_look.gd presets), the sun, the floor, cliffs, pixel_card3d props,
## omni lights, the vignette. This script does the two things a scene file cannot:
##   sprite_light(p)  the tint for a sprite standing at p. Character sprites are unshaded pixel art (a lit flat card
##                    reads as cardboard), so the coloured lights around them are added to their tint instead: the
##                    key colour plus every visible OmniLight3D reaching p (quadratic falloff), times the region light.
##   step_lights(dt)  flickers the lights under %FlickerLights (braziers, torches) on its own clock.
## set_region_light(c) recolours the sun (%Sun) and the sprites together, for one stage reused across regions.
##   extends "res://addons/proto_kit/hd2d_stage.gd"       # the game adds its own event lights (warnings, flashes)
##   army.lighting = stage.sprite_light                   # sprite3d crowd: multiply each instance colour by it
## Omni lights are collected once in _ready: add lights to the scene, not at runtime.

## The sprites' base light: the warm key the pixel art is painted for.
@export var sprite_key := Color(0.97, 0.93, 0.86)
## How strongly an omni light's colour adds to a sprite standing in it (at the light's centre, energy 1).
@export var sprite_light_gain: float = 0.45
## Flicker depth of the %FlickerLights (0 = steady).
@export var flicker_amount: float = 0.22

var _lights: Array[OmniLight3D] = []
var _flicker: Array[Node] = []
var _flicker_base: PackedFloat32Array = []
var _time: float = 0.0
var _sun: DirectionalLight3D
var _sun_base := Color.WHITE
## The region's light: multiplies the sun and the sprites' light.
var _region := Color.WHITE


func _ready() -> void:
	for light: Node in find_children("*", "OmniLight3D", true, false):
		_lights.append(light as OmniLight3D)
	_flicker = _flicker_nodes()
	for b: Node in _flicker:
		_flicker_base.append((b as OmniLight3D).light_energy)
	_sun = get_node_or_null(^"%Sun") as DirectionalLight3D
	if _sun != null:
		_sun_base = _sun.light_color


## The lights that flicker: the children of %FlickerLights (override to name another group).
func _flicker_nodes() -> Array[Node]:
	var group: Node = get_node_or_null(^"%FlickerLights")
	return group.get_children() if group != null else ([] as Array[Node])


## The stage's region light; white is the light the stage is built for.
func set_region_light(color: Color) -> void:
	_region = color
	if _sun != null:
		_sun.light_color = _sun_base * color


## Advances the stage clock and flickers the flicker lights. Call it every frame with game time.
func step_lights(dt: float) -> void:
	_time += dt
	for k: int in _flicker.size():
		var flicker: float = 1.0 + flicker_amount * (sin(_time * 11.0 + k * 2.1) * 0.6 + sin(_time * 23.0 + k) * 0.4)
		(_flicker[k] as OmniLight3D).light_energy = _flicker_base[k] * flicker


## Tint multiplier for a sprite at world point `p`: the key plus every visible omni light reaching it.
func sprite_light(p: Vector3) -> Color:
	var c: Color = sprite_key
	for light: OmniLight3D in _lights:
		if not light.visible or light.light_energy <= 0.0:
			continue
		var d: float = light.global_position.distance_to(p)
		if d >= light.omni_range:
			continue
		var k: float = 1.0 - d / light.omni_range
		c += light.light_color * (k * k * light.light_energy * sprite_light_gain)
	c *= _region
	c.a = 1.0
	return c
