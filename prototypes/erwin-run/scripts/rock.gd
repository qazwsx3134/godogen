extends Node2D
## A thrown boulder. Hostile until parried; a parried rock flies back (toward `target` when the boss is up).

signal struck_target

@onready var sprite: Sprite2D = %Sprite

var velocity := Vector2.ZERO
var spin := 8.0
var radius := 12.0
var parried := false
var target := Vector2.INF
var low := false
var delay := 0.0   # seconds before it appears (the boss's second rock)


func setup(at: Vector2, vel: Vector2, variant: int, is_low: bool, wait: float = 0.0) -> void:
	position = at
	delay = wait
	visible = wait <= 0.0
	velocity = vel
	low = is_low
	sprite.frame = variant
	spin = -9.0 if vel.x < 0.0 else 9.0


func step(delta: float) -> void:
	if delay > 0.0:
		delay -= delta
		visible = delay <= 0.0
		return
	if parried and target != Vector2.INF:
		var to := target - position
		if to.length() < 20.0:
			struck_target.emit()
			queue_free()
			return
		velocity = velocity.lerp(to.normalized() * 820.0, minf(1.0, delta * 6.0))
	position += velocity * delta
	rotation += spin * delta
	if position.x < -260.0 or position.x > 980.0 or position.y < -120.0 or position.y > 420.0:
		queue_free()


func hurtbox() -> Rect2:
	return Rect2(position - Vector2(radius, radius), Vector2(radius, radius) * 2.0)


func parry(to: Vector2 = Vector2.INF) -> void:
	parried = true
	target = to
	velocity = Vector2(560.0, -420.0)
	spin = 22.0
