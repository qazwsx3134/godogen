extends "res://addons/proto_kit/test_kit.gd"
## 推王戰報 (domain/push_report.gd) on real pushes of the pure sim:
##   wiped    nobody touches anything -> every fall booked to a cause, boards sorted, diagnosis says train 盾 or 補
##   timeout  heroes cannot die, the boss cannot either -> no falls, diagnosis says damage is short and names a damage class
##   won      the boss is nearly dead -> no diagnosis
##   parts    the ranged squad aims at the horns -> the report lists them broken
## and the bookkeeping matches the sim: the 輸出 board adds up to the damage the boss took.
##   godot --headless --path prototypes/hero-horde-idle --script res://tests/test_report.gd

const PushSim = preload("res://domain/push_sim.gd")
const PushReport = preload("res://domain/push_report.gd")
const DT := 1.0 / 60.0


func _init() -> void:
	var names: PackedStringArray = PushReport.load_names()
	var unique := {}
	for n: String in names:
		unique[n] = true
	_expect(names.size() == 100 and unique.size() == 100, "100 distinct hero names (got %d, %d distinct)" % [names.size(), unique.size()])

	var wiped := _play(3, func(_s: PushSim) -> void: pass)
	var r: Dictionary = PushReport.build(wiped, names)
	print("wiped: mvp %s / %s | causes %s | %s" % [r.mvp_name, r.mvp_line, str(r.causes), " / ".join(r.diagnosis)])
	_expect(not r.won and wiped.living() == 0, "wiped: lost with nobody standing")
	_expect(r.fallen == wiped.cls.size(), "wiped: every hero booked as fallen (got %d)" % r.fallen)
	_expect(r.causes.reduce(func(a: int, b: int) -> int: return a + b, 0) == r.fallen, "wiped: causes add up to the fallen")
	_expect(r.train == PushSim.SHIELD or r.train == PushSim.HEALER, "wiped: trains 盾 or 補 (got %d)" % r.train)
	_expect(not r.diagnosis.is_empty() and r.worst_squad >= 0, "wiped: has a diagnosis and a worst squad")
	_expect(absf(_sum(wiped.stat_dealt) - wiped.damage_dealt) <= wiped.damage_dealt * 0.001,
		"wiped: 輸出 adds up to the boss's damage (%.0f vs %.0f)" % [_sum(wiped.stat_dealt), wiped.damage_dealt])
	_expect(_sum(wiped.stat_healed) > 0.0 and _sum(wiped.stat_taken) > 0.0, "wiped: heals and damage taken are booked")
	for board: Dictionary in r.boards:
		var rows: Array = board.rows
		_expect(rows.size() == PushReport.TOP, "wiped: board %s has %d rows" % [board.title, rows.size()])
	var dealt: Array = r.boards[0].rows
	_expect(wiped.stat_dealt[dealt[0].hero] >= wiped.stat_dealt[dealt[1].hero], "wiped: 輸出 board is sorted")

	var timeout := _play(3, func(s: PushSim) -> void:
		for i: int in s.cls.size():
			s.hp[i] = 1.0e9
			s.max_hp[i] = 1.0e9
		s.boss_hp = 1.0e9)
	r = PushReport.build(timeout, names)
	print("timeout: %s" % " / ".join(r.diagnosis))
	_expect(not r.won and timeout.living() > 0 and r.fallen == 0, "timeout: lost on time, nobody fell")
	_expect(r.train in [PushSim.SWORD, PushSim.SPEAR, PushSim.BOW, PushSim.MAGE], "timeout: trains a damage class")
	_expect(" ".join(r.diagnosis).contains("輸出不夠"), "timeout: says damage is short")
	_expect(" ".join(r.diagnosis).contains("角"), "timeout: nobody aimed, so it suggests breaking the horns")

	var won := _play(3, func(s: PushSim) -> void: s.boss_hp = 500.0)
	r = PushReport.build(won, names)
	_expect(r.won and r.diagnosis.is_empty(), "won: no diagnosis")

	var aimed := _play(3, func(s: PushSim) -> void:
		for i: int in s.cls.size():
			s.hp[i] = 1.0e9
			s.max_hp[i] = 1.0e9
		s.aim_at(PushSim.Part.HORNS))
	r = PushReport.build(aimed, names)
	_expect("角" in r.broken, "parts: horns broken when aimed at (got %s)" % str(r.broken))
	_finish("REPORT TESTS")


func _play(seed_value: int, setup: Callable) -> PushSim:
	var sim := PushSim.new(seed_value)
	sim.skip_muster()
	setup.call(sim)
	while sim.fighting():
		sim.step(DT)
	return sim


func _sum(a: PackedFloat32Array) -> float:
	var s: float = 0.0
	for v: float in a:
		s += v
	return s
