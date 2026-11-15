extends Node3D
## A reusable visual Boss: its root is positioned by the scene, while its imported
## skeleton plays the in-place idle, fly and fire clips.

@export_enum("idle", "fly") var initial_animation: String = "idle"
@onready var _model: Node3D = %Model
var _anim: AnimationPlayer
var _locomotion: StringName = &"idle"


func _ready() -> void:
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		push_error("Boss model is missing its AnimationPlayer")
		return
	_locomotion = &"fly" if initial_animation == "fly" else &"idle"
	_anim.animation_finished.connect(_on_animation_finished)
	_anim.play(_locomotion)


## Switch the in-place movement cycle. During a shot, the new choice is queued.
func set_flying(flying: bool) -> void:
	_locomotion = &"fly" if flying else &"idle"
	if _anim != null and _anim.current_animation != &"fire" and _anim.current_animation != _locomotion:
		_anim.play(_locomotion, 0.15)


## The clip is visual only; a future attack system can spawn its projectile.
func fire() -> bool:
	if _anim == null or (_anim.current_animation == &"fire" and _anim.is_playing()):
		return false
	_anim.play(&"fire", 0.1)
	return true


func _on_animation_finished(animation: StringName) -> void:
	if animation == &"fire":
		_anim.play(_locomotion, 0.15)
