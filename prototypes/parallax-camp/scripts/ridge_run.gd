extends Node2D

const CameraRig = preload("res://scripts/camera_rig.gd")

@export var fall_limit := 365.0

@onready var _player: CharacterBody2D = %Player
@onready var _rig: CameraRig = %CameraRig
@onready var _sfx = %Sfx
@onready var _start: Marker2D = %Start
@onready var _checkpoint: Area2D = %Checkpoint
@onready var _finish: Area2D = %Finish
@onready var _progress: ProgressBar = %CourseProgress
@onready var _status: Label = %CourseStatus

var _spawn: Marker2D
var _complete := false


func _ready() -> void:
	_player.sound_requested.connect(_sfx.play)
	_player.landed.connect(_rig.on_landed)
	_checkpoint.body_entered.connect(_on_checkpoint)
	_finish.body_entered.connect(_on_finish)
	_rig.follow(_player)
	_restart()


func _physics_process(_delta: float) -> void:
	if _player.global_position.y > fall_limit:
		_respawn()
	if not _complete:
		_progress.value = clampf(inverse_lerp(_start.global_position.x, _finish.global_position.x, _player.global_position.x), 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart_course"):
		_restart()


func _on_checkpoint(body: Node2D) -> void:
	if body != _player or _spawn != _start:
		return
	_spawn = _checkpoint.get_node("Spawn")
	if not _complete:
		_status.text = "Checkpoint saved"
	_sfx.play(&"inspect")


func _on_finish(body: Node2D) -> void:
	if body != _player or _complete:
		return
	_complete = true
	_progress.value = 1.0
	_status.text = "Trail clear   R  Retry"
	_sfx.play(&"inspect")


func _restart() -> void:
	_spawn = _start
	_complete = false
	_progress.value = 0.0
	_status.text = "Reach the far flag"
	_respawn()


func _respawn() -> void:
	_player.respawn_at(_spawn.global_position)
	_rig.reset_to_target()
