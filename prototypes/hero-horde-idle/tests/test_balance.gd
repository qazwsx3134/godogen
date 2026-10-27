extends "res://addons/proto_kit/test_kit.gd"
## README acceptance criteria 1 and 2 at the reference roster (no growth), played by the bots in tests/push_bots.gd
## over 5 seeds:
##   idle -> loses; good -> wins with 25-45 s left; noparts -> clearly worse than good; human (reacts late, drags like
##   a person) -> still wins; late (dodges after the hit) -> loses.
##   godot --headless --path prototypes/hero-horde-idle --script res://tests/test_balance.gd

const PushSim = preload("res://domain/push_sim.gd")
const PushBots = preload("res://tests/push_bots.gd")
const SEEDS := [1, 2, 3, 4, 5]


func _init() -> void:
	for seed_value: int in SEEDS:
		var idle: Dictionary = PushBots.play(seed_value, PushBots.IDLE)
		var good: Dictionary = PushBots.play(seed_value, PushBots.GOOD)
		var noparts: Dictionary = PushBots.play(seed_value, PushBots.NOPARTS)
		var human: Dictionary = PushBots.play(seed_value, PushBots.HUMAN)
		var late: Dictionary = PushBots.play(seed_value, PushBots.LATE)
		print("seed %d  idle %s\n        good %s\n     noparts %s\n       human %s\n        late %s" % [seed_value,
			PushBots.line(idle), PushBots.line(good), PushBots.line(noparts), PushBots.line(human), PushBots.line(late)])
		var g: PushSim = good.sim
		var np: PushSim = noparts.sim
		_expect(idle.sim.phase == PushSim.Phase.LOST, "seed %d: idle loses" % seed_value)
		_expect(g.phase == PushSim.Phase.WON and g.time_left() >= 25.0 and g.time_left() <= 45.0,
			"seed %d: good wins with 25-45 s left (got %s)" % [seed_value, PushBots.line(good)])
		_expect(np.phase == PushSim.Phase.LOST or g.time_left() - np.time_left() >= 8.0 or np.fallen_total - g.fallen_total >= 10,
			"seed %d: breaking parts clearly helps (good %s vs noparts %s)" % [seed_value, PushBots.line(good), PushBots.line(noparts)])
		_expect(human.sim.phase == PushSim.Phase.WON and human.sim.time_left() >= 10.0,
			"seed %d: human wins with 10+ s left (got %s)" % [seed_value, PushBots.line(human)])
		_expect(late.sim.phase == PushSim.Phase.LOST, "seed %d: late dodging loses" % seed_value)
	_finish("BALANCE TESTS")
