extends Node2D
## The contest hall every round plays in: crowd, lanterns, the rival team at the back table, the referee.
## set_intensity (1..3, from the chart) makes it livelier: more spectators bobbing harder, brighter lantern flashes,
## a hotter curtain, speed lines in the final round. Everything here is background: it never covers the skewer's
## arc or the mouths, and it makes no sound (the player listens for the cues).

const CURTAIN := [Color(0.74, 0.2, 0.25), Color(0.82, 0.18, 0.2), Color(0.92, 0.3, 0.12)]

var intensity := 1

@onready var _crowd: Node2D = %Crowd
@onready var _lanterns: Node2D = %Lanterns
@onready var _curtain: ColorRect = %Curtain
@onready var _rivals: Array[Node2D] = [%RivalA, %RivalB]
@onready var _plates: Node2D = %RivalPlates
@onready var _referee: Node2D = %Referee
@onready var _speed_lines: Node2D = %SpeedLines


func set_intensity(level: int) -> void:
	intensity = clampi(level, 1, 3)
	_crowd.count = 8 + 8 * intensity
	_curtain.color = CURTAIN[intensity - 1]
	_speed_lines.visible = intensity >= 3


func pulse() -> void:
	_crowd.bob(1.5 * intensity)
	_lanterns.flash(0.25 + 0.25 * intensity)
	if _speed_lines.visible:
		_speed_lines.flash()


func rival_eat(total: int) -> void:
	_rivals[total % 2].bump(0.1, 0.12)
	_plates.count = total


func referee_call() -> void:
	_referee.bump(0.15, 0.25)


## Speed lines centre on whoever is being fed.
func focus(at_global: Vector2) -> void:
	_speed_lines.global_position = at_global
