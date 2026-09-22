extends SceneTree

const StepProviderScript = preload("res://domain/step_provider.gd")
const MockStepProviderScript = preload("res://domain/mock_step_provider.gd")
const StepServiceScript = preload("res://domain/step_service.gd")
const HatchServiceScript = preload("res://domain/hatch_service.gd")
const SaveServiceScript = preload("res://domain/save_service.gd")
const PetModelScript = preload("res://domain/pet_model.gd")
const CareServiceScript = preload("res://domain/care_service.gd")

class ResponseProvider extends "res://domain/step_provider.gd":
	var response: Dictionary = {}

	func set_response(value: Dictionary) -> void:
		response = value.duplicate(true)

	func query(_state: Dictionary, _from_utc: int, _to_utc: int) -> Dictionary:
		return response.duplicate(true)

var failures: int = 0

func _init() -> void:
	_run_tests()
	if failures == 0:
		print("test_steps_save: PASS")
		quit(0)
	else:
		push_error("test_steps_save: %d failure(s)" % failures)
		quit(1)

func _run_tests() -> void:
	_test_base_provider_is_unavailable()
	_test_step_buckets_and_source_rules()
	_test_invalid_partial_and_alias_coverage()
	_test_hatch_transition_when_pet_model_exists()
	_test_atomic_save_backup_and_recovery()
	_test_nested_schema_backup_recovery()
	_test_weight_is_not_a_need_percentage()

func _test_weight_is_not_a_need_percentage() -> void:
	var state: Dictionary = PetModelScript.create_state(1000)
	state.pet = PetModelScript.create_pet(1000)
	state.pet.weight = 99.9
	state.pet.fullness = 30.0
	var result: Dictionary = CareServiceScript.perform(state, "meal", 1000)
	var save_path: String = "/tmp/pixel-monster-test-weight-%d.json" % OS.get_process_id()
	_expect(bool(result.ok) and float(state.pet.weight) > 100.0, "meal can increase physical weight beyond a need percentage")
	_expect(SaveServiceScript.save(state, save_path) == OK, "valid heavy individual can still save after feeding")
	_expect(is_equal_approx(float(SaveServiceScript.load_state(save_path).pet.weight), float(state.pet.weight)), "weight survives reload without a percentage cap")
	state.pet.weight = -1.0
	_expect(not SaveServiceScript.validate_state(state), "negative weight is invalid")
	state.pet.weight = INF
	_expect(not SaveServiceScript.validate_state(state), "infinite weight is invalid")
	_cleanup_save_files(save_path)

func _test_base_provider_is_unavailable() -> void:
	var state: Dictionary = _new_state()
	var provider = StepProviderScript.new()
	var result: Dictionary = provider.query(state, 100, 200)
	_expect(String(result.get("status", "")) == "unavailable", "base provider status is unavailable")
	_expect(String(result.get("source", "")) == "native", "base provider identifies native source")
	_expect(result.get("today_steps", 0) == null, "unavailable today_steps stays null")
	_expect((result.get("buckets", []) as Array).is_empty(), "unavailable provider has no fabricated buckets")

func _test_step_buckets_and_source_rules() -> void:
	var state: Dictionary = _new_state()
	var provider = MockStepProviderScript.new()
	var started_at: int = 1_000
	var start_result: Dictionary = HatchServiceScript.start_egg(state, started_at, "starter")
	_expect(bool(start_result.get("ok", false)), "starter egg starts")

	provider.add_steps(state, 100, started_at + 1)
	var first: Dictionary = StepServiceScript.synchronize(state, provider, started_at + 10)
	_expect(bool(first.get("ok", false)), "first mock sync succeeds")
	_expect(int(first.get("credited_steps", -1)) == 100, "first bucket credits 100")
	_expect(int(first.get("credited_delta", -1)) == 100, "first bucket delta is 100")
	_expect(int(first.get("today_steps", -1)) == 100, "daily total is separate and known")
	_expect(first.has("status") and first.has("today_steps") and first.has("last_sync"), "sync result carries UI status fields")

	provider.set_mode(state, "duplicate", started_at + 20)
	provider.add_steps(state, 50, started_at + 21)
	var duplicate: Dictionary = StepServiceScript.synchronize(state, provider, started_at + 30)
	_expect(bool(duplicate.get("ok", false)), "duplicate response sync succeeds")
	_expect(int(duplicate.get("credited_steps", -1)) == 150, "duplicate buckets are not added twice")
	_expect(int(duplicate.get("credited_delta", -1)) == 50, "duplicate response contributes one delta")
	var repeated: Dictionary = StepServiceScript.synchronize(state, provider, started_at + 30)
	_expect(int(repeated.get("credited_steps", -1)) == 150, "repeating same response is idempotent")
	_expect(int(repeated.get("credited_delta", -1)) == 0, "repeating same response has zero delta")

	provider.set_mode(state, "delayed", started_at + 40)
	provider.add_steps(state, 20, started_at + 41)
	var delayed: Dictionary = StepServiceScript.synchronize(state, provider, started_at + 42)
	_expect(String(delayed.get("status", "")) == "delayed", "delayed response is visible")
	_expect(delayed.get("today_steps", 0) == null, "delayed response does not claim zero")
	_expect(int(delayed.get("credited_steps", -1)) == 150, "delayed response does not credit early")
	var late: Dictionary = StepServiceScript.synchronize(state, provider, started_at + 43)
	_expect(bool(late.get("ok", false)), "late requery succeeds")
	_expect(int(late.get("credited_steps", -1)) == 170, "late data is reconciled by bucket delta")

	var next_day: int = started_at + 86400 + 10
	provider.add_steps(state, 10, next_day)
	var cross_day: Dictionary = StepServiceScript.synchronize(state, provider, next_day + 10)
	_expect(int(cross_day.get("credited_steps", -1)) == 180, "cross-day progress does not reset")
	var ledger: Dictionary = state.get("step_ledger", {})
	var ledger_buckets: Dictionary = ledger.get("buckets", {})
	_expect(ledger_buckets.size() >= 2, "cross-day observations persist as separate buckets")

	provider.set_mode(state, "reboot", next_day + 20)
	provider.add_steps(state, 25, next_day + 21)
	var after_reboot: Dictionary = StepServiceScript.synchronize(state, provider, next_day + 30)
	_expect(int(after_reboot.get("credited_steps", -1)) == 205, "reboot epoch rebuilds baseline without negative credit")
	_expect(int(after_reboot.get("credited_delta", -1)) == 25, "post-reboot steps credit once")

	# The old egg is cleared the same way the archive flow clears it.  Its
	# ledger is deliberately left in the state to prove start_egg resets the
	# active ledger and does not carry a remainder into the next egg.
	state["egg"] = {}
	state["pet"] = {}
	var new_start: int = next_day + 100
	var new_egg: Dictionary = HatchServiceScript.start_egg(state, new_start, "starter")
	_expect(bool(new_egg.get("ok", false)), "new egg starts after old egg is cleared")
	provider.add_steps(state, 99, new_start - 1)
	provider.add_steps(state, 7, new_start + 1)
	var new_sync: Dictionary = StepServiceScript.synchronize(state, provider, new_start + 2)
	_expect(int(new_sync.get("credited_steps", -1)) == 7, "new egg excludes steps before its baseline")

	# A single provider response may exceed the target. The excess is capped
	# and the next egg starts at zero rather than inheriting a remainder.
	state["egg"] = {}
	state["pet"] = {}
	var capped_start: int = new_start + 100
	var capped_egg: Dictionary = HatchServiceScript.start_egg(state, capped_start, "starter")
	_expect(bool(capped_egg.get("ok", false)), "capped egg starts")
	provider.set_mode(state, "normal", capped_start)
	provider.add_steps(state, 1000, capped_start + 1)
	var capped_sync: Dictionary = StepServiceScript.synchronize(state, provider, capped_start + 2)
	_expect(int(capped_sync.get("credited_steps", -1)) == 500, "egg progress caps at target")
	state["egg"] = {}
	state["pet"] = {}
	var after_cap_start: int = capped_start + 100
	var after_cap: Dictionary = HatchServiceScript.start_egg(state, after_cap_start, "starter")
	_expect(bool(after_cap.get("ok", false)), "egg after capped egg starts")
	_expect(int((state.get("egg", {}) as Dictionary).get("credited_steps", -1)) == 0, "capped remainder does not transfer")

	provider.set_mode(state, "unavailable", after_cap_start)
	var unknown: Dictionary = StepServiceScript.synchronize(state, provider, after_cap_start + 1)
	_expect(String(unknown.get("status", "")) == "unavailable", "unavailable mode is visible")
	_expect(unknown.get("today_steps", 0) == null, "unknown is not displayed as zero")
	_expect(int(unknown.get("credited_steps", -1)) == 0, "unavailable mode does not credit")

	# A known source is locked to the egg; manually presenting another source
	# is the smallest deterministic test of the no-source-addition rule.
	var active_ledger: Dictionary = state.get("step_ledger", {})
	active_ledger["source"] = "mock"
	state["step_ledger"] = active_ledger
	var conflicting_provider = StepProviderScript.new()
	var conflict: Dictionary = StepServiceScript.synchronize(state, conflicting_provider, after_cap_start + 2)
	_expect(String(conflict.get("status", "")) == "source_conflict", "different source cannot be added")

func _test_invalid_partial_and_alias_coverage() -> void:
	var before_state: Dictionary = _new_state()
	var before_start: int = 10_000
	var before_egg: Dictionary = HatchServiceScript.start_egg(before_state, before_start, "starter")
	_expect(bool(before_egg.get("ok", false)), "invalid bucket test egg starts")
	var provider = ResponseProvider.new()
	provider.set_response({
		"source": "coverage-test",
		"status": "ok",
		"coverage": {
			"from_utc": before_start,
			"to_utc": before_start + 100,
			"complete": true,
			"known": true,
		},
		"buckets": [{
			"id": "before-egg",
			"from_utc": before_start - 1,
			"to_utc": before_start,
			"steps": 20,
			"complete": true,
		}],
		"today_steps": 20,
		"message": "測試",
	})
	var before_result: Dictionary = StepServiceScript.synchronize(before_state, provider, before_start + 100)
	_expect(String(before_result.get("status", "")) == "invalid", "bucket before egg is rejected")
	_expect(int(before_result.get("credited_steps", -1)) == 0, "invalid pre-egg bucket credits nothing")

	var partial_state: Dictionary = _new_state()
	var partial_start: int = 11_000
	var partial_egg: Dictionary = HatchServiceScript.start_egg(partial_state, partial_start, "starter")
	_expect(bool(partial_egg.get("ok", false)), "partial coverage test egg starts")
	provider.set_response({
		"source": "coverage-test",
		"status": "ok",
		# The provider incorrectly claims complete, but this range stops one
		# second before the requested query end.
		"coverage": {
			"from_utc": partial_start,
			"to_utc": partial_start + 99,
			"complete": true,
			"known": true,
		},
		"buckets": [{
			"id": "partial-known",
			"from_utc": partial_start,
			"to_utc": partial_start + 99,
			"steps": 5,
			"complete": true,
		}],
		"today_steps": 5,
		"message": "測試",
	})
	var partial_result: Dictionary = StepServiceScript.synchronize(partial_state, provider, partial_start + 100)
	_expect(not bool(partial_result.get("ok", true)), "coverage gap cannot report ok")
	_expect(String(partial_result.get("status", "")) == "partial", "coverage gap reports partial")
	_expect(bool((partial_result.get("coverage", {}) as Dictionary).get("provider_complete", false)), "provider complete claim is retained")
	_expect(not bool((partial_result.get("coverage", {}) as Dictionary).get("covers_query", true)), "coverage query span is checked")
	_expect(int(partial_result.get("credited_steps", -1)) == 5, "known partial bucket may credit only its covered steps")

	var alias_state: Dictionary = _new_state()
	var alias_start: int = 12_000
	var alias_egg: Dictionary = HatchServiceScript.start_egg(alias_state, alias_start, "starter")
	_expect(bool(alias_egg.get("ok", false)), "overlap alias test egg starts")
	provider.set_response({
		"source": "coverage-test",
		"status": "ok",
		"coverage": {"from_utc": alias_start, "to_utc": alias_start + 100, "complete": true, "known": true},
		"buckets": [{"id": "bucket-a", "from_utc": alias_start, "to_utc": alias_start + 50, "steps": 50, "complete": true}],
		"today_steps": 50,
		"message": "測試",
	})
	var alias_first: Dictionary = StepServiceScript.synchronize(alias_state, provider, alias_start + 100)
	_expect(int(alias_first.get("credited_steps", -1)) == 50, "first overlap interval credits once")
	provider.set_response({
		"source": "coverage-test",
		"status": "ok",
		"coverage": {"from_utc": alias_start, "to_utc": alias_start + 100, "complete": true, "known": true},
		"buckets": [{"id": "bucket-b", "from_utc": alias_start + 40, "to_utc": alias_start + 100, "steps": 50, "complete": true}],
		"today_steps": 50,
		"message": "測試",
	})
	var alias_overlap: Dictionary = StepServiceScript.synchronize(alias_state, provider, alias_start + 100)
	_expect(int(alias_overlap.get("credited_steps", -1)) == 50, "overlapping changed ID is not added twice")
	_expect((alias_state.get("step_ledger", {}) as Dictionary).get("buckets", {}).size() == 1, "overlapping changed ID keeps one logical bucket")
	provider.set_response({
		"source": "coverage-test",
		"status": "ok",
		"coverage": {"from_utc": alias_start, "to_utc": alias_start + 100, "complete": true, "known": true},
		"buckets": [{"id": "bucket-c", "from_utc": alias_start, "to_utc": alias_start + 100, "steps": 120, "complete": true}],
		"today_steps": 120,
		"message": "測試",
	})
	var alias_growth: Dictionary = StepServiceScript.synchronize(alias_state, provider, alias_start + 100)
	_expect(int(alias_growth.get("credited_steps", -1)) == 120, "overlap alias growth credits only the new difference")

func _test_hatch_transition_when_pet_model_exists() -> void:
	if OS.get_cmdline_user_args().has("--skip-hatch"):
		push_warning("test_steps_save: hatch checks explicitly skipped by command-line flag")
		return
	var pet_model_value: Variant = load("res://domain/pet_model.gd")
	if pet_model_value == null or not (pet_model_value is Script) or not (pet_model_value as Script).has_method("create_pet"):
		push_warning("test_steps_save: PetModel is not loadable yet; hatch transition will run in integrated project")
		return
	var state: Dictionary = _new_state()
	var provider = MockStepProviderScript.new()
	var started_at: int = 2_000
	var start_result: Dictionary = HatchServiceScript.start_egg(state, started_at, "starter")
	_expect(bool(start_result.get("ok", false)), "hatch test egg starts")
	provider.add_steps(state, 500, started_at + 1)
	var sync: Dictionary = StepServiceScript.synchronize(state, provider, started_at + 2)
	_expect(bool(sync.get("ok", false)), "hatch test sync succeeds")
	var first_check: Dictionary = HatchServiceScript.check(state, started_at + 3)
	_expect(bool(first_check.get("ok", false)), "hatch check succeeds")
	_expect(bool(first_check.get("hatched", false)), "hatch transition is true once")
	_expect((state.get("pet", {}) as Dictionary).size() > 0, "hatch creates a pet")
	var second_check: Dictionary = HatchServiceScript.check(state, started_at + 4)
	_expect(bool(second_check.get("ok", false)), "repeated hatch check remains valid")
	_expect(not bool(second_check.get("hatched", true)), "repeated hatch check is not a new transition")

	var time_state: Dictionary = _new_state()
	var time_start: int = 3_000
	var time_result: Dictionary = HatchServiceScript.start_egg(time_state, time_start, "starter")
	_expect(bool(time_result.get("ok", false)), "time-mode egg starts")
	var mode_result: Dictionary = HatchServiceScript.use_time_mode(time_state, time_start + 1)
	_expect(bool(mode_result.get("ok", false)), "time mode activates")
	_expect(not bool(mode_result.get("hatched", true)), "time mode does not hatch early")
	var time_check: Dictionary = HatchServiceScript.check(time_state, time_start + 86400)
	_expect(bool(time_check.get("ok", false)), "time-mode completion check succeeds")
	_expect(bool(time_check.get("hatched", false)), "time mode uses egg start plus 24 hours")
	var time_repeat: Dictionary = HatchServiceScript.use_time_mode(time_state, time_start + 86401)
	_expect(not bool(time_repeat.get("hatched", true)), "time-mode use is idempotent after hatch")

func _test_atomic_save_backup_and_recovery() -> void:
	var save_path: String = "/tmp/pixel-monster-steps-save-%d.json" % OS.get_process_id()
	_cleanup_save_files(save_path)
	var first_state: Dictionary = _new_state()
	first_state["saved_at"] = 1
	first_state["last_tick"] = 1
	var first_error: Error = SaveServiceScript.save(first_state, save_path)
	_expect(first_error == OK, "first save succeeds")

	var second_state: Dictionary = _new_state()
	second_state["saved_at"] = 2
	second_state["last_tick"] = 2
	var second_error: Error = SaveServiceScript.save(second_state, save_path)
	_expect(second_error == OK, "second save succeeds")
	_expect(FileAccess.file_exists(save_path + ".bak"), "valid previous save creates backup")
	_expect(not FileAccess.file_exists(save_path + ".tmp"), "successful atomic save removes temp")

	var loaded_current: Dictionary = SaveServiceScript.load_state(save_path)
	_expect(int(loaded_current.get("saved_at", -1)) == 2, "current primary loads")

	var corrupt: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string("{ definitely not json")
		corrupt.flush()
		corrupt.close()
	var recovered: Dictionary = SaveServiceScript.load_state(save_path)
	_expect(int(recovered.get("saved_at", -1)) == 1, "corrupt primary recovers last valid backup")
	var backup_after_recovery: Dictionary = SaveServiceScript.load_state(save_path + ".bak")
	_expect(int(backup_after_recovery.get("saved_at", -1)) == 1, "recovery preserves valid backup")

	var third_state: Dictionary = _new_state()
	third_state["saved_at"] = 3
	third_state["last_tick"] = 3
	var third_error: Error = SaveServiceScript.save(third_state, save_path)
	_expect(third_error == OK, "save after corrupt primary succeeds")
	var backup_after_bad_primary_save: Dictionary = SaveServiceScript.load_state(save_path + ".bak")
	_expect(int(backup_after_bad_primary_save.get("saved_at", -1)) == 1, "bad primary never replaces valid backup")

	var invalid_error: Error = SaveServiceScript.save({"schema_version": 999}, save_path + ".invalid")
	_expect(invalid_error == ERR_INVALID_DATA, "schema validation rejects incomplete state")
	_cleanup_save_files(save_path)
	_cleanup_save_files(save_path + ".invalid")

func _test_nested_schema_backup_recovery() -> void:
	var save_path: String = "/tmp/pixel-monster-steps-save-nested-%d.json" % OS.get_process_id()
	_cleanup_save_files(save_path)

	var backup_state: Dictionary = _nested_valid_state(10)
	var first_error: Error = SaveServiceScript.save(backup_state, save_path)
	_expect(first_error == OK, "nested-schema backup fixture saves")
	var current_state: Dictionary = _nested_valid_state(20)
	var second_error: Error = SaveServiceScript.save(current_state, save_path)
	_expect(second_error == OK, "nested-schema current fixture saves")
	_expect(int(SaveServiceScript.load_state(save_path).get("saved_at", -1)) == 20, "nested-schema current fixture loads")

	var malformed_pet: Dictionary = current_state.duplicate(true)
	var malformed_pet_value: Variant = malformed_pet.get("pet")
	var malformed_pet_data: Dictionary = malformed_pet_value
	malformed_pet_data.erase("name")
	_expect(not SaveServiceScript.validate_state(malformed_pet), "pet missing required name is invalid")

	var malformed_conditions: Dictionary = current_state.duplicate(true)
	var malformed_conditions_value: Variant = malformed_conditions.get("pet")
	var malformed_conditions_pet: Dictionary = malformed_conditions_value
	malformed_conditions_pet.erase("conditions")
	_expect(not SaveServiceScript.validate_state(malformed_conditions), "pet missing conditions is invalid")

	var malformed_egg: Dictionary = current_state.duplicate(true)
	var malformed_egg_value: Variant = malformed_egg.get("egg")
	var malformed_egg_data: Dictionary = malformed_egg_value
	malformed_egg_data.erase("target_steps")
	_expect(not SaveServiceScript.validate_state(malformed_egg), "active egg missing target is invalid")

	var nanish_state: Dictionary = current_state.duplicate(true)
	var nanish_pet_value: Variant = nanish_state.get("pet")
	var nanish_pet: Dictionary = nanish_pet_value
	# NaN/Inf cannot be represented by strict JSON. This first assertion covers
	# the in-memory edge, then the serialized replacement below models the
	# legal `null` representation produced by JSON encoders for that value.
	nanish_pet["health"] = NAN
	_expect(not SaveServiceScript.validate_state(nanish_state), "non-finite pet value is invalid")
	var nanish_text: String = JSON.stringify(nanish_state)
	nanish_text = nanish_text.replace("NaN", "null").replace("nan", "null")
	nanish_text = nanish_text.replace("INF", "null").replace("inf", "null")
	var nanish_json_state: Dictionary = current_state.duplicate(true)
	var nanish_json_pet_value: Variant = nanish_json_state.get("pet")
	var nanish_json_pet: Dictionary = nanish_json_pet_value
	nanish_json_pet["health"] = null
	_expect(not SaveServiceScript.validate_state(nanish_json_state), "null numeric pet value is invalid")

	var out_of_range: Dictionary = current_state.duplicate(true)
	var out_of_range_pet_value: Variant = out_of_range.get("pet")
	var out_of_range_pet: Dictionary = out_of_range_pet_value
	out_of_range_pet["fullness"] = 101.0
	_expect(not SaveServiceScript.validate_state(out_of_range), "out-of-range pet value is invalid")

	var malformed_settings: Dictionary = current_state.duplicate(true)
	var malformed_settings_value: Variant = malformed_settings.get("settings")
	var malformed_settings_data: Dictionary = malformed_settings_value
	malformed_settings_data["sound"] = "true"
	_expect(not SaveServiceScript.validate_state(malformed_settings), "settings default type is validated")

	var malformed_pending: Dictionary = current_state.duplicate(true)
	var malformed_pending_value: Variant = malformed_pending.get("pending_battle")
	var malformed_pending_data: Dictionary = malformed_pending_value
	malformed_pending_data.erase("rounds")
	_expect(not SaveServiceScript.validate_state(malformed_pending), "pending battle shape is validated")

	var malformed_collection: Dictionary = current_state.duplicate(true)
	var malformed_collection_value: Variant = malformed_collection.get("collection")
	var malformed_collection_data: Array = malformed_collection_value
	malformed_collection_data.append(17)
	_expect(not SaveServiceScript.validate_state(malformed_collection), "collection scalar entry is invalid")

	var empty_collection_entry: Dictionary = current_state.duplicate(true)
	var empty_collection_value: Variant = empty_collection_entry.get("collection")
	var empty_collection_data: Array = empty_collection_value
	empty_collection_data.append({})
	_expect(not SaveServiceScript.validate_state(empty_collection_entry), "empty collection entry is invalid")

	var malformed_collection_pet: Dictionary = current_state.duplicate(true)
	var malformed_collection_pet_value: Variant = malformed_collection_pet.get("collection")
	var malformed_collection_pet_data: Array = malformed_collection_pet_value
	malformed_collection_pet_data.append({"pet": 17})
	_expect(not SaveServiceScript.validate_state(malformed_collection_pet), "collection nested pet is invalid")

	var malformed_snapshot: Dictionary = current_state.duplicate(true)
	var malformed_snapshot_pending_value: Variant = malformed_snapshot.get("pending_battle")
	var malformed_snapshot_pending: Dictionary = malformed_snapshot_pending_value
	malformed_snapshot_pending["player"] = 17
	_expect(not SaveServiceScript.validate_state(malformed_snapshot), "pending player snapshot must be a dictionary")

	var malformed_round: Dictionary = current_state.duplicate(true)
	var malformed_round_pending_value: Variant = malformed_round.get("pending_battle")
	var malformed_round_pending: Dictionary = malformed_round_pending_value
	var malformed_rounds_value: Variant = malformed_round_pending.get("rounds")
	var malformed_rounds: Array = malformed_rounds_value
	malformed_rounds[0] = 17
	_expect(not SaveServiceScript.validate_state(malformed_round), "pending round entry must be a dictionary")

	var malformed_cases: Array = [
		{"label": "malformed pet primary", "state": malformed_pet, "text": JSON.stringify(malformed_pet)},
		{"label": "malformed conditions primary", "state": malformed_conditions, "text": JSON.stringify(malformed_conditions)},
		{"label": "malformed egg primary", "state": malformed_egg, "text": JSON.stringify(malformed_egg)},
		{"label": "non-finite primary", "state": nanish_json_state, "text": nanish_text},
		{"label": "out-of-range primary", "state": out_of_range, "text": JSON.stringify(out_of_range)},
		{"label": "malformed settings primary", "state": malformed_settings, "text": JSON.stringify(malformed_settings)},
		{"label": "malformed pending primary", "state": malformed_pending, "text": JSON.stringify(malformed_pending)},
		{"label": "scalar collection primary", "state": malformed_collection, "text": JSON.stringify(malformed_collection)},
		{"label": "empty collection primary", "state": empty_collection_entry, "text": JSON.stringify(empty_collection_entry)},
		{"label": "nested collection primary", "state": malformed_collection_pet, "text": JSON.stringify(malformed_collection_pet)},
		{"label": "scalar snapshot primary", "state": malformed_snapshot, "text": JSON.stringify(malformed_snapshot)},
		{"label": "scalar round primary", "state": malformed_round, "text": JSON.stringify(malformed_round)},
	]
	for case_value: Variant in malformed_cases:
		var case_data: Dictionary = case_value
		_write_raw_save(save_path, String(case_data.get("text", "")))
		var recovered: Dictionary = SaveServiceScript.load_state(save_path)
		_expect(int(recovered.get("saved_at", -1)) == 10, "%s falls back to backup" % String(case_data.get("label", "nested schema")))
		var backup_after_case: Dictionary = SaveServiceScript.load_state(save_path + ".bak")
		_expect(int(backup_after_case.get("saved_at", -1)) == 10, "%s preserves backup" % String(case_data.get("label", "nested schema")))

	_cleanup_save_files(save_path)

func _nested_valid_state(saved_at: int) -> Dictionary:
	var state: Dictionary = _new_state()
	state["saved_at"] = saved_at
	state["last_tick"] = saved_at
	state["pet"] = PetModelScript.create_pet(1_000)
	var archived_pet: Dictionary = PetModelScript.create_pet(2_000)
	archived_pet["stage"] = "mature"
	archived_pet["species"] = "ember"
	archived_pet["archived_at"] = 2_100
	state["collection"] = [archived_pet]
	state["egg"] = {
		"id": "egg-schema-test",
		"kind": "starter",
		"started_at": 1_000,
		"target_steps": 500,
		"credited_steps": 100,
		"mode": "steps",
		"hatched": false,
		"hatched_at": 0,
		"time_started_at": 1_000,
		"time_required_seconds": 86400,
		"step_source": "mock",
		"step_coverage": {},
		"last_sync": 1_010,
		"step_buckets": {},
		"step_ledger": {},
	}
	state["pending_battle"] = {
		"version": 1,
		"id": "battle-schema-test",
		"seed": 123,
		"npc_id": "npc-1",
		"npc_name": "小岩",
		"stance": "balanced",
		"player": {"id": "pet-1000", "name": "芽芽"},
		"enemy": {"id": "npc-1", "name": "小岩"},
		"rounds": [{
			"round": 1,
			"actor": "player",
			"damage": 4,
			"skill": false,
			"miss": false,
			"player_hp": 40,
			"enemy_hp": 36,
			"text": "芽芽造成 4 點傷害。",
		}],
		"outcome": "win",
		"settled": false,
		"started_at": 1_020,
		"max_rounds": 12,
	}
	return state

func _write_raw_save(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures += 1
		push_error("FAIL: unable to write raw save fixture")
		return
	file.store_string(text)
	file.flush()
	file.close()

func _new_state() -> Dictionary:
	return {
		"schema_version": 1,
		"saved_at": 0,
		"last_tick": 0,
		"pet": {},
		"egg": {},
		"collection": [],
		"pending_battle": {},
		"battle_history": [],
		"step_ledger": {},
		"step_debug": {},
		"settings": {
			"sound": true,
			"music": true,
			"vibration": true,
			"auto_lights": true,
			"sleep_hour": 22,
			"wake_hour": 7,
			"timezone_offset_minutes": 480,
			"debug_time_offset": 0,
		},
	}

func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _cleanup_save_files(path: String) -> void:
	for candidate in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
