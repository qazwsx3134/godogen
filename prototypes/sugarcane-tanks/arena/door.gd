extends Area2D
## Exit at the top of the room. Locked (red bars) until the room is cleared and
## the rewards are picked, then glows and takes the hero to the next room.

signal entered

var is_open: bool = false

@onready var _bars: Node2D = %Bars
@onready var _glow: Node2D = %Glow

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_glow.visible = false

func open() -> void:
	is_open = true
	_bars.visible = false
	_glow.visible = true
	_glow.modulate.a = 0.4
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(_glow, "modulate:a", 1.0, 0.5)
	tween.tween_property(_glow, "modulate:a", 0.4, 0.5)
	for body: Node2D in get_overlapping_bodies():
		_on_body_entered(body)

func _on_body_entered(body: Node2D) -> void:
	if is_open and body.is_in_group("hero"):
		is_open = false
		entered.emit()
