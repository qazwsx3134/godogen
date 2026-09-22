extends SceneTree

const PetModelScript = preload("res://domain/pet_model.gd")
const CareServiceScript = preload("res://domain/care_service.gd")
const TimeServiceScript = preload("res://domain/time_service.gd")
const EvolutionServiceScript = preload("res://domain/evolution_service.gd")

var failures: int = 0


func _init() -> void:
	_test_state_and_pet_schema()
	_test_care_and_noop_denial()
	_test_healing_countdown()
	_test_training_cap_and_cooldown()
	_test_time_high_water_and_protection()
	_test_sleep_freezes_need_events()
	_test_lights_require_schedule_or_fatigue()
	_test_timezone_sleep_schedule()
	_test_equal_sleep_hours_disable_schedule()
	_test_segmented_settlement_and_care_order()
	_test_sickness_and_healing()
	_test_one_mistake_per_need_event()
	_test_need_reset_waits_for_threshold()
	_test_evolution_is_deterministic_and_once()
	_test_archive_is_deep_copy()
	if failures == 0:
		print("CARE TESTS PASS")
		quit(0)
	else:
		push_error("CARE TESTS FAIL: %d" % failures)
		quit(1)


func _test_state_and_pet_schema() -> void:
	var state: Dictionary = PetModelScript.create_state(100)
	_check(int(state.get("schema_version", 0)) == 1, "state schema version")
	_check(int(state.get("last_tick", -1)) == 100, "state last tick")
	_check(state.get("pet", {}) is Dictionary and (state["pet"] as Dictionary).is_empty(), "state starts without pet")
	var pet: Dictionary = PetModelScript.create_pet(100)
	state["pet"] = pet
	for key in ["id", "name", "species", "stage", "born_at", "stage_started_at", "fullness", "mood", "energy", "health", "cleanliness", "weight", "training", "training_count", "wins", "losses", "draws", "battles", "care_mistakes", "sleep_seconds", "behavior", "sleep_reason", "conditions", "lights_on", "poop", "poop_queue", "cooldowns", "care_timers", "need_events", "history", "evolutions"]:
		_check(pet.has(key), "pet field %s" % key)
	_check(PetModelScript.stage_name(pet) == "幼年", "baby stage name")
	var stats: Dictionary = PetModelScript.stats(pet)
	_check(stats.has_all(["attack", "defense", "agility", "max_hp"]), "derived stats schema")
	var ideal: Vector2 = PetModelScript.ideal_weight(pet)
	_check(ideal.x < ideal.y, "ideal weight range")


func _test_care_and_noop_denial() -> void:
	var state: Dictionary = _state_with_pet(0)
	var before: Dictionary = state.duplicate(true)
	var denied: Dictionary = CareServiceScript.perform(state, "unknown", 0)
	_check(not bool(denied.get("ok", true)), "unknown action denied")
	_check(state == before, "denied action is a no-op")
	var meal: Dictionary = CareServiceScript.perform(state, "meal", 0)
	_check(bool(meal.get("ok", false)) and meal.get("animation", "") == "eat", "meal succeeds with eat animation")
	_check((state["pet"] as Dictionary).get("fullness", 0.0) > 70.0, "meal raises fullness")
	var cooldown: String = CareServiceScript.can_act(state, "meal", 1)
	_check(not cooldown.is_empty(), "meal cooldown is explained")
	var pet: Dictionary = state["pet"]
	pet["poop"] = [1]
	pet["cleanliness"] = 60.0
	var clean: Dictionary = CareServiceScript.perform(state, "clean", 1000)
	_check(bool(clean.get("ok", false)), "clean succeeds")
	_check((pet["poop"] as Array).is_empty(), "clean removes poop")


func _test_healing_countdown() -> void:
	var state: Dictionary = _state_with_pet(0)
	var pet: Dictionary = state["pet"]
	var conditions: Dictionary = pet["conditions"]
	conditions["injured"] = true
	pet["health"] = 60.0
	var heal_config: Dictionary = (CareServiceScript.balance().get("care", {}) as Dictionary).get("heal", {})
	var duration: int = int(heal_config.get("injury_seconds", 1800))
	var start: Dictionary = CareServiceScript.perform(state, "heal_injury", 0)
	_check(bool(start.get("ok", false)), "injury care starts")
	_check(not CareServiceScript.can_act(state, "heal_injury", 1).is_empty(), "healing countdown blocks repeat")
	var mid: Dictionary = TimeServiceScript.advance(state, duration / 2)
	_check((pet["conditions"] as Dictionary).get("injured", false), "injury remains during countdown")
	_check(not bool(mid.get("protected", true)), "countdown advance is not protected")
	TimeServiceScript.advance(state, duration)
	_check(not bool((pet["conditions"] as Dictionary).get("injured", true)), "injury clears at countdown end")
	_check(float(pet.get("health", 0.0)) > 60.0, "healing restores health")


func _test_training_cap_and_cooldown() -> void:
	var state: Dictionary = _state_with_pet(0)
	var pet: Dictionary = state["pet"]
	pet["energy"] = 100.0
	var training_config: Dictionary = CareServiceScript.balance().get("training", {})
	var caps: Dictionary = (training_config.get("stage_caps", {}) as Dictionary).get("baby", {})
	var cooldown_seconds: int = int(training_config.get("cooldown_seconds", 1800))
	var quality_gain: int = int((training_config.get("gain_by_quality", {}) as Dictionary).get("3", 3))
	var first: Dictionary = CareServiceScript.train(state, "power", 3, 0)
	_check(bool(first.get("ok", false)) and int(first.get("gain", 0)) == mini(quality_gain, int(caps.get("power", 3))), "quality three training gain")
	var second: Dictionary = CareServiceScript.train(state, "power", 1, cooldown_seconds)
	_check(bool(second.get("ok", false)) and int(second.get("gain", -1)) == 0, "training clamps at baby cap")
	_check(int((pet["training"] as Dictionary).get("power", -1)) == int(caps.get("power", 3)), "training cap remains balance configured")
	_check(int(pet.get("training_count", 0)) == 2, "each completed attempt records training")
	var too_hard: Dictionary = CareServiceScript.train(state, "guard", 3, cooldown_seconds * 2)
	_check(bool(too_hard.get("ok", false)), "second kind can train after cooldown")
	_check(int((pet["training"] as Dictionary).get("guard", -1)) == 3, "second kind is independent")


func _test_time_high_water_and_protection() -> void:
	var state: Dictionary = _state_with_pet(0)
	var pet: Dictionary = state["pet"]
	pet["fullness"] = 100.0
	var first: Dictionary = TimeServiceScript.advance(state, 13 * 3600)
	_check(bool(first.get("protected", false)), "offline over cap enters protection")
	_check(int(first.get("elapsed", 0)) == 12 * 3600, "offline needs cap at twelve hours")
	_check(int(state.get("last_tick", 0)) == 13 * 3600, "high-water advances to requested time")
	_check(bool((pet["conditions"] as Dictionary).get("hibernating", false)), "pet is hibernating")
	var fullness_after_cap: float = float(pet.get("fullness", 0.0))
	var snapshot: Dictionary = state.duplicate(true)
	var rollback: Dictionary = TimeServiceScript.advance(state, 6 * 3600)
	_check(int(rollback.get("elapsed", -1)) == 0, "time rollback has no elapsed time")
	_check(state == snapshot, "time rollback does not mutate state")
	var time_config: Dictionary = CareServiceScript.balance().get("time", {})
	var expected_fullness: float = 100.0 - float(time_config.get("fullness_loss_per_hour", 4.0)) * float(first.get("elapsed", 0)) / float(time_config.get("seconds_per_hour", 3600))
	_check(is_equal_approx(fullness_after_cap, expected_fullness), "needs apply exactly twelve hours before protection")


func _test_sleep_freezes_need_events() -> void:
	var state: Dictionary = _state_with_pet(0)
	var pet: Dictionary = state["pet"]
	pet["fullness"] = 0.0
	pet["cleanliness"] = 0.0
	pet["behavior"] = "sleeping"
	pet["sleep_reason"] = "manual"
	var result: Dictionary = TimeServiceScript.advance(state, 5 * 3600)
	_check(not bool(result.get("protected", true)), "manual sleep within cap")
	_check(int(pet.get("care_mistakes", -1)) == 0, "sleep freezes care mistake clock")
	_check(float(pet.get("fullness", -1.0)) == 0.0, "sleep freezes hunger decay")
	_check(int(pet.get("sleep_seconds", 0)) == 5 * 3600, "sleep duration is tracked")


func _test_lights_require_schedule_or_fatigue() -> void:
	var daytime: Dictionary = _state_with_pet(0)
	var daytime_pet: Dictionary = daytime["pet"]
	var off: Dictionary = CareServiceScript.perform(daytime, "lights", 0)
	_check(bool(off.get("ok", false)) and off.get("animation", "") == "idle", "daytime lights off stays awake when energy is high")
	_check(not bool(daytime_pet.get("lights_on", true)) and str(daytime_pet.get("behavior", "")) == "idle", "daytime lights state is observable without forced sleep")
	var elapsed: Dictionary = TimeServiceScript.advance(daytime, 3600)
	_check(int(elapsed.get("sleep_seconds", -1)) == 0, "dark daytime room does not count as sleep")
	daytime_pet["lights_on"] = true
	daytime_pet["energy"] = float((CareServiceScript.balance().get("time", {}) as Dictionary).get("fatigue_sleep_threshold", 30.0))
	var fatigue_off: Dictionary = CareServiceScript.perform(daytime, "lights", 3600)
	_check(bool(fatigue_off.get("ok", false)) and fatigue_off.get("animation", "") == "sleep", "fatigue allows sleep after lights off")
	_check(str(daytime_pet.get("sleep_reason", "")) == "fatigue", "fatigue sleep reason is observable")
	var scheduled: Dictionary = _state_with_pet(14 * 3600)
	var scheduled_off: Dictionary = CareServiceScript.perform(scheduled, "lights", 14 * 3600)
	_check(bool(scheduled_off.get("ok", false)) and str((scheduled["pet"] as Dictionary).get("sleep_reason", "")) == "schedule", "schedule allows sleep after lights off")


func _test_timezone_sleep_schedule() -> void:
	var state: Dictionary = _state_with_pet(14 * 3600)
	var pet: Dictionary = state["pet"]
	pet["fullness"] = 70.0
	pet["energy"] = 50.0
	var result: Dictionary = TimeServiceScript.advance(state, 16 * 3600)
	_check(not bool(result.get("protected", true)), "scheduled sleep stays inside offline cap")
	_check(int(result.get("sleep_seconds", 0)) == 2 * 3600, "timezone-aware sleep interval is counted")
	_check(float(pet.get("fullness", 0.0)) == 70.0, "scheduled sleep pauses hunger decay")
	_check(is_equal_approx(float(pet.get("energy", 0.0)), 66.0), "scheduled sleep restores energy")
	_check(str(pet.get("behavior", "")) == "sleeping", "scheduled sleep updates behavior")
	var wake: Dictionary = CareServiceScript.perform(state, "wake", 16 * 3600)
	_check(bool(wake.get("ok", false)), "wake exits scheduled sleep")


func _test_equal_sleep_hours_disable_schedule() -> void:
	var state: Dictionary = _state_with_pet(0)
	var settings: Dictionary = state["settings"]
	settings["timezone_offset_minutes"] = 480
	settings["sleep_hour"] = 7
	settings["wake_hour"] = 7
	state["settings"] = settings
	var lights: Dictionary = CareServiceScript.perform(state, "lights", 0)
	_check(bool(lights.get("ok", false)) and lights.get("animation", "") == "idle", "equal sleep and wake hours do not force lights-off sleep")
	var result: Dictionary = TimeServiceScript.advance(state, 3600)
	_check(int(result.get("sleep_seconds", -1)) == 0, "equal sleep and wake hours disable scheduled sleep")
	_check(str((state["pet"] as Dictionary).get("behavior", "")) == "idle", "equal sleep and wake hours keep idle behavior")


func _test_segmented_settlement_and_care_order() -> void:
	var long_state: Dictionary = _state_with_pet(0)
	var short_state: Dictionary = _state_with_pet(0)
	for candidate in [long_state, short_state]:
		var settings: Dictionary = candidate["settings"]
		settings["timezone_offset_minutes"] = 480
		settings["sleep_hour"] = 22
		settings["wake_hour"] = 7
		candidate["settings"] = settings
		var candidate_pet: Dictionary = candidate["pet"]
		candidate_pet["cleanliness"] = 35.0
		candidate_pet["poop_queue"] = [3599]
		candidate["pet"] = candidate_pet

	TimeServiceScript.advance(long_state, 3600)
	for at in range(60, 3601, 60):
		TimeServiceScript.advance(short_state, at)
	var long_pet: Dictionary = long_state["pet"]
	var short_pet: Dictionary = short_state["pet"]
	_check(long_pet.get("poop", []) == short_pet.get("poop", []) and long_pet.get("poop", []) == [3599], "poop boundary is deterministic")
	_check(is_equal_approx(float(long_pet.get("cleanliness", 0.0)), float(short_pet.get("cleanliness", 0.0))), "long and small time settlement agree")
	_check(int(long_pet.get("care_mistakes", -1)) == int(short_pet.get("care_mistakes", -2)) and int(long_pet.get("care_mistakes", 0)) == 0, "poop at interval end does not borrow a grace period")
	var cleanliness_event: Dictionary = (long_pet.get("need_events", {}) as Dictionary).get("cleanliness", {})
	_check(int(cleanliness_event.get("started_at", -1)) == 3599, "poop starts cleanliness event at its event boundary")
	_check(is_equal_approx(float(cleanliness_event.get("awake_seconds", -1.0)), 1.0), "post-poop grace counts only awake seconds")
	_check(_history_has(long_pet, "poop", 3599), "poop materialization is observable in history")

	var care_state: Dictionary = _state_with_pet(0)
	var care_pet: Dictionary = care_state["pet"]
	var care_conditions: Dictionary = care_pet["conditions"]
	care_conditions["sick"] = true
	care_pet["conditions"] = care_conditions
	care_pet["fullness"] = 0.0
	care_pet["health"] = 45.0
	var care_start: Dictionary = CareServiceScript.perform(care_state, "heal_sickness", 0)
	_check(bool(care_start.get("ok", false)), "care order setup starts sickness timer")
	var care_result: Dictionary = TimeServiceScript.advance(care_state, 7200)
	_check(care_result.get("completed_care", []).has("heal_sickness"), "care timer completes at its boundary during segmented advance")
	_check(_history_has(care_pet, "care_complete", 3600), "care completion keeps its true UTC completion time")
	_check(_history_has(care_pet, "care_mistake", 7200), "unresolved need mistake is recorded after elapsed care time")


func _test_sickness_and_healing() -> void:
	var state: Dictionary = _state_with_pet(0)
	var settings: Dictionary = state["settings"]
	settings["timezone_offset_minutes"] = 480
	settings["sleep_hour"] = 22
	settings["wake_hour"] = 7
	state["settings"] = settings
	var pet: Dictionary = state["pet"]
	pet["fullness"] = 0.0
	pet["health"] = 45.0
	var long_result: Dictionary = TimeServiceScript.advance(state, 12 * 3600)
	var conditions: Dictionary = pet["conditions"]
	_check(not bool(long_result.get("protected", true)), "long sickness setup stays inside offline cap")
	_check(bool(conditions.get("sick", false)), "persistent unresolved need enters sickness")
	_check(float(pet.get("health", 100.0)) < 40.0, "unresolved need continuously lowers health")
	_check(int(pet.get("care_mistakes", 0)) == 1, "long sickness records one care mistake per need event")
	_check(_history_has(pet, "sick_start", -1), "sickness transition is observable in history")

	var meal: Dictionary = CareServiceScript.perform(state, "meal", 12 * 3600)
	_check(bool(meal.get("ok", false)), "meal can resolve the need driving sickness")
	var start: Dictionary = CareServiceScript.perform(state, "heal_sickness", 12 * 3600)
	_check(bool(start.get("ok", false)), "sickness care can start after sickness is observed")
	var finished: Dictionary = TimeServiceScript.advance(state, 13 * 3600)
	_check(finished.get("completed_care", []).has("heal_sickness"), "sickness care timer completes")
	_check(not bool((pet["conditions"] as Dictionary).get("sick", true)), "sickness clears after care completion")
	_check(float(pet.get("health", 0.0)) > 40.0, "sickness care restores health above threshold")


func _test_one_mistake_per_need_event() -> void:
	var state: Dictionary = _state_with_pet(0)
	var pet: Dictionary = state["pet"]
	pet["fullness"] = 0.0
	TimeServiceScript.advance(state, 3 * 3600)
	_check(int(pet.get("care_mistakes", 0)) == 1, "first unresolved hunger event records one mistake")
	TimeServiceScript.advance(state, 6 * 3600)
	_check(int(pet.get("care_mistakes", 0)) == 1, "same unresolved event does not repeat mistake")
	var meal: Dictionary = CareServiceScript.perform(state, "meal", 7 * 3600)
	_check(bool(meal.get("ok", false)), "care resolves hunger event")
	pet["fullness"] = 0.0
	TimeServiceScript.advance(state, 10 * 3600)
	_check(int(pet.get("care_mistakes", 0)) == 2, "resolved hunger can create a new event")


func _test_need_reset_waits_for_threshold() -> void:
	var state: Dictionary = _state_with_pet(0)
	var pet: Dictionary = state["pet"]
	pet["fullness"] = 0.0
	pet["need_events"] = {"hunger": {"started_at": 0, "awake_seconds": 7200.0, "mistake_recorded": true}}
	var snack: Dictionary = CareServiceScript.perform(state, "snack", 0)
	_check(bool(snack.get("ok", false)), "small snack is accepted while hungry")
	_check((pet["need_events"] as Dictionary).has("hunger"), "snack below threshold preserves hunger event")
	var meal: Dictionary = CareServiceScript.perform(state, "meal", 1)
	_check(bool(meal.get("ok", false)), "meal can resolve remaining hunger")
	_check(not (pet["need_events"] as Dictionary).has("hunger"), "meal above threshold resets hunger event")

	var clean_state: Dictionary = _state_with_pet(0)
	var clean_pet: Dictionary = clean_state["pet"]
	clean_pet["cleanliness"] = 0.0
	clean_pet["need_events"] = {"cleanliness": {"started_at": 0, "awake_seconds": 7200.0, "mistake_recorded": true}}
	var first_clean: Dictionary = CareServiceScript.perform(clean_state, "clean", 0)
	_check(bool(first_clean.get("ok", false)), "clean action is accepted while dirty")
	_check((clean_pet["need_events"] as Dictionary).has("cleanliness"), "clean below threshold preserves cleanliness event")
	var second_clean: Dictionary = CareServiceScript.perform(clean_state, "clean", 300)
	_check(bool(second_clean.get("ok", false)), "second clean after cooldown is accepted")
	_check(not (clean_pet["need_events"] as Dictionary).has("cleanliness"), "clean above threshold resets cleanliness event")


func _test_evolution_is_deterministic_and_once() -> void:
	var state: Dictionary = _state_with_pet(0)
	var pet: Dictionary = state["pet"]
	pet["training"] = {"power": 4, "guard": 4, "swift": 1}
	pet["training_count"] = 3
	var first: Array = EvolutionServiceScript.check(state, 2 * 3600)
	_check(first.size() == 1 and str(first[0]).contains("成長"), "baby evolves at two hours")
	var second: Array = EvolutionServiceScript.check(state, 26 * 3600)
	_check(second.size() == 1 and str(second[0]).contains("成熟"), "growing evolves after twenty-four hours and three trainings")
	_check(str(pet.get("species", "")) == "ember", "power wins deterministic tie")
	_check((pet["evolutions"] as Array).size() == 2, "evolution transitions recorded once")
	_check(int(pet.get("stage_started_at", -1)) == 26 * 3600, "legacy training data falls back to growing boundary")
	var repeat: Array = EvolutionServiceScript.check(state, 40 * 3600)
	_check(repeat.is_empty(), "mature evolution is not repeated")
	_check(int(state.get("last_tick", 0)) == 0, "evolution check does not consume TimeService high-water")

	var delayed_state: Dictionary = _state_with_pet(0)
	var delayed_pet: Dictionary = delayed_state["pet"]
	delayed_pet["stage"] = "growing"
	delayed_pet["species"] = "bloom"
	delayed_pet["stage_started_at"] = 0
	delayed_pet["training"] = {"power": 3, "guard": 2, "swift": 1}
	delayed_pet["training_count"] = 3
	delayed_pet["history"] = [
		{"type": "train", "kind": "power", "at": 100},
		{"type": "train", "kind": "guard", "at": 200},
		{"type": "train", "kind": "power", "at": 90000},
	]
	var delayed_results: Array = EvolutionServiceScript.check(delayed_state, 100000)
	_check(delayed_results.size() == 1 and delayed_pet.get("stage", "") == "mature", "delayed third training still enables maturity")
	_check(int(delayed_pet.get("stage_started_at", -1)) == 90000, "maturity starts at the later qualifying training timestamp")
	_check(int((delayed_pet["evolutions"] as Array)[0].get("at", -1)) == 90000, "maturity history uses the qualifying training timestamp")


func _test_archive_is_deep_copy() -> void:
	var blocked_state: Dictionary = _state_with_pet(0)
	var blocked_pet: Dictionary = blocked_state["pet"]
	blocked_pet["stage"] = "mature"
	blocked_state["pending_battle"] = {"settled": false, "outcome": "win"}
	var blocked_before: Dictionary = blocked_state.duplicate(true)
	var blocked: Dictionary = EvolutionServiceScript.archive(blocked_state, 10)
	_check(not bool(blocked.get("ok", true)), "archive rejects an unsettled pending battle")
	_check(blocked_state == blocked_before, "blocked archive is a no-op")

	var state: Dictionary = _state_with_pet(0)
	var pet: Dictionary = state["pet"]
	pet["stage"] = "mature"
	pet["history"] = [{"type": "test", "nested": {"value": 1}}]
	var archived_result: Dictionary = EvolutionServiceScript.archive(state, 10)
	_check(bool(archived_result.get("ok", false)), "mature pet archives")
	_check(int(state.get("last_tick", -1)) == 0, "archive does not consume TimeService high-water")
	_check((state["pet"] as Dictionary).is_empty() and (state["egg"] as Dictionary).is_empty(), "archive clears active pet and egg")
	var collection: Array = state["collection"]
	_check(collection.size() == 1, "archive adds collection entry")
	var archived: Dictionary = collection[0]
	_check((archived["history"] as Array).size() == 1, "archive retains history")
	((archived["history"] as Array)[0] as Dictionary)["nested"] = {"value": 99}
	_check(((pet["history"] as Array)[0] as Dictionary)["nested"].get("value", 0) == 1, "archive is deep copied")


func _state_with_pet(now: int) -> Dictionary:
	var state: Dictionary = PetModelScript.create_state(now)
	state["pet"] = PetModelScript.create_pet(now)
	return state


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)


func _history_has(pet: Dictionary, kind: String, at: int) -> bool:
	var history_variant: Variant = pet.get("history", [])
	if not history_variant is Array:
		return false
	var history: Array = history_variant
	for item_variant in history:
		if not item_variant is Dictionary:
			continue
		var item: Dictionary = item_variant
		if str(item.get("type", "")) != kind:
			continue
		if at < 0 or int(item.get("at", -1)) == at:
			return true
	return false
