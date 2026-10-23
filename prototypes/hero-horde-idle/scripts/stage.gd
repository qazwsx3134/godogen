extends "res://addons/proto_kit/hd2d_stage.gd"
## The HD-2D diorama around the push (godot-kit hd2d_stage): dusk environment and grading, the sun and its shadows,
## the floor, the cliffs and props, drifting motes, the vignette, all static in stage.tscn. The kit base tints the
## sprites by the lights around them (sprite_light) and flickers the braziers; this adds the lights that follow the
## fight: the telegraph glow under the warned zones and the volley flash.

const PushSim = preload("res://domain/push_sim.gd")

@export var telegraph_energy: float = 2.2
@export var volley_energy: float = 5.0
@export var volley_decay: float = 3.0

@onready var _telegraph_lights: Array[Node] = %TelegraphLights.get_children()
@onready var _volley_light: OmniLight3D = %VolleyLight

var _volley: float = 0.0


func _ready() -> void:
	super()
	for light: Node in _telegraph_lights:
		(light as OmniLight3D).visible = false
	_volley_light.visible = false


func _flicker_nodes() -> Array[Node]:
	return %BrazierLights.get_children()


func reset() -> void:
	_volley = 0.0


## Red glow under every telegraph shape, rising over the countdown; the volley flash fading out; braziers flickering.
func step(sim: PushSim, dt: float) -> void:
	step_lights(dt)
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


func flash_volley(at: Vector3) -> void:
	_volley_light.global_position = at
	_volley = 1.0
