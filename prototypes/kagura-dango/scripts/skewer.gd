extends Node2D
## One generated dango sprite in flight, on a serving plate, or being eaten.

const TRI_PATH := "res://assets/sprites/dango_props_0.png"
const BIG_PATH := "res://assets/sprites/dango_props_1.png"
const DROPPED_PATH := "res://assets/sprites/dango_props_3.png"
const FLAVOR_PATHS := {
	&"anko": "res://assets/sprites/dango_flavors_0.png",
	&"soy": "res://assets/sprites/dango_flavors_1.png",
	&"rice": "res://assets/sprites/rice_bowl.png",
	&"bento": "res://assets/sprites/bento_box.png",
}

var flavor: StringName = &"tri"
var from := Vector2.ZERO
var to := Vector2.ZERO
var t0 := 0.0
var t1 := 1.0
var height := 120.0
var big := false
var state: StringName = &"flying"  # flying, eaten, dropped

@onready var _sprite: Sprite2D = %Sprite


func _ready() -> void:
	var path: String = BIG_PATH if big else FLAVOR_PATHS.get(flavor, TRI_PATH)
	if not ResourceLoader.exists(path):
		path = TRI_PATH
	_sprite.texture = load(path) as Texture2D


func place(t: float) -> void:
	if state != &"flying":
		return
	var u := clampf((t - t0) / maxf(0.001, t1 - t0), 0.0, 1.0)
	position = from.lerp(to, u) + Vector2(0, -height * 4.0 * u * (1.0 - u))
	rotation = lerpf(-0.6, 0.6, u)


func eat() -> void:
	_eat_at(position)


func serve_eat(target: Vector2) -> void:
	_eat_at(target)


func _eat_at(target: Vector2) -> void:
	state = &"eaten"
	var tw := create_tween()
	tw.tween_property(self, "position", target, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "scale", Vector2(0.2, 0.2), 0.14)
	tw.tween_callback(queue_free)


func drop() -> void:
	state = &"dropped"
	_sprite.texture = load(DROPPED_PATH) as Texture2D
	var tw := create_tween()
	tw.tween_property(self, "position", position + Vector2(30, 70), 0.35).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "rotation", rotation + 2.0, 0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
