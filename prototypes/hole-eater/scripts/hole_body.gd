class_name HoleBody
extends RigidBody3D
## 會移動的洞。本體在第 5 層（hole）、mask 0、重力 0、kinematic freeze：只被我們移動，不被推。
## 子 node：
##   HoleMask（CSGCylinder3D，stencil write）在地板上挖出可見的洞
##   Pit（CSGCylinder3D，cull front）洞的內壁與底
##   Lip＋LipShape*／Ground*：帶洞的第二層地面碰撞，跟著洞走
##   Catch（Area3D）：物體進入 → collision_mask 換成 hole_flags（不再碰地板，只碰帶洞地面）
##   Kill（Area3D）：洞底，碰到的物體刪掉並計分

signal ate(body: RigidBody3D)

@export_flags_3d_physics var normal_flags := 0b00011   ## 地板＋道具
@export_flags_3d_physics var hole_flags := 0b10010     ## 帶洞地面＋道具
@export var follow_speed := 14.0
@export var max_speed := 8.0  ## m/s；太快時洞緣會把上面的物體鏟飛
@export var arena_half := 18.0
@export var grow_per_eat := 0.08  ## 每吃一個，整個洞（含碰撞）等比放大這麼多
@export var max_scale := 3.0
@export var eat_sound: AudioStream = preload("res://assets/sfx/eat.ogg")
@export var grow_sound: AudioStream = preload("res://assets/sfx/grow.ogg")
@export var grow_every := 5  ## 每吃幾個放一次變大音效

var eaten := 0
## 洞的倍率。RigidBody 自己的 scale 會被物理重設，所以改為等比縮放每個子 node（含位置）
var size := 1.0:
	set(v):
		size = v
		for c in _base:
			c.transform = Transform3D(_base[c].basis.scaled(Vector3.ONE * v), _base[c].origin * v)
var _base := {}
var target := Vector3.ZERO


func _ready() -> void:
	%Catch.body_entered.connect(_on_catch_enter)
	%Catch.body_exited.connect(_on_catch_exit)
	%Kill.body_entered.connect(_on_kill)
	target = global_position
	for c in get_children():
		if c is Node3D:
			_base[c] = c.transform


func _physics_process(delta: float) -> void:
	var p := global_position
	var t := Vector3(clampf(target.x, -arena_half, arena_half), p.y, clampf(target.z, -arena_half, arena_half))
	var step := (t - p) * (1.0 - exp(-follow_speed * delta))
	global_position = p + step.limit_length(max_speed * delta)


func _on_catch_enter(body: Node3D) -> void:
	if body is RigidBody3D:
		body.collision_mask = hole_flags
		body.sleeping = false  # 靜止的物體要醒來才會掉


func _on_catch_exit(body: Node3D) -> void:
	if body is RigidBody3D and is_instance_valid(body):
		body.collision_mask = normal_flags


func _on_kill(body: Node3D) -> void:
	if body is RigidBody3D and not body.is_queued_for_deletion():
		eaten += 1
		ate.emit(body)
		body.queue_free()
		_grow()


func _grow() -> void:
	var s := minf(size + grow_per_eat, max_scale)
	create_tween().tween_property(self, "size", s, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sfx(eat_sound, 1.0 / sqrt(s))  # 洞越大，吞的聲音越低沉
	if eaten % grow_every == 0:
		_sfx(grow_sound, 1.0)


func _sfx(stream: AudioStream, pitch: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.pitch_scale = pitch * randf_range(0.92, 1.08)
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()
