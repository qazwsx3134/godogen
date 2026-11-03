extends Node2D
## Bar lines on the note track (every 4 beats), drawn under the notes so the player can read the rhythm.
## NoteTrack sets `xs` every frame.

@export var half_height := 19.0
@export var color := Color(1, 0.97, 0.9, 0.6)

var xs: PackedFloat32Array = []:
	set(value):
		xs = value
		queue_redraw()


func _draw() -> void:
	for x in xs:
		draw_line(Vector2(x, -half_height), Vector2(x, half_height), color, 2.0)
