extends Node3D
## The HD-2D diorama around the push: dusk environment and grading, the sun and its shadows, the floor, the cliffs
## and props, drifting motes, the vignette. Everything static lives in stage.tscn; this script only drives the
## lights that follow the fight (telegraph glow under the warned zones, the volley flash, flickering braziers) and
## tells the sprites how lit they are: the hero and boss sprites are unshaded pixel art (a lit flat card reads as
## cardboard), so sprite_light() adds the nearby coloured lights to their tint instead.

const PushSim = preload("res://domain/push_sim.gd")

## The sprites' base light: the warm key the pixel art is painted for.
@export var sprite_key := Color(0.97, 0.93, 0.86)
## How strongly an omni light's colour adds to a sprite standing in it (at the light's centre, energy 1).
@export var sprite_light_gain: float = 0.45
@export var telegraph_energy: float = 2.2
@export var volley_energy: float = 5.0
@export var volley_decay: float = 3.0
@export var brazier_flicker: float = 0.22

@onready var _telegraph_lights: Array[Node] = %TelegraphLights.get_children()
@onready var _volley_light: OmniLight3D = %VolleyLight
@onready var _braziers: Array[Node] = %BrazierLights.get_children()

var _lights: Array[OmniLight3D] = []
var _brazier_base: PackedFloat32Array = []
var _time: float = 0.0
var _volley: float = 0.0


func _ready() -> void:
	for light: Node in find_children("*", "OmniLight3D", true, false):
		_lights.append(light as OmniLight3D)
	for b: Node in _braziers:
		_brazier_base.append((b as OmniLight3D).light_energy)
	for light: Node in _telegraph_lights:
		(light as OmniLight3D).visible = false
	_volley_light.visible = false


func reset() -> void:
	_volley = 0.0


## Red glow under every telegraph shape, rising over the countdown; the volley flash fading out; braziers flickering.
func step(sim: PushSim, dt: float) -> void:
	_time += dt
	var warn: float = 0.0
	if sim.tele_t > 0.0:
		warn = clampf(1.0 - sim.tele_t / PushSim.TELE_WARN, 0.0, 1.0)
	var pulse: float = 0.75 + 0.25 * sin(_time * 20.0)
	for k: int in _telegraph_lights.size():
		var light := _telegraph_lights[k] as OmniLight3D
		var on: bool = sim.tele_t > 0.0 and k < sim.tele_shapes.size()
		light.visible = on
		if on:
			var c: Vector2 = PushSim.shape_center(sim.tele_shapes[k])
			light.position = Vector3(c.x, light.position.y, c.y)
			light.light_energy = telegraph_energy * (0.35 + 0.65 * warn) * pulse
	_volley = maxf(_volley - dt * volley_decay, 0.0)
	_volley_light.visible = _volley > 0.0
	_volley_light.light_energy = volley_energy * _volley
	for k: int in _braziers.size():
		var flicker: float = 1.0 + brazier_flicker * (sin(_time * 11.0 + k * 2.1) * 0.6 + sin(_time * 23.0 + k) * 0.4)
		(_braziers[k] as OmniLight3D).light_energy = _brazier_base[k] * flicker


func flash_volley(at: Vector3) -> void:
	_volley_light.global_position = at
	_volley = 1.0


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
	c.a = 1.0
	return c
