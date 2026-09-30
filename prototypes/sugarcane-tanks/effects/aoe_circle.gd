extends Node2D
## Red-circle area attack. A translucent disc with a bright rim sits on the floor while a
## brighter disc (%Grow) fills it from the centre; when it is full the circle blows up and hurts
## the hero if the hero's centre is inside. Then it fades and frees itself.
## It lives under Main's EnemyShots, so clearing the room or the hero dying stops it like a bullet.
## The look is authored in aoe_circle.tscn at DESIGN_RADIUS; `radius` rescales it on top of whatever
## scale the scene has. %Grow is drawn at 60% so the editor shows both layers; at runtime it grows 0 → 1.

const DESIGN_RADIUS: float = 130.0
const FADE_TIME: float = 0.4

@export var radius: float = 130.0
@export var telegraph_time: float = 1.5
@export var damage: int = 120

var game: Node
var exploded: bool = false

@onready var _visual: Node2D = %Visual
@onready var _grow: Polygon2D = %Grow
@onready var _burst: Polygon2D = %Burst

## True while the blast is still coming (the bot leaves circles that say so).
func is_aoe() -> bool:
	return not exploded

func _ready() -> void:
	_visual.scale *= radius / DESIGN_RADIUS
	_grow.scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(_grow, "scale", Vector2.ONE, telegraph_time)
	tween.tween_callback(_explode)

func _explode() -> void:
	exploded = true
	if game.hero.global_position.distance_to(global_position) <= radius:
		game.hero.take_hit(damage)
	game.spawn_explosion(global_position, radius / 80.0, Color(1.0, 0.25, 0.2))
	for i: int in 6:
		game.spawn_puff(global_position + Vector2.from_angle(randf() * TAU) * randf() * radius * 0.7, Color(0.4, 0.37, 0.34))
	game.shake(6.0, 0.2)
	game.sfx.play(&"boom")
	_visual.modulate = Color(1.8, 1.4, 1.4)
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_visual, "modulate", Color(1.0, 1.0, 1.0, 0.0), FADE_TIME).set_ease(Tween.EASE_IN)
	tween.tween_property(_burst, "scale", Vector2(1.5, 1.5), FADE_TIME).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(queue_free)
