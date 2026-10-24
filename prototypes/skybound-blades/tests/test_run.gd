extends "res://addons/proto_kit/test_kit.gd"
## The Run (domain/run.gd): rewards pay once, quests re-check and hand in atomically, issued
## supplies stay out of the economy, gear instances never touch their template.
## Run: prototypes/godot-kit/tools/run_tests.sh prototypes/skybound-blades run

const Tuning = preload("res://domain/tuning.gd")
const Run = preload("res://domain/run.gd")

var tuning: Tuning


func _init() -> void:
	tuning = Tuning.load_default()
	test_run_starts_with_issued_kit_and_gear()
	test_run_kill_pays_once()
	test_run_kill_counts_toward_quests()
	test_run_collect_quest_rechecks_and_hands_in_once()
	test_run_issued_supplies_cannot_be_sold_or_stored()
	test_run_gear_bonus_is_template_times_quality()
	test_run_equip_moves_gear_and_changes_stats()
	test_run_trip_tracks_the_outing()
	_finish("RUN")


func _run() -> Run:
	return Run.new(tuning, "r1")


func _rng(seed: int = 5) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


func test_run_starts_with_issued_kit_and_gear() -> void:
	var r := _run()
	_expect(r.count("tonic_small") == 5 and r.free_count("tonic_small") == 0, "start: 5 issued tonics, none free")
	_expect(r.equipped_ids("leader").size() == 2 and r.equipped_ids("guardian").size() == 3, "start: initial gear worn")
	var base: Dictionary = tuning.member_stats("leader", 1)
	var worn: Dictionary = r.member_stats("leader")
	_expect(is_equal_approx(base.attack, worn.attack) and is_equal_approx(base.max_hp, worn.max_hp),
		"start: worn plain gear equals the template stats")


func test_run_kill_pays_once() -> void:
	var r := _run()
	var kid := r.next_kill_id()
	var first := r.record_kill(kid, "meadow_slime", 1, _rng())
	var gold := r.gold
	var again := r.record_kill(kid, "meadow_slime", 1, _rng())
	_expect(not first.is_empty() and again.is_empty(), "kill: a replayed kill id pays nothing")
	_expect(r.gold == gold and r.kills == 1, "kill: gold and kill count unchanged by the replay")
	_expect(r.next_kill_id() != kid, "kill: ids are unique")


func test_run_kill_counts_toward_quests() -> void:
	var r := _run()
	for i in 7:
		r.record_kill(r.next_kill_id(), "meadow_slime", 1, _rng(i))
	_expect(r.quest_progress("hunt_1_0") == 5, "quest: hunt progress caps at its count")
	_expect(r.quest_progress("hunt_1_1") == 0, "quest: other targets do not count")
	var paid := r.claim("hunt_1_0", 0.0)
	_expect(int(paid.gold) == 30 and r.quests.hunt_1_0.progress == 0, "quest: claim pays and resets")
	_expect(r.claim("hunt_1_0", 1000.0).is_empty(), "quest: repeat waits for its cooldown")
	r.record_kill(r.next_kill_id(), "meadow_slime", 1, _rng(99), 1000.0)
	_expect(r.quest_progress("hunt_1_0") == 0, "quest: kills during the cooldown do not count")


func test_run_collect_quest_rechecks_and_hands_in_once() -> void:
	var r := _run()
	r.add_item("green_core", 4)
	_expect(r.claim("gather_1", 0.0).is_empty(), "collect: 4 of 5 is not enough")
	r.add_item("green_core", 2)
	var paid := r.claim("gather_1", 0.0)
	_expect(not paid.is_empty() and r.count("green_core") == 1, "collect: exactly 5 handed in")
	_expect(r.claim("gather_1", 0.0).is_empty(), "collect: a one-time quest cannot be claimed twice")


func test_run_issued_supplies_cannot_be_sold_or_stored() -> void:
	var r := _run()
	_expect(not r.take_free("tonic_small", 1), "issued: issued tonics cannot leave the run")
	r.add_item("tonic_small", 2)
	_expect(r.free_count("tonic_small") == 2, "issued: bought tonics are free stock")
	_expect(r.consume("tonic_small", 1) and r.free_count("tonic_small") == 2, "issued: drinking uses issued stock first")


func test_run_gear_bonus_is_template_times_quality() -> void:
	var r := _run()
	var rare := r.make_gear("novice_sword", "rare")
	_expect(is_equal_approx(float(rare.bonus.attack), roundf(6 * 1.3)), "gear: rare sword attack 6 x 1.3 rounded")
	var chain := r.make_gear("chain_mail", "fine")
	_expect(is_equal_approx(float(chain.bonus.agility), -1.0), "gear: negative stats are not scaled by quality")
	_expect(int(tuning.equipment.novice_sword.bonus.attack) == 6, "gear: the template is untouched")


func test_run_equip_moves_gear_and_changes_stats() -> void:
	var r := _run()
	var before: float = r.member_stats("leader").attack
	var sword := r.make_gear("novice_sword", "rare")
	var replaced := r.equip("leader", sword.id)
	_expect(replaced != "" and r.holder_of(replaced) == "", "equip: the old weapon returns to the bag")
	_expect(r.member_stats("leader").attack > before, "equip: a better weapon raises attack")
	r.equip("support", sword.id)
	_expect(r.holder_of(sword.id) == "support" and not r.equipped.leader.has("weapon"), "equip: one instance, one wearer")


func test_run_trip_tracks_the_outing() -> void:
	var r := _run()
	r.record_kill(r.next_kill_id(), "briar_boar", 2, _rng(3))
	r.consume("tonic_small")
	_expect(int(r.trip.kills) == 1 and int(r.trip.used.tonic_small) == 1 and int(r.trip.gold) == 4,
		"trip: kills, gold and supplies used are summed")
	r.reset_trip()
	_expect(int(r.trip.kills) == 0, "trip: resets on return")
