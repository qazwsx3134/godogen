class_name Ultimate
extends Node3D
## Chibaku Tensei, Madara's ultimate: a black core rises over the battlefield, every enemy within `radius` is torn off
## the ground and spirals up into it, then the core crushes them all at once and the bodies rain down.
## Learned on a late level-up card; fired from the ultimate button when Dominance is full (main checks both).
## Runs on game time; main keeps the player invulnerable while it plays.

signal started
signal crushed(count: int, at: Vector3)

@export var horde: Horde
@export var fx: Fx
@export var rig: CameraRig
@export var radius: float = 34.0
@export var core_height: float = 6.0
@export var gather_time: float = 1.7
@export var crush_time: float = 0.3
@export var damage: float = 5000.0
@export var zoom_out: float = 1.6

var learned: bool = false

enum Phase { IDLE, GATHER, CRUSH }
var phase: Phase = Phase.IDLE
var _t: float = 0.0
var _center := Vector2.ZERO
var _recapture: float = 0.0

@onready var _core: MeshInstance3D = %Core


func _ready() -> void:
	_core.visible = false


func active() -> bool:
	return phase != Phase.IDLE


func fire(at: Vector3) -> void:
	phase = Phase.GATHER
	_t = 0.0
	_center = Vector2(at.x, at.z)
	_core.global_position = Vector3(at.x, core_height, at.z + 1.0)
	_core.scale = Vector3.ONE * 0.4
	_core.visible = true
	horde.capture(_center, radius, _core.global_position)
	rig.zoom_to(zoom_out)
	started.emit()


func step(dt: float) -> void:
	match phase:
		Phase.GATHER:
			_t += dt
			var t: float = clampf(_t / gather_time, 0.0, 1.0)
			_core.scale = Vector3.ONE * lerpf(0.4, 3.6, t * t)
			_recapture -= dt
			if _recapture <= 0.0:
				# Stragglers walking in are caught too.
				_recapture = 0.25
				horde.capture(_center, radius, _core.global_position)
			if randf() < 0.6:
				var o: Vector2 = Vector2.from_angle(randf() * TAU) * randf_range(4.0, radius * 0.6)
				fx.dust(Vector3(_center.x + o.x, 0.3, _center.y + o.y), 1.6, Color(0.6, 0.45, 0.32, 0.7), Vector3(-o.x, 6.0, -o.y) * 0.3, 0.8)
			if _t >= gather_time:
				phase = Phase.CRUSH
				_t = 0.0
		Phase.CRUSH:
			_t += dt
			var t: float = clampf(_t / crush_time, 0.0, 1.0)
			_core.scale = Vector3.ONE * lerpf(3.6, 2.2, t)
			if _t >= crush_time:
				var count: int = horde.crush(damage)
				var at: Vector3 = _core.global_position
				_core.visible = false
				phase = Phase.IDLE
				rig.zoom_to(1.0)
				fx.flash(at, 14.0, Color(1.0, 0.95, 1.0))
				fx.ring(at, 26.0, Color(0.75, 0.5, 1.0), 0.6)
				crushed.emit(count, at)
