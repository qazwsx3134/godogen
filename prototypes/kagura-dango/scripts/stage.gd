extends Node2D
## The contest hall every round plays in: crowd, lanterns, the rival team at the back table, the referee.
## set_intensity (1..3, from the chart) makes it livelier: more spectators bobbing harder, brighter lantern flashes,
## a hotter curtain, speed lines in the final round. Everything here is background: it never covers the skewer's
## arc or the mouths, and it makes no sound (the player listens for the cues).

const CURTAIN := [Color(0.74, 0.2, 0.25), Color(0.82, 0.18, 0.2), Color(0.92, 0.3, 0.12)]

var intensity := 1
var _homes := {}  # background figure → its resting position

@onready var _crowd: Node2D = %Crowd
@onready var _lanterns: Node2D = %Lanterns
@onready var _curtain: ColorRect = %Curtain
@onready var _rivals: Array[Node2D] = [%RivalA, %RivalB]
@onready var _plates: Node2D = %RivalPlates
@onready var _referee: Node2D = %Referee
@onready var _speed_lines: Node2D = %SpeedLines


## A round may play outdoors (the chart's "background"): swap the hall picture (and its two mirrored side copies,
## which fill the canvas of a phone wider than 16:9; the seam is invisible because a mirror matches along its edge).
func set_background(path: String) -> void:
	if path != "" and ResourceLoader.exists(path):
		for n in [%Background, %BackgroundLeft, %BackgroundRight]:
			n.texture = load(path)


## Round 1 follows the original episode's outdoor contest: a plain stage, no crowd or lanterns, one rival.
func set_calm(calm: bool) -> void:
	for n in [_crowd, _lanterns, %RivalB, %Commentators, _referee]:
		n.visible = not calm


## Round 2 keeps the rival team off the back table: the only rival on screen is the one sneaking in.
## Only hides (shown = true leaves what set_calm chose).
func set_rival_table(shown: bool) -> void:
	if shown:
		return
	for n in [%RivalA, %RivalB, _plates]:
		n.visible = false


## Background figures that hop on every beat (higher with the combo's hype).
func _hoppers() -> Array:
	return [%RivalA, %RivalB, _referee, %Commentators]


func set_intensity(level: int) -> void:
	intensity = clampi(level, 1, 3)
	_crowd.count = 8 + 8 * intensity
	_curtain.color = CURTAIN[intensity - 1]
	_speed_lines.visible = intensity >= 3


## One beat. hype (0..1, from the combo) makes it bigger: the crowd bobs higher, lanterns flash brighter, the
## background figures hop higher, and from hype 0.6 the speed lines join in every round.
func pulse(hype := 0.0) -> void:
	_crowd.bob(1.5 * intensity + 6.0 * hype)
	_lanterns.flash(0.25 + 0.25 * intensity + 0.5 * hype)
	_speed_lines.visible = intensity >= 3 or hype >= 0.6
	if _speed_lines.visible:
		_speed_lines.flash()
	for n: Node2D in _hoppers():
		if not n.visible:
			continue
		if not _homes.has(n):
			_homes[n] = n.position
		var tw := create_tween()
		tw.tween_property(n, "position:y", _homes[n].y - (2.0 + 8.0 * hype), 0.08).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "position:y", _homes[n].y, 0.16).set_ease(Tween.EASE_IN)


func rival_eat(total: int) -> void:
	_rivals[total % 2].call("play_pose", &"eat", 0.3)
	_rivals[total % 2].bump(0.1, 0.12)
	_plates.count = total


func referee_call(pose: StringName) -> void:
	_referee.call("play_pose", pose, 0.8)
	_referee.bump(0.15, 0.25)


## Speed lines centre on whoever is being fed.
func focus(at_global: Vector2) -> void:
	_speed_lines.global_position = at_global
