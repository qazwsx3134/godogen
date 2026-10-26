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
	test_save_invalid_main_loads_backup_and_keeps_it()
	test_save_tombstoned_run_never_loads_alive()
	test_death_journal_recovers_profile_after_interrupted_main()
	test_schema_rejects_nested_damage()
	test_atomic_recovery_and_rejected_bytes()
	test_preferences_round_trip()
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


func test_save_invalid_main_loads_backup_and_keeps_it() -> void:
	# Arrange: a good save in .bak, then a main file from a newer version, then one with an empty run
	var s := _fresh()
	s.save({"profile": {"warehouse_gold": 1}, "run": null})
	s.save({"profile": {"warehouse_gold": 2}, "run": null})
	for bad: Dictionary in [{"schema": 999, "profile": {"warehouse_gold": 9}, "run": null}, {"schema": 1, "profile": {}, "run": {}}]:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(JSON.stringify(bad))
		f.close()
		# Act: load, then save over it the way field.load_game does
		var loaded := s.load_state()
		s.save({"profile": loaded.profile, "run": null})
		# Assert
		_expect(int(loaded.profile.warehouse_gold) == 1, "invalid main (schema %s): the backup loads" % bad.schema)
		_expect(int(s.load_state().profile.warehouse_gold) == 1 and int(JSON.parse_string(
			FileAccess.get_file_as_string(PATH + ".bak")).profile.warehouse_gold) == 1, "invalid main: the good backup survives the next save")
		_expect(JSON.parse_string(FileAccess.get_file_as_string(PATH + ".rejected")).hash() == JSON.parse_string(JSON.stringify(bad)).hash(),
			"invalid main: the rejected file is kept aside")
		f = FileAccess.open(PATH, FileAccess.WRITE)  # put the good backup back as main for the next case
		f.store_string(FileAccess.get_file_as_string(PATH + ".bak"))
		f.close()


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


func test_death_journal_recovers_profile_after_interrupted_main() -> void:
	var service := _fresh()
	var run := Run.new(tuning, "g1", 1)
	var before := Profile.new()
	before.warehouse_gold = 42
	service.save({"profile": before.to_dict(), "run": run.to_dict()})
	var after := Profile.from_dict(before.to_dict().duplicate(true))
	after.record_death(run, "守門者")
	_expect(service.mark_dead(run.id, after.to_dict()) == OK, "journal: death snapshot commits")
	# Simulate termination before the main save. A fresh service must recover both sides of the death.
	var restored := SaveService.new(PATH).load_state()
	_expect(restored.run == null and int(restored.profile.generation) == 2,
		"journal: interrupted main cannot resurrect or reuse the dead generation")
	_expect(restored.profile.memorial.size() == 1 and int(restored.profile.warehouse_gold) == 42,
		"journal: memorial and warehouse recover together")
	service.save({"profile": restored.profile, "run": Run.new(tuning, "g2", 2).to_dict()})
	_expect(service.load_state().run.id == "g2", "journal: next generation is not tombstoned")


func test_schema_rejects_nested_damage() -> void:
	var service := _fresh()
	var good := {"schema": 1, "profile": Profile.new().to_dict(), "run": Run.new(tuning, "g1").to_dict()}
	for field: String in ["stacks", "gear", "equipped", "quests", "learned", "slots", "chains", "receipts", "trip"]:
		var bad := good.duplicate(true)
		bad.run[field] = "broken"
		_expect(not service.valid(bad), "schema: rejects wrong container " + field)
	var bad := good.duplicate(true)
	bad.run.quests[bad.run.quests.keys()[0]].progress = []
	_expect(not service.valid(bad), "schema: rejects nested quest type")
	bad = good.duplicate(true)
	bad.run.gear[bad.run.gear.keys()[0]].template = "unknown-template"
	_expect(not service.valid(bad), "schema: rejects unknown equipment")
	bad = good.duplicate(true)
	bad.profile.warehouse_items = []
	_expect(not service.valid(bad), "schema: rejects malformed warehouse")
	_expect(service.save({"profile": {}, "run": {}}) == ERR_INVALID_DATA,
		"schema: invalid runtime state is not written")


func test_atomic_recovery_and_rejected_bytes() -> void:
	var service := _fresh()
	var state := {"profile": {"warehouse_gold": 37}, "run": null}
	service.save(state)
	DirAccess.rename_absolute(PATH, PATH + ".old")
	_expect(service.load_state().profile.warehouse_gold == 37 and service.load_source.ends_with(".old"),
		"atomic: recovers interrupted fallback rename")
	service.save(state)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("not valid json")
	file.close()
	_expect(service.save(state) == OK and FileAccess.get_file_as_string(PATH + ".rejected") == "not valid json",
		"recovery: preserves corrupt original bytes before replacement")


func test_preferences_round_trip() -> void:
	var profile := Profile.new()
	profile.settings.screen_shake = false
	profile.settings.auto_retreat = false
	var service := _fresh()
	service.save({"profile": profile.to_dict(), "run": null})
	var restored := Profile.from_dict(service.load_state().profile)
	_expect(not restored.settings.screen_shake and not restored.settings.auto_retreat,
		"settings: account preferences survive load")
	var legacy := Profile.from_dict({"settings": {"screen_shake": "false"}})
	_expect(legacy.settings.screen_shake and legacy.settings.auto_retreat, "settings: malformed or absent values keep defaults")
