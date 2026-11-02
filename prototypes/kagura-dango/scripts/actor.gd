@tool
extends Node2D
## Placeholder character: a coloured body and head with a name tag, plus the Hand and Mouth markers minigames aim at.
## The generated art replaces Body/Head with a sprite later; the markers stay.

@export var display_name := "角色":
	set(v):
		display_name = v
		_apply()
@export var body_color := Color(0.3, 0.4, 0.7):
	set(v):
		body_color = v
		_apply()
@export var head_color := Color(0.98, 0.86, 0.74):
	set(v):
		head_color = v
		_apply()

## 1 = normal; Kagura grows to about 1.9 over a match. Only the body widens: the Mouth marker stays put, so the
## skewers still land on it.
@export var girth := 1.0:
	set(v):
		girth = v
		_apply()
## 0..1 how full: tints the face red and adds sweat drops at the top.
@export var fullness := 0.0:
	set(v):
		fullness = v
		_apply()

var _base_scale := Vector2.ONE


func _ready() -> void:
	_base_scale = scale
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	$Body.color = body_color
	$Body.size.x = 80.0 * girth
	$Body.position.x = -40.0 * girth
	$Head.color = head_color.lerp(Color(0.95, 0.45, 0.4), fullness * 0.6)
	$Sweat.visible = fullness >= 0.5
	$NameLabel.text = display_name


## A quick squash, e.g. a chomp or a throw.
func bump(amount := 0.12, time := 0.12) -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", _base_scale * Vector2(1.0 + amount, 1.0 - amount), time * 0.4)
	tw.tween_property(self, "scale", _base_scale, time * 0.6)
