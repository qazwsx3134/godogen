extends Node2D
## One note on the track: a coloured drum head (whose lane it is) with the cue's picture on it.

## Lane colours: left Gintoki red, middle Shinpachi blue, right Kagura pink; any-side notes (round 3) orange.
const LANE_COLORS := {0: Color(0.86, 0.22, 0.2), 1: Color(0.2, 0.45, 0.86), 2: Color(0.95, 0.45, 0.68), -1: Color(0.96, 0.58, 0.16)}
const ICONS := {
	&"anko": "res://assets/sprites/dango_flavors_0.png",
	&"soy": "res://assets/sprites/dango_flavors_1.png",
	&"rice": "res://assets/sprites/rice_bowl.png",
	&"bento": "res://assets/sprites/shinpachi_bento_2.png",
	&"rival": "res://assets/sprites/gintoki_kick_1.png",
	&"big": "res://assets/sprites/dango_props_1.png",
}
const DEFAULT_ICON := "res://assets/sprites/dango_props_0.png"

@export var radius := 13.0

var lane := -1
var type: StringName = &"tri"


func _ready() -> void:
	var path: String = ICONS.get(type, DEFAULT_ICON)
	%Icon.texture = load(path if ResourceLoader.exists(path) else DEFAULT_ICON)
	var tex_size: Vector2 = %Icon.texture.get_size()
	%Icon.scale = Vector2.ONE * (radius * 1.5 / maxf(tex_size.x, tex_size.y))
	if type == &"big":
		scale = Vector2(1.35, 1.35)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 2.0, Color(0.1, 0.08, 0.12))
	draw_circle(Vector2.ZERO, radius, LANE_COLORS.get(lane, LANE_COLORS[-1]))
	draw_circle(Vector2.ZERO, radius * 0.72, Color(1, 0.97, 0.9))


## Hit: arc up to `to` (the score, in the parent's space), shrinking, and vanish there.
func fly_to(to: Vector2) -> void:
	var from := position
	var peak := (from + to) * 0.5 + Vector2(0, -50)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		position = from.lerp(peak, t).lerp(peak.lerp(to, t), t)
		scale = Vector2.ONE * lerpf(1.3, 0.6, t), 0.0, 1.0, 0.4).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.06)
	tw.tween_callback(queue_free)


## Hit: pop and vanish. Missed: drop and fade.
func finish(hit: bool) -> void:
	var tw := create_tween().set_parallel()
	if hit:
		tw.tween_property(self, "scale", scale * 1.6, 0.12)
		tw.tween_property(self, "modulate:a", 0.0, 0.12)
	else:
		tw.tween_property(self, "position:y", position.y + 14.0, 0.25)
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)
