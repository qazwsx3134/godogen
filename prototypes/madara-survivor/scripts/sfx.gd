extends "res://addons/proto_kit/sfx_bank.gd"
## The run's sound events with synthesized placeholders. Drop <event>.ogg / .wav into assets/sfx to replace one.
## Layers follow the design doc: a swing is a whoosh, its contact a thud, a kill a crack, a rock slam a deep knock.

const Synth = preload("res://addons/proto_kit/synth.gd")


func _ready() -> void:
	_streams = {
		&"swing": Synth.ramp(900.0, 260.0, 0.13, 0.25, 0.0, 1.6),
		&"hit": Synth.click(0.07, 0.45, 34.0),
		&"kill": Synth.click(0.12, 0.35, 18.0),
		&"slam": Synth.ramp(120.0, 45.0, 0.22, 0.55, 0.0, 1.2),
		&"dash": Synth.ramp(300.0, 1400.0, 0.12, 0.3, 0.0, 0.8),
		&"level_up": Synth.notes([523.25, 659.25, 783.99, 1046.5], 0.08),
		&"hurt": Synth.ramp(320.0, 140.0, 0.15, 0.4, 0.0, 1.0),
		&"pickup": Synth.ramp(1200.0, 1700.0, 0.05, 0.12, 0.0, 1.0),
		&"dodge": Synth.ramp(1800.0, 600.0, 0.18, 0.3, 0.0, 0.7),
		&"ultimate": Synth.ramp(60.0, 220.0, 1.6, 0.1, 0.5, 2.0),
		&"reflect": Synth.ramp(500.0, 1500.0, 0.1, 0.35, 0.1, 1.0),
	}
	fallback = {&"crit": &"slam", &"elite": &"slam"}
	super()
