class_name Ultimate
extends Node3D
## Conqueror's Haki, Luffy's ultimate (docs/one-piece-marineford/README.md 霸王色的規則): a held breath while the
## camera pulls back and the air ripples, then one wave: every common Marine within `radius` faints on the spot
## (a kill, XP dropped, no launch), elites are only shoved back, bosses and named targets are untouched.
## Unlocked by the story (act 4) or QA learn=haki; fired from the ultimate button when the will meter is full, or
## by the story beat itself. Runs on game time; main keeps the player invulnerable while it plays.
## Its kills give no will (main): otherwise one wave would refill the meter.

signal started
## The wave landed: `count` fainted. (The name stays from the shared ultimate interface.)
signal crushed(count: int, at: Vector3)

@export var horde: Horde
@export var fx: Fx
@export var rig: CameraRig
@export var radius: float = 26.0
@export var build_time: float = 0.8
@export var elite_push: float = 4.0
@export var zoom_out: float = 1.35
@export var color: Color = Color(1.0, 0.82, 0.42)

var learned: bool = false
## How many fainted in the last wave (main reads it to skip will gains for them).
var last_fainted: int = 0

enum Phase { IDLE, BUILD }
var phase: Phase = Phase.IDLE
var _t: float = 0.0
var _at := Vector3.ZERO
var _ripple: float = 0.0

@onready var _core: MeshInstance3D = %Core


func _ready() -> void:
	_core.visible = false


func active() -> bool:
	return phase != Phase.IDLE


func fire(at: Vector3) -> void:
	phase = Phase.BUILD
	_t = 0.0
	_ripple = 0.0
	_at = at
	rig.zoom_to(zoom_out)
	started.emit()


func step(dt: float) -> void:
	if phase != Phase.BUILD:
		return
	_t += dt
	_ripple -= dt
	if _ripple <= 0.0:
		_ripple = 0.2
		fx.ring(_at + Vector3(0, 0.4, 0), lerpf(3.0, 9.0, _t / build_time), color, 0.25)
	if _t < build_time:
		return
	var result: Dictionary = horde.haki_wave(Vector2(_at.x, _at.z), radius, elite_push)
	last_fainted = result.fainted
	phase = Phase.IDLE
	rig.zoom_to(1.0)
	fx.flash(_at + Vector3(0, 1.5, 0), 10.0, Color(1.0, 0.95, 0.85))
	fx.ring(_at + Vector3(0, 0.3, 0), radius * 2.0, color, 0.6)
	fx.ring(_at + Vector3(0, 0.6, 0), radius * 1.2, Color(0.95, 0.4, 0.95), 0.45)
	crushed.emit(last_fainted, _at)
