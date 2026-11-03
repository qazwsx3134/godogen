@tool
extends Node2D
## Shared sprite actor. Hand and Mouth stay as editable scene markers while poses swap generated textures.

const SPRITES := {
	&"gintoki": {
		&"idle": ["res://assets/sprites/gintoki_idle_0.png", "res://assets/sprites/gintoki_idle_1.png"],
		&"wait": ["res://assets/sprites/gintoki_eat_0.png"],
		&"eat": ["res://assets/sprites/gintoki_eat_1.png"],
		&"throw": ["res://assets/sprites/gintoki_toss_0.png", "res://assets/sprites/gintoki_toss_1.png", "res://assets/sprites/gintoki_toss_2.png"],
		&"full": ["res://assets/sprites/gintoki_full.png"],
		&"kick": ["res://assets/sprites/gintoki_kick_0.png", "res://assets/sprites/gintoki_kick_1.png", "res://assets/sprites/gintoki_kick_2.png"],
		&"dart": ["res://assets/sprites/gintoki_dart_0.png", "res://assets/sprites/gintoki_dart_1.png"],
		&"fat": ["res://assets/sprites/gintoki_dart_0.png"],
	},
	&"shinpachi": {
		&"idle": ["res://assets/sprites/shinpachi_cheer_0.png", "res://assets/sprites/shinpachi_cheer_1.png"],
		&"wait": ["res://assets/sprites/shinpachi_eat_0.png"],
		&"eat": ["res://assets/sprites/shinpachi_eat_1.png"],
		&"miss": ["res://assets/sprites/shinpachi_shock.png"],
		&"full": ["res://assets/sprites/shinpachi_full.png"],
		&"pack": ["res://assets/sprites/shinpachi_bento_0.png", "res://assets/sprites/shinpachi_bento_1.png", "res://assets/sprites/shinpachi_bento_2.png"],
		&"dart": ["res://assets/sprites/shinpachi_dart_0.png", "res://assets/sprites/shinpachi_dart_1.png"],
		&"fat": ["res://assets/sprites/shinpachi_dart_0.png"],
	},
	&"kagura": {},
	&"referee": {
		&"idle": ["res://assets/sprites/referee_ref.png"],
		&"start": ["res://assets/sprites/referee_call_0.png"],
		&"stop": ["res://assets/sprites/referee_call_1.png"],
	},
	&"rival_man": {
		&"idle": ["res://assets/sprites/rival_team_0.png"],
		&"eat": ["res://assets/sprites/rival_team_1.png"],
	},
	&"rival_woman": {
		&"idle": ["res://assets/sprites/rival_team_2.png"],
		&"eat": ["res://assets/sprites/rival_team_3.png"],
	},
}

@export var character_id: StringName = &"gintoki":
	set(value):
		character_id = value
		_apply()
@export var flip_sprite_h := false:
	set(value):
		flip_sprite_h = value
		_apply()
## 1 = normal; Kagura changes sprite set at 1.14 (round 2) and 1.73 (halfway through round 3), see tier().
## Mouth remains a separate marker.
@export var girth := 1.0:
	set(value):
		girth = value
		_apply()
@export_range(0.0, 1.0) var fullness := 0.0:
	set(value):
		fullness = value
		_apply()
## Round 3: Gintoki and Shinpachi have eaten themselves fat; they idle in their fat dart pose.
@export var fat := false:
	set(value):
		fat = value
		_apply()

var _base_scale := Vector2.ONE
var _pose: StringName = &"idle"
var _pose_token := 0
var _frame_index := 0
var _frame_elapsed := 0.0

@onready var _sprite: Sprite2D = %Sprite


func _ready() -> void:
	_base_scale = scale  # the Sprite's size and offset stay as set in actor.tscn; only its texture changes
	_apply()


func _process(delta: float) -> void:
	if _pose != &"idle":
		return
	var paths := _paths_for_pose()
	if paths.size() < 2:
		return
	_frame_elapsed += delta
	if _frame_elapsed >= 0.42:
		_frame_elapsed = 0.0
		_frame_index = (_frame_index + 1) % paths.size()
		_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	_sprite.flip_h = flip_sprite_h
	var paths := _paths_for_pose()
	if not paths.is_empty():
		_frame_index = clampi(_frame_index, 0, paths.size() - 1)
		_sprite.texture = load(paths[_frame_index]) as Texture2D


func _paths_for_pose() -> Array:
	if character_id == &"kagura":
		if _pose == &"full":
			return ["res://assets/sprites/kagura_full.png"]
		if _pose == &"eye":
			return ["res://assets/sprites/kagura_eye_hit.png"]
		if _pose == &"rice":
			return ["res://assets/sprites/kagura_rice.png"]
		if _pose in [&"miss", &"eye"]:
			return ["res://assets/sprites/kagura_miss.png"]
		var tier := tier()
		if _pose == &"eat":
			if tier == 1:
				return ["res://assets/sprites/kagura_chomp_0.png", "res://assets/sprites/kagura_chomp_1.png"]
			return ["res://assets/sprites/kagura_tier%d_2.png" % tier, "res://assets/sprites/kagura_tier%d_3.png" % tier]
		if tier == 1:
			return ["res://assets/sprites/kagura_ready_0.png", "res://assets/sprites/kagura_ready_1.png"]
		return ["res://assets/sprites/kagura_tier%d_0.png" % tier, "res://assets/sprites/kagura_tier%d_1.png" % tier]
	var character: Dictionary = SPRITES.get(character_id, SPRITES[&"gintoki"])
	var resting := _pose in [&"idle", &"wait", &"eat"]
	if fat and resting:
		return character[&"fat"]
	if character_id in [&"gintoki", &"shinpachi"] and fullness >= 1.0 and resting:
		return character[&"full"]
	var pose := _pose
	if not character.has(pose) or not ResourceLoader.exists(character[pose][0]):
		pose = &"idle"
	return character[pose]


## Kagura's body: 1 slim, 2 round (from girth 1.14, during round 2), 3 roundest (from 1.73: round 3 opens with
## her round 2 body and she grows into this one halfway through).
func tier() -> int:
	if girth >= 1.73:
		return 3
	if girth >= 1.14:
		return 2
	return 1


## Show a reaction, then return to the current idle/fullness pose. Throw uses its three generated frames in order.
func play_pose(pose: StringName, duration := 0.34) -> void:
	_pose = pose
	_pose_token += 1
	var token := _pose_token
	_frame_index = 0
	_frame_elapsed = 0.0
	_apply()
	var paths := _paths_for_pose()
	if pose in [&"throw", &"eat", &"kick", &"pack", &"dart"] and paths.size() > 1:
		var step_duration := duration / paths.size()
		for index in paths.size():
			_frame_index = index
			_apply()
			await get_tree().create_timer(step_duration, true, false, true).timeout
			if token != _pose_token:
				return
	else:
		await get_tree().create_timer(duration, true, false, true).timeout
	if token == _pose_token:
		_pose = &"idle"
		_frame_index = 0
		_apply()


## A quick squash, e.g. a chomp or a throw.
func bump(amount := 0.12, time := 0.12) -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", _base_scale * Vector2(1.0 + amount, 1.0 - amount), time * 0.4)
	tw.tween_property(self, "scale", _base_scale, time * 0.6)
