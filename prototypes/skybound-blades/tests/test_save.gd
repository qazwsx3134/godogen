extends "res://addons/proto_kit/test_kit.gd"
## Save, backup, tombstone and the warehouse rules (domain/save_service.gd, domain/profile.gd).
## Writes only under user://test_saves/ and removes it afterwards.

const Tuning = preload("res://domain/tuning.gd")
const Run = preload("res://domain/run.gd")
const Profile = preload("res://domain/profile.gd")
const SaveService = preload("res://domain/save_service.gd")

const PATH := "user://test_saves/save.json"

var tuning: Tuning


func _init() -> void:
	tuning = Tuning.load_default()
	test_save_round_trip_keeps_run_and_profile()
	test_save_corrupt_main_falls_back_to_backup()
	test_save_tombstoned_run_never_loads_alive()
	test_save_warehouse_rules()
	SaveService.new(PATH).erase()
	DirAccess.remove_absolute("user://test_saves")
	_finish("SAVE")


func _fresh() -> SaveService:
	var s := SaveService.new(PATH)
	s.erase()
	return s


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	return rng


func test_save_round_trip_keeps_run_and_profile() -> void:
	var s := _fresh()
	var run := Run.new(tuning, "g1")
	for i in 6:
		run.record_kill(run.next_kill_id(), "briar_boar", 2, _rng())
	var sword := run.make_gear("novice_sword", "rare")
	run.equip("leader", sword.id)
	run.note_damage("leader:cleave", "", 120.0)
	run.note_warning(true)
	var profile := Profile.new()
	profile.warehouse_gold = 40
	_expect(s.save({"profile": profile.to_dict(), "run": run.to_dict()}) == OK, "round trip: save ok")
	var doc := s.load_state()
	var back: Run = Run.from_dict(tuning, doc.run)
	_expect(back.level == run.level and is_equal_approx(back.experience, run.experience) and back.gold == run.gold,
		"round trip: growth and gold")
	_expect(back.equipped.leader.weapon == sword.id and back.member_stats("leader").attack == run.member_stats("leader").attack,
		"round trip: worn gear and stats")
	_expect(back.receipts.size() == 6 and back.record_kill(run.receipts.keys()[0], "briar_boar", 2, _rng()).is_empty(),
		"round trip: kill receipts still block replays")
	_expect(back.next_kill_id() == run.next_kill_id(), "round trip: id sequence continues")
	_expect(is_equal_approx(float(back.trip.dealt["leader:cleave"]), 120.0) and int(back.trip.warned.dodged) == 1,
		"round trip: trip damage and warning stats")
	var old_trip := Run.from_dict(tuning, doc.run)
	old_trip.trip = {"kills": 0, "exp": 0.0, "gold": 0, "items": {}, "gear": [], "used": {}}  # saved before the stats
	old_trip.note_damage("leader:attack", "leader", 5.0)
	_expect(float(old_trip.trip.dealt["leader:attack"]) == 5.0, "round trip: a trip saved before the stats still records")
	_expect(Profile.from_dict(doc.profile).warehouse_gold == 40, "round trip: warehouse")


func test_save_corrupt_main_falls_back_to_backup() -> void:
	var s := _fresh()
	s.save({"profile": {"warehouse_gold": 1}, "run": null})
	s.save({"profile": {"warehouse_gold": 2}, "run": null})
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	_expect(int(s.load_state().profile.warehouse_gold) == 1, "backup: a corrupt main file loads the last good copy")


func test_save_tombstoned_run_never_loads_alive() -> void:
	var s := _fresh()
	var run := Run.new(tuning, "g7")
	s.save({"profile": {}, "run": run.to_dict()})
	_expect(s.mark_dead("g7") == OK, "tombstone: written")
	_expect(s.load_state().run == null, "tombstone: the dead run does not load")
	s.save({"profile": {}, "run": run.to_dict()})  # an old copy of the dead run written again
	_expect(s.load_state().run == null, "tombstone: even a re-saved copy stays dead")


func test_save_warehouse_rules() -> void:
	var run := Run.new(tuning, "g2")
	var profile := Profile.new()
	_expect(not profile.deposit_item(run, "tonic_small", 1), "warehouse: issued supplies cannot be stored")
	run.add_item("green_core", 3)
	_expect(profile.deposit_item(run, "green_core", 2) and run.count("green_core") == 1, "warehouse: materials stored")
	var worn: String = run.equipped.leader.weapon
	_expect(not profile.deposit_gear(run, worn), "warehouse: worn gear cannot be stored")
	var spare := run.make_gear("cloth_cap", "fine")
	_expect(profile.deposit_gear(run, spare.id) and not run.gear.has(spare.id), "warehouse: bag gear stored")
	run.gold = 50
	_expect(profile.deposit_gold(run, 30) and run.gold == 20 and profile.warehouse_gold == 30, "warehouse: gold stored")
	var next := Run.new(tuning, "g3", 2)
	_expect(profile.withdraw_gear(next, spare.id) and next.gear.has(spare.id), "warehouse: the next generation takes it out")
