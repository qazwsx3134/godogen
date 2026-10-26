extends "res://addons/proto_kit/sfx_bank.gd"
const Synth = preload("res://addons/proto_kit/synth.gd")


func _ready() -> void:
	_streams = {&"upgrade": Synth.notes([523.25, 659.25, 783.99], 0.07, true),
		&"loot": Synth.notes([783.99, 1046.5], 0.08, true),
		&"click": Synth.click(0.025, 0.08, 80.0)}
	super()
