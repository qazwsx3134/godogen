extends Node2D
## Expanding ring for explosions, lantern fire and farts. Damage is applied by Street when it spawns.
@export var lifetime: float = 0.35
var age: float = 0.0
@onready var ring: Line2D = %Ring
@onready var fill: Polygon2D = %Fill
@onready var caption: Label = %Caption

func setup(radius: float, color: Color, text: String = "") -> void:
	scale = Vector2.ONE * (radius / 100.0)
	ring.default_color = color
	fill.color = Color(color, 0.35)
	caption.text = text
	caption.visible = text != ""
	caption.scale = Vector2.ONE / scale.x

func _process(delta: float) -> void:
	age += delta
	var t: float = clampf(age / lifetime, 0.0, 1.0)
	ring.scale = Vector2.ONE * (0.6 + 0.5 * t)
	fill.scale = ring.scale
	modulate.a = 1.0 - t * t
	caption.position.y = -40.0 - 40.0 * t
	if age >= lifetime:
		queue_free()
