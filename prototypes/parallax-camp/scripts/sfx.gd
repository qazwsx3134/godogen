extends "res://addons/proto_kit/sfx_bank.gd"

const Synth = preload("res://addons/proto_kit/synth.gd")


func _ready() -> void:
	_streams = {
		&"jump": Synth.ramp(205.0, 485.0, 0.15, 0.30, 0.0, 0.65),
		&"land": Synth.click(0.17, 0.52, 25.0),
		&"stoke": Synth.click(0.35, 0.60, 8.0),
		&"inspect": Synth.notes([330.0, 440.0, 587.0], 0.065, true),
		&"cook": Synth.click(0.52, 0.45, 6.0),
	}
	super()
