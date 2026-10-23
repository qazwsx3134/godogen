extends "res://addons/proto_kit/sfx_bank.gd"
## The push's sounds by event name. Placeholders are synthesised; drop `<event>.ogg` (or .wav) into assets/sfx to
## replace one without touching code.
##   warn     a telegraph goes up (rising whine)         slam     a telegraphed attack lands
##   thud     普通攻擊 lands                               fall     heroes fell
##   skill    an SR/SSR skill fires                       volley   大招
##   aim      a boss part is aimed at                     break    a boss part breaks
##   signature an SSR's 招牌技
##   phase2   the boss enrages                            revive   an SSR healer revives someone
##   move     a squad is moved or regrouped                tap      a HUD button
##   won / lost

const Synth = preload("res://addons/proto_kit/synth.gd")


func _ready() -> void:
	_streams = {
		&"warn": Synth.ramp(220.0, 520.0, 0.5, 0.15, 0.35, 1.6),
		&"slam": Synth.click(0.45, 0.6, 7.0),
		&"thud": Synth.click(0.12, 0.35, 26.0),
		&"fall": Synth.ramp(330.0, 140.0, 0.22, 0.25, 0.05),
		&"skill": Synth.ramp(600.0, 1100.0, 0.12, 0.2, 0.1),
		&"volley": Synth.click(0.6, 0.55, 5.0),
		&"aim": Synth.notes([987.77, 1318.5], 0.06),
		&"signature": Synth.notes([659.25, 880.0, 1174.66, 1760.0], 0.07),
		&"break": Synth.click(0.35, 0.55, 10.0),
		&"phase2": Synth.ramp(160.0, 70.0, 0.9, 0.5, 0.2, 0.7),
		&"revive": Synth.notes([523.25, 783.99, 1046.5], 0.08, true),
		&"move": Synth.click(0.04, 0.25, 50.0),
		&"tap": Synth.click(0.03, 0.2, 60.0),
		&"won": Synth.notes([523.25, 659.25, 783.99, 1046.5], 0.14),
		&"lost": Synth.notes([392.0, 329.63, 261.63, 196.0], 0.18, true),
	}
	super()
