extends Node2D
@export var lifetime: float = 0.32
var age: float = 0.0
@onready var burst: Node2D = %Burst
@onready var streak: Line2D = %Streak
@onready var caption: Label = %Caption
func setup(lethal: bool, direction: Vector2) -> void:
	rotation = direction.angle()
	caption.rotation = -rotation
	caption.text = "飛出去！" if lethal else "砰！"
	if lethal:
		lifetime = 0.5
		burst.scale = Vector2.ONE * 1.7
		streak.show()
	else:
		streak.hide()
func _process(delta: float) -> void:
	age += delta
	burst.scale += Vector2.ONE * delta * 2.4
	caption.position.y -= delta * 45.0
	modulate.a = clampf((lifetime - age) / 0.16, 0.0, 1.0)
	if age >= lifetime:
		queue_free()
