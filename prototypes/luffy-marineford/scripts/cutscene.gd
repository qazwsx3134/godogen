@tool
class_name Cutscene
extends Node3D
## A cutscene scene (scenes/cutscenes/*.tscn), placed in world coordinates on the route:
##   Shot        Camera3D: never made current; the game camera copies its pose and FOV every frame
##   Anim        AnimationPlayer: `animation` moves Shot and the actors and, through method tracks, calls say(),
##               shake(), flash() on this node
##   Reference   (optional) editor-only context such as a route instance; freed at run time
##   actors      cast_actor.tscn instances
## A cutscene only shows things: whatever changes the game (unlocks, enemies knocked down) is a Beat after it, so
## skipping never skips a rule.

signal line(speaker: String, text: String, seconds: float)
signal effect(kind: StringName, amount: float)
signal ended

@export var animation: StringName = &"main"
## Real seconds the game camera takes to ease back to the chase view afterwards.
@export var blend_out: float = 0.6

var _over: bool = false

@onready var shot: Camera3D = %Shot
@onready var anim: AnimationPlayer = %Anim


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var reference := get_node_or_null(^"Reference")
	if reference:
		reference.free()
	shot.current = false
	anim.animation_finished.connect(func(_name: StringName) -> void: _end())


func start() -> void:
	anim.play(animation)


func skip() -> void:
	anim.stop()
	_end()


func length() -> float:
	return anim.get_animation(animation).length if anim.has_animation(animation) else 0.0


func _end() -> void:
	if _over:
		return
	_over = true
	ended.emit()


## Method-track targets.
func say(speaker: String, text: String, seconds: float = 0.0) -> void:
	line.emit(speaker, text, seconds)


func shake(amount: float) -> void:
	effect.emit(&"shake", amount)


func flash(amount: float = 1.0) -> void:
	effect.emit(&"flash", amount)
