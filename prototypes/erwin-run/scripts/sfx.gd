extends "res://addons/proto_kit/sfx_bank.gd"
## Event → sound. Drop `<event>.ogg` into res://assets/sfx to replace a synth placeholder.

const Synth = preload("res://addons/proto_kit/synth.gd")


func _ready() -> void:
	_streams = {
		&"jump": Synth.ramp(260.0, 620.0, 0.14, 0.35, 0.1),
		&"land": Synth.click(0.07, 0.28, 30.0),
		&"slash": Synth.click(0.13, 0.32, 13.0),
		&"whiff": Synth.click(0.09, 0.16, 22.0),
		&"kill": Synth.click(0.3, 0.55, 9.0),
		&"steam": Synth.click(0.7, 0.18, 3.5),
		&"parry": Synth.notes([1568.0, 2349.0], 0.06),
		&"perfect": Synth.notes([1046.5, 1568.0, 2093.0], 0.05),
		&"hurt": Synth.ramp(420.0, 110.0, 0.28, 0.5, 0.25),
		&"warn": Synth.notes([1760.0, 1318.5], 0.07),
		&"rock": Synth.ramp(180.0, 90.0, 0.25, 0.3, 0.05),
		&"shatter": Synth.click(0.2, 0.4, 14.0),
		&"roar": Synth.ramp(150.0, 55.0, 1.3, 0.7, 0.15, 0.7),
		&"reach": Synth.ramp(90.0, 260.0, 0.5, 0.25, 0.5, 1.6),
		&"levi": Synth.notes([659.25, 987.77, 1318.5, 1975.5], 0.045),
		&"spin": Synth.click(0.06, 0.3, 26.0),
		&"boss_down": Synth.ramp(120.0, 40.0, 1.6, 0.7, 0.05),
		&"ui": Synth.notes([880.0, 1318.5], 0.05),
		&"fall": Synth.ramp(300.0, 70.0, 0.7, 0.5, 0.1),
		&"victory": Synth.notes([587.33, 739.99, 880.0, 1174.66, 0.0, 880.0, 1174.66], 0.12),
		&"over": Synth.notes([440.0, 392.0, 349.23, 293.66], 0.22, true),
	}
	super()
