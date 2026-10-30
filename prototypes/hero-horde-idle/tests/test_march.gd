extends "res://addons/proto_kit/test_kit.gd"
## 行軍 (domain/march_sim.gd) with the squad from domain/progression.gd:
##   the same seed gives the same march at 15, 30, 60 and 120 FPS
##   a 段 is WAVES waves, then the squad marches on (travel) and the next 段 begins
##   a new save's squad clears 1-1 on its own; a squad far too weak for a stage falls (lost) and the pace measure steps
##   the march back to a stage it holds
##   the forms' passives do what they say: a monster heals from its hits, a dreamling regains HP on its own
##   the bonds: 2 / 3 / 5 of a form reach tiers 1-3, one of each is 三族同行; a human bond raises the squad's attack
##   march kills pay gold, EXP for the squad only, and the offline claim pays the measured pace for the time away
##   godot --headless --path prototypes/hero-horde-idle --script res://tests/test_march.gd
const MarchSim = preload("res://domain/march_sim.gd")
const Progression = preload("res://domain/progression.gd")
const Heroes = preload("res://domain/heroes.gd")
const Stages = preload("res://domain/stages.gd")
const PushSim = preload("res://domain/push_sim.gd")


func _init() -> void:
	var p := Progression.new(3)
	var units: Array = p.march_units()
	_expect(units.size() == 3 and p.slots() == 3, "a new save marches with 3 heroes in 3 slots")
	_expect(p.march == PackedInt32Array([13, 33, 99]) and units[0].cls == PushSim.SHIELD and units[2].cls == PushSim.HEALER,
		"the opening squad: the shield, sword and healer SSRs")

	# Fixed steps: any frame rate gives the same march.
	var finals: Array = []
	for fps: int in [15, 30, 60, 120]:
		var sim := MarchSim.new(7, units, 1)
		for k: int in fps * 40:
			sim.step(1.0 / fps)
		finals.append("%d %d %.3f %.3f" % [sim.kills, sim.waves_cleared, sim.hp[0], sim.t])
	_expect(finals.count(finals[0]) == 4, "the same march at 15/30/60/120 FPS (%s)" % finals[0])

	var sim := MarchSim.new(7, units, 1)
	var travels: int = 0
	var waves: int = 0
	for k: int in 1200:
		sim.step(0.05)
		for e: Dictionary in sim.take_events():
			if e.kind == &"travel":
				travels += 1
			elif e.kind == &"wave":
				waves += 1
	_expect(not sim.lost and sim.kills >= 12, "the opening squad holds 1-1 for a minute (%d kills, %d waves)" % [sim.kills, waves])
	_expect(travels >= 1 and sim.waves_cleared >= MarchSim.WAVES, "after %d waves the squad marches on (%d times)" % [MarchSim.WAVES, travels])

	print("stage  kills/s (opening squad, 90 s)")
	for n: int in range(1, 6):
		var m: Dictionary = MarchSim.measure(units, n, 90.0)
		print("%-5s  %.3f %s" % [Stages.label(n), m.kills_per_sec, "LOST" if m.lost else ""])
	var hard: Dictionary = MarchSim.measure(units, 6, 90.0)
	_expect(hard.lost, "the opening squad falls at %s" % Stages.label(6))
	var q := Progression.new(3)
	q.cleared = 9
	q.march_stage = 8
	var pace: Dictionary = q.measure_march()
	_expect(pace.stage < 8 and q.march_stage == pace.stage and pace.kills_per_sec > 0.0,
		"too weak for %s: the pace measure steps the march back to %s" % [Stages.label(8), Stages.label(pace.stage)])

	# Passives.
	var monster: Dictionary = units[1].duplicate()
	monster.lifesteal = Heroes.BEAST_LIFESTEAL
	var plain: Dictionary = units[1].duplicate()
	plain.lifesteal = 0.0
	var a := MarchSim.new(1, [monster], 1)
	var b := MarchSim.new(1, [plain], 1)
	for k: int in 400:
		a.step(0.05)
		b.step(0.05)
	_expect(a.hp[0] > b.hp[0], "a monster's lifesteal keeps it healthier (%.0f vs %.0f HP)" % [a.hp[0], b.hp[0]])
	var dream: Dictionary = units[0].duplicate()
	dream.regen = Heroes.ELF_REGEN
	var c := MarchSim.new(1, [dream], 1)
	c.hp[0] = c.max_hp[0] * 0.5
	c.step(2.0)
	_expect(c.hp[0] > c.max_hp[0] * 0.5, "a dreamling regains HP on its own")

	# Bonds.
	_expect(Heroes.tier(1) == 0 and Heroes.tier(2) == 1 and Heroes.tier(3) == 2 and Heroes.tier(5) == 3, "bond tiers at 2, 3, 5")
	var humans: Dictionary = Heroes.bonds(PackedInt32Array([0, 3, 6]))
	_expect(humans.tiers[Heroes.HUMAN] == 2 and is_equal_approx(humans.atk, 0.18) and not humans.trio,
		"three humans: 人類同行 tier 2, +18% attack")
	var trio: Dictionary = Heroes.bonds(PackedInt32Array([0, 1, 2]))
	_expect(trio.trio and is_equal_approx(trio.hp, Heroes.TRIO), "one of each form: 三族同行")
	# The opening squad is three humans (人類同行 tier 2); swapping the sword for a dreamling drops it to tier 1.
	var r := Progression.new(3)
	var three: float = r.march_units()[0].atk
	r.march = PackedInt32Array([13, 32, 99])
	var two: float = r.march_units()[0].atk
	_expect(is_equal_approx(three / two, 1.18 / 1.10), "the shield hits %.3fx harder with three humans than two" % (three / two))
	var counts := [0, 0, 0]
	for i: int in Progression.HEROES:
		counts[Heroes.form(i)] += 1
	_expect(counts == [40, 30, 30], "100 heroes: 40 humans, 30 monsters, 30 dreamlings (%s)" % str(counts))

	# Kills and the offline claim.
	var k := Progression.new(5)
	var g0: int = k.gold
	var got: Dictionary = k.march_kill(1)
	_expect(got.gold > 0 and k.gold == g0 + got.gold and k.hero_exp[13] == got.exp and k.hero_exp[0] == 0,
		"a kill pays %d gold and EXP to the squad only" % got.gold)
	var t0: int = 1_800_000_000
	_expect(k.offline_seconds(t0) == 0, "the time away starts counting at the first look")
	var away: Dictionary = k.claim_offline(t0 + 2 * 3600)
	_expect(away.seconds == 7200 and away.gold > 0 and away.kills > 0, "two hours away: %d kills, %d gold" % [away.kills, away.gold])
	_expect(k.offline_seconds(t0 + 2 * 3600 + 30) == 30 and k.claim_offline(t0 + 2 * 3600 + 30).seconds == 0,
		"a short switch away pays nothing")
	_expect(k.offline_seconds(t0 + 50 * 3600) == k.offline_cap_hours() * 3600, "away for days banks only the cap")
	k.keep_marching(t0 + 60 * 3600)
	_expect(k.offline_seconds(t0 + 60 * 3600) == 0, "time the home screen played the march is not paid again")
	var weighted_sim := MarchSim.new(4242, units, 1)
	var reward_units := 0
	for step: int in roundi(Progression.MEASURE_SECONDS / MarchSim.TICK):
		weighted_sim.step(MarchSim.TICK)
		for event: Dictionary in weighted_sim.take_events():
			if event.kind == &"kill":
				reward_units += 3 if event.elite else 1
	var weighted: Dictionary = MarchSim.measure(units, 1, Progression.MEASURE_SECONDS)
	_expect(reward_units > weighted_sim.kills and weighted.reward_units == reward_units,
		"measured rewards include elite triples while raw kills count once")
	var offline_p := Progression.new(3)
	var measured: Dictionary = offline_p.measure_march()
	var paid: Dictionary = offline_p._estimate_march(300)
	_expect(paid.gold == roundi(measured.reward_units_per_sec * 300 * offline_p.kill_gold(measured.stage)),
		"offline gold uses weighted elite rewards")
	_expect(paid.kills == roundi(measured.kills_per_sec * 300), "offline kill ledger remains unweighted")

	var retreat := Progression.new(4242)
	retreat.march_stage = 8
	retreat.cleared = 7
	var before_gold: int = retreat.gold
	var initial_kills: int = retreat.march_kills
	var short: Dictionary = retreat._march_for(300)
	_expect(retreat.march_stage < 8 and short.stage == retreat.march_stage, "offline opening combat resolves retreats")
	_expect(short.gold == retreat.gold - before_gold and short.kills == retreat.march_kills - initial_kills,
		"offline receipt matches actual gold and kills without duplicate payment")
	var resumed := Progression.from_dict(retreat.to_dict().duplicate(true))
	var a_next: Dictionary = retreat._march_for(3600)
	var b_next: Dictionary = resumed._march_for(3600)
	_expect(a_next == b_next, "opening simulation and remaining estimate reproduce after save roundtrip")

	_finish("MARCH TESTS")
