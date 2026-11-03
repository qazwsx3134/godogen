class_name Conductor
extends "res://addons/proto_kit/song_clock.gd"
## This game's song clock: the kit's song_clock.gd with this game's mix.
## The three songs are mastered hot (about -7 LUFS, true peaks +1.5..+2.5 dBFS), so at 0 dB they clip against the
## sound effects and voice lines; -6 dB leaves them near -13 LUFS. They play on the Music bus (Settings' volume).


func _init() -> void:
	level_db = -6.0
	bus = &"Music"
