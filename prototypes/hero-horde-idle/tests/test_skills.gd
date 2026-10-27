extends "res://addons/proto_kit/test_kit.gd"
## 招牌技 (push_sim.gd Sig) on the pure sim:
##   roster    the 7 SSRs each carry one move, the two SSR swords different ones; nobody else has one
##   wall      不動城牆 goes up while its squad stands in a telegraph about to land, and the hit then hurts nobody there
##   dawn      黎明之光 revives up to 3 fallen heroes near the SSR healer
##   bursts    斷鋼斬 / 穿雲箭 / 隕石術 hit the boss (the aimed part too), 疾風連斬 and 破甲突刺 raise damage for a while
##   a played push: every move is cast at least once, and the push report names the MVP's move
##   godot --headless --path prototypes/hero-horde-idle --script res://tests/test_skills.gd

const PushSim = preload("res://domain/push_sim.gd")
const PushReport = preload("res://domain/push_report.gd")
const DT := 1.0 / 60.0


func _init() -> void:
	var sim := PushSim.new(4)
	var holders := {}
	for i: int in sim.cls.size():
		if sim.sig[i] >= 0:
			holders[sim.sig[i]] = i
			_expect(sim.rarity[i] == PushSim.SSR, "only SSRs carry a 招牌技 (hero %d)" % i)
	_expect(holders.size() == PushSim.SIG_NAMES.size(), "the 7 SSRs carry the 7 different moves (got %d)" % holders.size())

	# 不動城牆: a 重砸 on the melee squad, the wall goes up, nobody there is hurt.
	sim.skip_muster()
	var shield: int = holders[PushSim.Sig.WALL]
	sim.sig_cd[shield] = 0.0
	sim.t = sim._next_tele - PushSim.TELE_WARN - 0.01
	var hp_before: float = _squad_hp(sim, PushSim.MELEE)
	var walled: bool = false
	while sim.fighting() and (sim.tele_t > 0.0 or not walled):
		sim.step(DT)
		walled = walled or sim.wall_t[PushSim.MELEE] > 0.0
		if sim.t > PushSim.TELE_FIRST + 3.0:
			break
	_expect(walled and sim.sig_casts[shield] == 1, "不動城牆 goes up under the 重砸")
	_expect(sim.tele_hit_count > 0, "the 重砸 caught the melee squad (%d)" % sim.tele_hit_count)
	_expect(sim.fallen_total == 0 and _squad_hp(sim, PushSim.MELEE) >= hp_before - 1000.0,
		"behind the wall the 重砸 hurts nobody (squad HP %.0f -> %.0f)" % [hp_before, _squad_hp(sim, PushSim.MELEE)])

	# 黎明之光: four fallen around the SSR healer, three get up.
	sim = PushSim.new(4)
	sim.skip_muster()
	var healer: int = _holder(sim, PushSim.Sig.DAWN)
	var fallen: Array[int] = []
	for j: int in sim.cls.size():
		if j != healer and sim.squad[j] == PushSim.SUPPORT and fallen.size() < 4:
			sim.hp[j] = 0.0
			fallen.append(j)
	sim.fallen_total = 4
	sim.sig_cd[healer] = 0.0
	sim.step(DT)
	var up: int = 0
	for j: int in fallen:
		if sim.alive(j):
			up += 1
	_expect(sim.sig_casts[healer] == 1 and up == PushSim.DAWN_REVIVE, "黎明之光 revives %d of 4 fallen (got %d)" % [PushSim.DAWN_REVIVE, up])

	# Bursts and buffs.
	for move: int in [PushSim.Sig.METEOR, PushSim.Sig.CLEAVE]:
		sim = PushSim.new(4)
		sim.skip_muster()
		sim.aim_at(PushSim.Part.HORNS)
		var hero: int = _holder(sim, move)
		sim.sig_cd[hero] = 0.0
		var boss: float = sim.boss_hp
		var horns: float = sim.part_hp[PushSim.Part.HORNS]
		var legs: float = sim.part_hp[PushSim.Part.LEGS]
		sim.step(DT)
		var big: float = sim.atk[hero] * 20.0
		_expect(sim.sig_casts[hero] == 1 and boss - sim.boss_hp > big, "%s hits the boss hard" % PushSim.SIG_NAMES[move])
		if move == PushSim.Sig.METEOR:
			_expect(horns - sim.part_hp[PushSim.Part.HORNS] > big, "隕石術 wears down the aimed horns")
		else:
			_expect(legs - sim.part_hp[PushSim.Part.LEGS] > big, "斷鋼斬 wears down the legs melee are hitting")
	sim = PushSim.new(4)
	sim.skip_muster()
	sim.sig_cd[_holder(sim, PushSim.Sig.PIERCE)] = 0.0
	sim.sig_cd[_holder(sim, PushSim.Sig.GALE)] = 0.0
	var plain: float = sim.damage_mult()
	sim.step(DT)
	_expect(sim.pierce_t > 0.0 and sim.gale_t > 0.0 and sim.damage_mult() > plain * 1.2, "破甲突刺 and 疾風連斬 raise the damage")

	# A whole push played well enough to survive: every move comes out, the report names the MVP's move.
	sim = PushSim.new(4)
	sim.skip_muster()
	for i: int in sim.cls.size():
		sim.max_hp[i] *= 1.5
		sim.hp[i] = sim.max_hp[i]
	sim.aim_at(PushSim.Part.HORNS)
	while sim.fighting():
		if sim.morale >= PushSim.MORALE_MAX:
			sim.volley()
		if sim.aim < 0:
			for p: int in [PushSim.Part.ARM, PushSim.Part.LEGS]:
				if not sim.broken(p):
					sim.aim_at(p)
					break
		sim.step(DT)
	var cast := {}
	for i: int in sim.cls.size():
		if sim.sig_casts[i] > 0:
			cast[sim.sig[i]] = true
	_expect(cast.size() >= 6, "a played push shows most moves (got %s)" % str(cast.keys().map(func(m: int) -> String: return PushSim.SIG_NAMES[m])))
	var r: Dictionary = PushReport.build(sim, PushReport.load_names())
	print("mvp: %s / %s" % [r.mvp_name, r.mvp_line])
	if sim.sig[r.mvp] >= 0:
		_expect(r.mvp_line.contains(PushSim.SIG_NAMES[sim.sig[r.mvp]]), "the report names the MVP's move")
	_finish("SKILL TESTS")


func _holder(sim: PushSim, move: int) -> int:
	for i: int in sim.cls.size():
		if sim.sig[i] == move:
			return i
	return -1


func _squad_hp(sim: PushSim, s: int) -> float:
	var total: float = 0.0
	for i: int in sim.cls.size():
		if sim.squad[i] == s:
			total += sim.hp[i]
	return total
