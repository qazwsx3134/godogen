@tool
extends "res://scripts/cast_actor.gd"
## A story blocker (Garp on the bridge, Coby in the plaza): stands in the way, never fights back, and goes down after
## `hits_needed` strikes from Luffy's moves (jutsu.gd `targets`). Then it is knocked flying and `beaten` fires.
## Main keeps the player out of its circle while it stands.

signal beaten

@export var hits_needed: int = 6
@export var radius: float = 0.9
@export var hit_anim: StringName = &"hit"
@export var down_anim: StringName = &"knocked"
@export var fly_distance: float = 14.0

var hits_taken: int = 0
var _down: bool = false
var _recover: float = 0.0


func ground() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func is_down() -> bool:
	return _down


## A strike from Luffy. A burst (the Gatling) counts once per 0.15 s, so a blocker takes punches, not frames.
func take_strike(_amount: float, push: Vector2) -> void:
	if _down or _recover > 0.0:
		return
	_recover = 0.15
	hits_taken += 1
	flash = 1.0
	play(hit_anim, true)
	if hits_taken >= hits_needed:
		_knock(push)


func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	_recover = maxf(_recover - delta, 0.0)
	flash = maxf(flash - delta * 4.0, 0.0)


func _knock(push: Vector2) -> void:
	_down = true
	play(down_anim, true)
	var dir: Vector2 = push.normalized() if push.length() > 0.01 else Vector2(0.0, -1.0)
	var to: Vector3 = global_position + Vector3(dir.x, 0.0, dir.y) * fly_distance
	var tween := create_tween()
	tween.tween_property(self, "global_position", to + Vector3(0.0, 3.0, 0.0), 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", to, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: beaten.emit())
