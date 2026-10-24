extends "res://addons/proto_kit/sfx_bank.gd"
## Field sound events. Drop assets/sfx/<event>.ogg to replace a synthesized placeholder.

const Synth = preload("res://addons/proto_kit/synth.gd")


func _ready() -> void:
	_streams = {
		&"swing": Synth.ramp(900.0, 260.0, 0.09, 0.22, 0.0, 1.6),
		&"hit": Synth.click(0.06, 0.38, 38.0),
		&"crit": Synth.ramp(1400.0, 420.0, 0.14, 0.42, 0.0, 1.3),
		&"block": Synth.notes([620.0, 420.0], 0.04),
		&"miss": Synth.ramp(500.0, 900.0, 0.08, 0.15, 0.0),
		&"enemy_down": Synth.ramp(320.0, 90.0, 0.32, 0.45, 0.0, 1.4),
		&"skill": Synth.ramp(220.0, 1300.0, 0.18, 0.35, 0.15, 0.8),
		&"heal": Synth.notes([660.0, 880.0, 1100.0], 0.06, true),
		&"potion": Synth.notes([520.0, 780.0], 0.07, true),
		&"taunt": Synth.ramp(180.0, 120.0, 0.22, 0.5, 0.1),
		&"level_up": Synth.notes([523.0, 659.0, 784.0, 1047.0], 0.09, true),
		&"quest": Synth.notes([784.0, 988.0, 1175.0], 0.1, true),
		&"loot": Synth.notes([1320.0, 1760.0], 0.05, true),
		&"blocked": Synth.notes([300.0, 240.0], 0.07),
		&"run_end": Synth.ramp(330.0, 70.0, 1.1, 0.5, 0.0, 0.7),
		&"ui": Synth.click(0.03, 0.18, 60.0),
	}
	fallback = {&"party_hurt": &"hit"}
	super()
