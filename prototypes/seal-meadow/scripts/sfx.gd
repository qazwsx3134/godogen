extends "res://addons/proto_kit/sfx_bank.gd"
## Combat and pickup sounds. Placeholders are synthesized; drop <event>.ogg into res://assets/sfx to replace one.

const Synth = preload("res://addons/proto_kit/synth.gd")


func _ready() -> void:
	_streams = {
		&"hit": Synth.click(0.05, 0.35, 38.0),
		&"crit": Synth.ramp(900.0, 300.0, 0.12, 0.5, 0.0, 1.5),
		&"sweep": Synth.ramp(220.0, 700.0, 0.18, 0.45, 0.1),
		&"player_hurt": Synth.ramp(320.0, 160.0, 0.1, 0.4, 0.0),
		&"monster_die": Synth.ramp(500.0, 120.0, 0.25, 0.4, 0.0),
		&"level_up": Synth.notes([523.0, 659.0, 784.0, 1047.0], 0.09),
		&"pickup": Synth.notes([880.0, 1175.0], 0.05, true),
		&"denied": Synth.click(0.08, 0.25, 14.0),
	}
	fallback = {&"bag_full": &"denied"}
	super()
