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
		_check_report(seed_value, idle, good, late)
	test_push_sim_revive_credits_the_target_hp()
	test_push_sim_advance_ignores_the_frame_rate()
	_finish("BALANCE TESTS")


func test_push_sim_advance_ignores_the_frame_rate() -> void:
	# Arrange: the same idle push fed by uneven frames (with hitches) and by exact ticks
	var frames := PushSim.new(1)
	var ticks := PushSim.new(1)
	frames.skip_muster()
	ticks.skip_muster()
	var pattern: Array[float] = [1.0 / 30.0, 1.0 / 144.0, 0.05, 2.0, 1.0 / 60.0]
	# Act
	var k: int = 0
	while frames.fighting():
		frames.advance(pattern[k % pattern.size()])
		k += 1
	for i: int in frames.ticks:
		ticks.step(PushSim.STEP)
	# Assert
	_expect(frames.boss_hp == ticks.boss_hp and frames.fallen_total == ticks.fallen_total,
		"advance: uneven frames play the same fight as fixed ticks (%.2f vs %.2f)" % [frames.boss_hp, ticks.boss_hp])
	var stalled := PushSim.new(1)
	stalled.advance(10.0)
	_expect(stalled.ticks <= ceili(PushSim.MAX_FRAME / PushSim.STEP), "advance: a 10 s stall advances at most MAX_FRAME")


func test_push_sim_revive_credits_the_target_hp() -> void:
	# Arrange: an SSR healer and a fallen hero with a different max HP in its zone
	var sim := PushSim.new(1)
	var healer: int = -1
	for i: int in sim.cls.size():
		if sim.cls[i] == PushSim.HEALER and sim.rarity[i] == PushSim.SSR:
			healer = i
	var target: int = 0 if healer != 0 else 1
	sim.zone[target] = sim.zone[healer]
	sim.max_hp[target] = sim.max_hp[healer] * 2.0
	sim.hp[target] = 0.0
	var before: float = sim.contribution(healer)
	# Act
	var ok: bool = sim._revive(sim.zone[healer], healer)
	# Assert
	var restored: float = sim.hp[target]
	_expect(ok and sim.saves[healer] == 1 and is_equal_approx(sim.contribution(healer) - before, restored),
		"revive: the healer is credited the target's restored HP (%.0f, got %.0f)" % [restored, sim.contribution(healer) - before])


## 推王戰報: per-hero damage adds up to the army's, and a lost push names a cause that matches how it was lost.
func _check_report(seed_value: int, idle: PushSim, good: PushSim, late: PushSim) -> void:
	for sim: PushSim in [idle, good, late]:
		var sum: float = 0.0
		for d: float in sim.dealt:
			sum += d
		_expect(absf(sum - sim.damage_dealt) <= sim.damage_dealt * 0.01,
			"seed %d report: hero damage sums to the army's (%.0f vs %.0f)" % [seed_value, sum, sim.damage_dealt])
	var r: Dictionary = late.report()
	_expect(int(r.tele_falls) > int(r.auto_falls) and not (r.advice as PackedStringArray).is_empty(),
		"seed %d report: late dodging falls mostly to telegraphs (%d vs 普攻 %d)" % [seed_value, r.tele_falls, r.auto_falls])
	var gr_lost: Dictionary = idle.report()
	_expect((gr_lost.advice as PackedStringArray).size() >= 1, "seed %d report: a lost push gets advice" % seed_value)
	var gr: Dictionary = good.report()
	_expect(good.contribution(gr.mvp) > 0.0 and gr.top.dealt[0][1] >= gr.top.dealt[-1][1],
		"seed %d report: an MVP with a contribution and a sorted damage ranking" % seed_value)
	if seed_value == SEEDS[0]:
		print("late report: mvp %s causes %s advice %s" % [late.hero_name(r.mvp), r.causes, r.advice])
		print("idle advice: %s" % [idle.report().advice])


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
