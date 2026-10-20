extends "res://addons/proto_kit/test_kit.gd"
## README acceptance criteria 1 and 2, played by bots on the pure sim (5 seeds):
##   idle   never touches anything                                   -> loses
##   good   dodges every telegraph the moment it shows (moves each marked zone to the safest unmarked one),
##          regroups after the hit, taps weak points, volleys (skills cast themselves)
##                                                                  -> wins with 25-45 s left
##   human  the same plan, but reacts REACTION s after each cue and acts at most once per ACTION_GAP s
##                                                                  -> still wins
##   late   the same, but only gets to the dodge after the hit landed -> loses
##   godot --headless --path prototypes/hero-horde-idle --script res://tests/test_balance.gd

const PushSim = preload("res://domain/push_sim.gd")
const DT := 1.0 / 60.0
const SEEDS := [1, 2, 3, 4, 5]
const REACTION := 0.6
const ACTION_GAP := 0.5


func _init() -> void:
	for seed_value: int in SEEDS:
		var idle: PushSim = _play(seed_value, {"idle": true})
		var good: PushSim = _play(seed_value, {})
		var human: PushSim = _play(seed_value, {"reaction": REACTION, "gap": ACTION_GAP})
		var late: PushSim = _play(seed_value, {"reaction": PushSim.TELE_WARN + 0.3, "gap": ACTION_GAP})
		print("seed %d  idle %s | good %s | human %s | late %s" % [seed_value, _line(idle), _line(good), _line(human), _line(late)])
		_expect(idle.phase == PushSim.Phase.LOST, "seed %d: idle loses" % seed_value)
		_expect(good.phase == PushSim.Phase.WON and good.time_left() >= 25.0 and good.time_left() <= 45.0,
			"seed %d: good wins with 25-45 s left (got %.1f s)" % [seed_value, good.time_left()])
		_expect(human.phase == PushSim.Phase.WON and human.time_left() >= 10.0,
			"seed %d: human wins with 10+ s left (got %s)" % [seed_value, _line(human)])
		_expect(late.phase == PushSim.Phase.LOST, "seed %d: late dodging loses" % seed_value)
	_finish("BALANCE TESTS")


func _play(seed_value: int, opts: Dictionary) -> PushSim:
	var sim := PushSim.new(seed_value)
	var reaction: float = opts.get("reaction", 0.0)
	var gap: float = opts.get("gap", 0.0)
	var tele_seen: float = -1.0
	var dodged: bool = false
	var next_action: float = 0.0
	sim.skip_muster()
	while sim.fighting():
		if not opts.get("idle", false) and sim.t >= next_action:
			var acted: bool = false
			if sim.tele_t > 0.0:
				if tele_seen < 0.0:
					tele_seen = sim.t
					dodged = false
				if not dodged and sim.t - tele_seen >= reaction:
					acted = _dodge(sim)
					dodged = not acted
			elif tele_seen >= 0.0:
				tele_seen = -1.0
				acted = sim.regroup()
			if not acted:
				acted = _act(sim)
			if acted:
				next_action = sim.t + gap
		sim.step(DT)
	return sim


## Moves one marked zone that still has heroes to the safest unmarked zone. False when nothing is left to move.
func _dodge(sim: PushSim) -> bool:
	for z: int in sim.tele_zones:
		if sim.living_in(z) == 0:
			continue
		var best: int = -1
		var best_cost: float = INF
		for d: int in PushSim.ZONES:
			if d in sim.tele_zones:
				continue
			# Prefer the other column of the same row, then a neighbouring row; then the emptier zone.
			var cost: float = absi(d / 2 - z / 2) * 10.0 + sim.living_in(d)
			if cost < best_cost:
				best_cost = cost
				best = d
		return sim.move_zone(z, best)
	return false


func _act(sim: PushSim) -> bool:
	if sim.weak_t > 0.0:
		return sim.tap_weak_point()
	if sim.morale >= PushSim.MORALE_MAX:
		return sim.volley()
	return false


func _line(sim: PushSim) -> String:
	return "%s %3.0f%% %5.1fs fell %d" % ["WON " if sim.phase == PushSim.Phase.WON else "LOST", sim.hp_ratio() * 100.0,
		sim.time_left(), sim.fallen_total]
