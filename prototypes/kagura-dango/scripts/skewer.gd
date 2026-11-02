extends Node2D
## One dango skewer in flight: an arc from the thrower's hand that lands in the mouth exactly at its beat.
## Placeholder drawing (stick and three dango); the generated art replaces _draw with a sprite.

const FLAVORS := {
	&"tri": [Color(0.98, 0.62, 0.72), Color(0.98, 0.97, 0.92), Color(0.55, 0.78, 0.45)],
	&"anko": [Color(0.42, 0.22, 0.2), Color(0.42, 0.22, 0.2), Color(0.42, 0.22, 0.2)],
	&"soy": [Color(0.86, 0.6, 0.25), Color(0.86, 0.6, 0.25), Color(0.86, 0.6, 0.25)],
}

var flavor := &"tri"

var from := Vector2.ZERO
var to := Vector2.ZERO
var t0 := 0.0
var t1 := 1.0
var height := 120.0
var big := false
var state := &"flying"  # flying, eaten, dropped


func place(t: float) -> void:
	if state != &"flying":
		return
	var u := (t - t0) / maxf(0.001, t1 - t0)
	position = from.lerp(to, u) + Vector2(0, -height * 4.0 * u * (1.0 - u))
	rotation = lerpf(-0.6, 0.6, u)


func eat() -> void:
	state = &"eaten"
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.2, 0.2), 0.08)
	tw.tween_callback(queue_free)


func drop() -> void:
	state = &"dropped"
	var tw := create_tween()
	tw.tween_property(self, "position", position + Vector2(30, 70), 0.35).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "rotation", rotation + 2.0, 0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


func _draw() -> void:
	var r := 13.0 if big else 9.0
	draw_line(Vector2(-r * 4, 0), Vector2(r * 4, 0), Color(0.72, 0.55, 0.3), 3.0)
	for i in 3:
		draw_circle(Vector2((i - 1) * r * 2.1, 0), r, FLAVORS[flavor][i])
		draw_arc(Vector2((i - 1) * r * 2.1, 0), r, 0, TAU, 20, Color(0.35, 0.25, 0.2), 1.5)
