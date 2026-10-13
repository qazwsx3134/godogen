extends Node2D
## A mindless titan walking toward Erwin. Origin = feet on the ground line. Kinds differ in sheet, size and pace.

const KINDS := {
	&"tall": {"tex": preload("res://assets/sprites/titan_tall.png"), "walk": 22.0, "fps": 5.0, "w": 44.0, "h": 128.0},
	&"fat": {"tex": preload("res://assets/sprites/titan_fat.png"), "walk": 30.0, "fps": 7.0, "w": 56.0, "h": 84.0},
	&"runner": {"tex": preload("res://assets/sprites/titan_runner.png"), "walk": 120.0, "fps": 12.0, "w": 50.0, "h": 108.0},
}

@onready var sprite: Sprite2D = %Sprite

var kind: StringName = &"tall"
var dead := false
var hit_player := false
var t := 0.0
var walk := 0.0
var fps := 5.0
var half_w := 22.0
var height := 128.0


func setup(new_kind: StringName) -> void:
	kind = new_kind
	var k: Dictionary = KINDS[kind]
	sprite.texture = k.tex
	sprite.hframes = 4
	sprite.offset = Vector2(0.0, -k.tex.get_height() / 2.0)
	walk = k.walk
	fps = k.fps
	half_w = k.w / 2.0
	height = k.h


func step(delta: float, world_speed: float) -> void:
	t += delta
	position.x -= (world_speed + (0.0 if dead else walk)) * delta
	if position.x < -260.0:
		queue_free()
		return
	if not dead:
		sprite.frame = int(t * fps) % 4
		sprite.position.y = -absf(sin(t * fps * PI / 2.0)) * 2.0


func hurtbox() -> Rect2:
	return Rect2(position + Vector2(-half_w, -height), Vector2(half_w * 2.0, height - 4.0))


## Front (left) edge: what the blade meets.
func front() -> float:
	return position.x - half_w


func nape() -> Vector2:
	return position + Vector2(half_w * 0.3, -height * 0.82)


func die() -> void:
	dead = true
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "rotation", 0.5, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "modulate", Color(0.55, 0.42, 0.42, 1.0), 0.4)
	tw.chain().tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.6)
	tw.chain().tween_callback(queue_free)
