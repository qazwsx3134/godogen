extends SceneTree

const BattleServiceScript = preload("res://domain/battle_service.gd")
const PetModelScript = preload("res://domain/pet_model.gd")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_opponents_schema()
	_test_opponent_progression_and_baby_battle()
	_test_resolver_is_deterministic()
	_test_begin_freezes_timeline_and_consumes_energy()
	_test_begin_gates_match_care_service()
	_test_finish_is_idempotent_and_preserves_replay()
	_test_sequence_advances_after_settlement()
	_test_initiative_and_injury()
	_test_wrong_individual_cannot_settle()

	if failures == 0:
		print("Battle tests passed")
	else:
		push_error("Battle tests failed: %d" % failures)
	quit(failures)


func _test_opponents_schema() -> void:
	var rows: Array = BattleServiceScript.opponents()
	_expect(rows.size() == 3, "opponents.json exposes exactly three NPCs")
	var ids: Array[String] = []
	for row_variant: Variant in rows:
		_expect(row_variant is Dictionary, "each opponent is a dictionary")
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant
		for key: String in ["id", "name", "attack", "defense", "agility", "max_hp", "species", "description"]:
			_expect(row.has(key), "opponent has required field: %s" % key)
		ids.append(str(row.get("id", "")))
		_expect(_as_int(row.get("attack", 0)) > 0, "opponent attack is positive")
		_expect(_as_int(row.get("defense", 0)) > 0, "opponent defense is positive")
		_expect(_as_int(row.get("max_hp", 0)) > 0, "opponent max_hp is positive")
	_expect(ids == ["moss_scout", "ember_rival", "bloom_guardian"], "opponent order and IDs are stable")


func _test_opponent_progression_and_baby_battle() -> void:
	var rows: Array = BattleServiceScript.opponents()
	var stages: Array[String] = ["baby", "growing", "mature"]
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		_expect(str(row.get("stage", "")) == stages[index], "NPC %d is assigned to the intended growth stage" % index)
		if index == 0:
			continue
		var previous: Dictionary = rows[index - 1]
		_expect(_as_int(row["attack"]) > _as_int(previous["attack"]), "NPC attack rises by growth stage")
		_expect(_as_int(row["defense"]) > _as_int(previous["defense"]), "NPC defense rises by growth stage")
		_expect(_as_int(row["agility"]) > _as_int(previous["agility"]), "NPC agility rises by growth stage")
		_expect(_as_int(row["max_hp"]) > _as_int(previous["max_hp"]), "NPC max_hp rises by growth stage")

	var baby_state: Dictionary = {
		"pet": PetModelScript.create_pet(1700000050),
		"pending_battle": {},
		"battle_history": [],
	}
	var model_stats: Dictionary = PetModelScript.stats(baby_state["pet"])
	var baby_result: Dictionary = BattleServiceScript.begin(baby_state, "moss_scout", "balanced", 1700000051)
	_expect(bool(baby_result.get("ok", false)), "a fresh baby can enter the baby-tier NPC battle")
	if bool(baby_result.get("ok", false)):
		var player_snapshot: Dictionary = baby_result["battle"]["player"]
		for key: String in ["attack", "defense", "agility", "max_hp"]:
			_expect(_as_int(player_snapshot[key]) == _as_int(model_stats[key]), "balanced baby snapshot equals PetModel.stats.%s" % key)
		_expect(baby_result["battle"]["rounds"].size() > 0, "baby battle produces a playable timeline")
		_expect(baby_result["battle"]["rounds"].size() <= 12, "baby battle remains bounded")
		_expect(absi(_as_int(baby_result["battle"]["enemy"]["attack"]) - _as_int(model_stats["attack"])) <= 3, "baby NPC attack is near baby PetModel attack")
		_expect(absi(_as_int(baby_result["battle"]["enemy"]["max_hp"]) - _as_int(model_stats["max_hp"])) <= 4, "baby NPC HP is near baby PetModel HP")


func _test_resolver_is_deterministic() -> void:
	var player: Dictionary = _player_snapshot()
	var enemy: Dictionary = BattleServiceScript.opponents()[0]
	var first: Dictionary = BattleServiceScript.resolve_battle(player, enemy, "balanced", 13579)
	var second: Dictionary = BattleServiceScript.resolve_battle(player, enemy, "balanced", 13579)
	_expect(first == second, "same snapshots and seed produce the same battle")
	_expect(first["rounds"].size() <= 12, "resolver is bounded to twelve actions")
	_expect(["win", "loss", "draw"].has(str(first["outcome"])), "resolver returns a valid outcome")


func _test_initiative_and_injury() -> void:
	var quick: Dictionary = {"name": "快", "attack": 1, "defense": 80, "agility": 90, "max_hp": 300}
	var slow: Dictionary = {"name": "慢", "attack": 1, "defense": 80, "agility": 1, "max_hp": 300}
	var report: Dictionary = BattleServiceScript.resolve_battle(quick, slow, "balanced", 57)
	var turns: Dictionary = {"player": 0, "enemy": 0}
	for action in report.rounds: turns[action.actor] += 1
	_expect(turns.player == 6 and turns.enemy == 6, "initiative determines order, never removes the slower pet's turns")
	var state: Dictionary = _state()
	BattleServiceScript.begin(state, "moss_scout", "balanced", 1700000300)
	state.pending_battle.outcome = "loss"
	state.pending_battle.rounds.back().player_hp = 0
	var health: float = float(state.pet.health)
	BattleServiceScript.finish(state, 1700000400)
	_expect(state.pet.conditions.injured, "knockout creates a treatable injury")
	_expect(float(state.pet.health) == health, "battle HP never subtracts from care health")


func _test_wrong_individual_cannot_settle() -> void:
	var state: Dictionary = _state()
	BattleServiceScript.begin(state, "moss_scout", "balanced", 1700000500)
	state.pet.id = "another-pet"
	var before: Dictionary = state.duplicate(true)
	_expect(not BattleServiceScript.finish(state, 1700000600).ok, "another pet cannot claim the pending battle")
	_expect(state == before, "wrong-pet settlement has no side effects")


func _test_begin_freezes_timeline_and_consumes_energy() -> void:
	var state: Dictionary = _state()
	var result: Dictionary = BattleServiceScript.begin(state, "moss_scout", "assault", 1700000000)
	_expect(bool(result.get("ok", false)), "begin accepts a valid battle")
	_expect(_as_int(state["pet"]["energy"]) == 88, "begin consumes exactly twelve energy")
	_expect(_as_int(state.get("battle_sequence", 0)) == 1, "begin records the first per-state sequence")

	var pending: Dictionary = state["pending_battle"]
	for key: String in ["id", "seed", "npc_id", "npc_name", "stance", "player", "enemy", "rounds", "outcome", "settled", "started_at"]:
		_expect(pending.has(key), "pending battle has required field: %s" % key)
	_expect(not bool(pending.get("settled", true)), "new pending battle is unsettled")
	_expect(str(pending.get("stance", "")) == "assault", "pending battle preserves stance")
	_expect(str(pending.get("id", "")).ends_with("-0001"), "battle ID includes sequence")

	var rounds: Array = pending.get("rounds", [])
	_expect(rounds.size() > 0, "begin stores a non-empty resolved timeline")
	_expect(rounds.size() <= 12, "pending timeline is bounded")
	for round_variant: Variant in rounds:
		_expect(round_variant is Dictionary, "round entry is a dictionary")
		if not (round_variant is Dictionary):
			continue
		var round_data: Dictionary = round_variant
		for key: String in ["round", "actor", "damage", "skill", "miss", "player_hp", "enemy_hp", "text"]:
			_expect(round_data.has(key), "round has required field: %s" % key)
		_expect(["player", "enemy"].has(str(round_data.get("actor", ""))), "round actor is player or enemy")
		_expect(str(round_data.get("text", "")) != "", "round text is Traditional Chinese copy")

	var player_snapshot: Dictionary = pending["player"]
	_expect(player_snapshot.has("attack"), "player snapshot freezes attack")
	_expect(player_snapshot.has("defense"), "player snapshot freezes defense")
	_expect(player_snapshot.has("agility"), "player snapshot freezes agility")
	_expect(player_snapshot.has("max_hp"), "player snapshot freezes max_hp")
	_expect(_as_int(player_snapshot.get("base_attack", 0)) == 18, "player snapshot uses PetModel.stats attack")
	_expect(_as_int(player_snapshot.get("base_defense", 0)) == 17, "player snapshot uses PetModel.stats defense")
	_expect(_as_int(player_snapshot.get("max_hp", 0)) == 56, "player snapshot uses PetModel.stats max_hp before stance")
	_expect(_as_int(player_snapshot.get("base_attack", 0)) < _as_int(player_snapshot.get("attack", 0)), "assault stance gives a visible attack tradeoff")
	var frozen_snapshot: Dictionary = player_snapshot.duplicate(true)
	state["pet"]["name"] = "被改名的寵物"
	state["pet"]["training"]["power"] = 999
	_expect(state["pending_battle"]["player"] == frozen_snapshot, "pending battle keeps an immutable player snapshot")


func _test_begin_gates_match_care_service() -> void:
	var invalid_stance_state: Dictionary = _state()
	var invalid_before: Dictionary = invalid_stance_state.duplicate(true)
	var invalid_result: Dictionary = BattleServiceScript.begin(invalid_stance_state, "moss_scout", "reckless", 1700000000)
	_expect(not bool(invalid_result.get("ok", true)), "invalid stance is rejected")
	_expect(invalid_stance_state == invalid_before, "invalid stance does not mutate state")

	var low_energy_state: Dictionary = _state()
	low_energy_state["pet"]["energy"] = 11
	_expect_battle_gate(low_energy_state, "low energy", "精力不足，至少需要 12 點才能戰鬥。")

	var injured_state: Dictionary = _state()
	injured_state["pet"]["conditions"]["injured"] = true
	_expect_battle_gate(injured_state, "injury", "受傷中，暫時不能戰鬥。")

	var sick_state: Dictionary = _state()
	sick_state["pet"]["conditions"]["sick"] = true
	_expect_battle_gate(sick_state, "sickness", "生病中，暫時不能戰鬥。")

	var sleeping_state: Dictionary = _state()
	sleeping_state["pet"]["behavior"] = "sleeping"
	_expect_battle_gate(sleeping_state, "sleep", "怪獸正在睡覺，請先開燈或喚醒。")

	var hibernating_state: Dictionary = _state()
	hibernating_state["pet"]["conditions"]["hibernating"] = true
	_expect_battle_gate(hibernating_state, "hibernation", "怪獸正在保護性休眠，請先喚醒。")

	var active_state: Dictionary = _state()
	var first: Dictionary = BattleServiceScript.begin(active_state, "moss_scout", "balanced", 1700000000)
	_expect(bool(first.get("ok", false)), "setup active pending battle")
	_expect_battle_gate(active_state, "active pending battle", "還有一場戰鬥尚未結算。")


func _expect_battle_gate(state: Dictionary, label: String, expected_message: String) -> void:
	var before: Dictionary = state.duplicate(true)
	var begin_result: Dictionary = BattleServiceScript.begin(state, "moss_scout", "balanced", 1700000000)
	_expect(not bool(begin_result.get("ok", true)), "%s is denied by BattleService" % label)
	_expect(str(begin_result.get("message", "")) == expected_message, "%s denial message matches CareService contract" % label)
	_expect(state == before, "%s rejection does not mutate state" % label)


func _test_finish_is_idempotent_and_preserves_replay() -> void:
	var state: Dictionary = _state()
	var started: Dictionary = BattleServiceScript.begin(state, "ember_rival", "defend", 1700000100)
	_expect(bool(started.get("ok", false)), "setup battle for finish test")
	var resumed_state: Dictionary = state.duplicate(true)
	var original_training: Dictionary = state["pet"]["training"].duplicate(true)

	var resumed_result: Dictionary = BattleServiceScript.finish(resumed_state, 1700000200)
	var finish_result: Dictionary = BattleServiceScript.finish(state, 1700000201)
	_expect(bool(finish_result.get("ok", false)), "finish settles an active battle")
	_expect(resumed_result.get("outcome", "") == finish_result.get("outcome", ""), "restart keeps the same outcome")
	_expect(resumed_result["battle"]["rounds"] == finish_result["battle"]["rounds"], "restart keeps the same timeline")
	_expect(bool(state["pending_battle"].get("settled", false)), "finish marks pending battle settled")
	_expect(state["battle_history"].size() == 1, "finish stores one battle history record")
	_expect(state["pet"]["battles"] == 1, "finish increments battles once")
	_expect(state["pet"]["training"] == original_training, "finish does not mutate lifelong training stats")

	var after_first_finish: Dictionary = state.duplicate(true)
	var repeated_result: Dictionary = BattleServiceScript.finish(state, 1700000300)
	_expect(bool(repeated_result.get("ok", false)), "repeated finish is safely acknowledged")
	_expect(bool(repeated_result.get("already_settled", false)), "repeated finish is marked already settled")
	_expect(state == after_first_finish, "repeated finish gives no duplicate reward or history")

	var no_battle_result: Dictionary = BattleServiceScript.finish({"pending_battle": {}}, 1700000300)
	_expect(not bool(no_battle_result.get("ok", true)), "finish without a pending battle is rejected")


func _test_sequence_advances_after_settlement() -> void:
	var state: Dictionary = _state()
	var first: Dictionary = BattleServiceScript.begin(state, "moss_scout", "balanced", 1700000400)
	_expect(bool(first.get("ok", false)), "first battle starts for sequence test")
	BattleServiceScript.finish(state, 1700000401)
	var second: Dictionary = BattleServiceScript.begin(state, "bloom_guardian", "balanced", 1700000402)
	_expect(bool(second.get("ok", false)), "a new battle starts after settlement")
	_expect(str(second["battle"]["id"]).ends_with("-0002"), "second battle uses the next sequence")
	_expect(second["battle"]["seed"] != first["battle"]["seed"], "new battle gets a new persisted seed")
	_expect(_as_int(state["pet"]["energy"]) == 76, "each accepted battle consumes twelve energy")


func _state() -> Dictionary:
	return {
		"schema_version": 1,
		"saved_at": 1700000000,
		"pet": {
			"id": "pet-test",
			"name": "芽芽",
			"species": "sprout",
			"stage": "baby",
			"energy": 100,
			"health": 100,
			"mood": 70,
			"behavior": "idle",
			"conditions": {"injured": false, "sick": false, "hibernating": false},
			"training": {"power": 8, "guard": 7, "swift": 6},
			"wins": 0,
			"losses": 0,
			"draws": 0,
			"battles": 0,
			"history": [],
		},
		"pending_battle": {},
		"battle_history": [],
	}


func _player_snapshot() -> Dictionary:
	return {
		"id": "player-test",
		"name": "芽芽",
		"species": "sprout",
		"stage": "baby",
		"attack": 24,
		"defense": 22,
		"agility": 15,
		"max_hp": 100,
		"skill_name": "芽芽突進",
		"skill_chance_percent": 16,
		"skill_bonus_percent": 30,
	}


func _as_int(value: Variant) -> int:
	return int(value) if value != null else 0


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("[battle] %s" % message)
