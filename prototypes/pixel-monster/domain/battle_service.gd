extends RefCounted
class_name BattleService

## Pure dictionary battle rules for the Stage A local NPC battles.
##
## A battle is resolved completely at begin().  The resulting timeline is
## persisted in state.pending_battle, so loading the state cannot reroll it.

const OPPONENTS_PATH: String = "res://data/opponents.json"
const PetModelScript = preload("res://domain/pet_model.gd")
const ENERGY_COST: int = 12
const MAX_ROUNDS: int = 12
const VALID_STANCES: Array = ["balanced", "assault", "defend"]
const PENDING_KEYS: Array = [
	"id",
	"seed",
	"npc_id",
	"npc_name",
	"stance",
	"player",
	"enemy",
	"rounds",
	"outcome",
	"settled",
	"started_at",
]


static func opponents() -> Array:
	var result: Array = []
	if not FileAccess.file_exists(OPPONENTS_PATH):
		return result

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OPPONENTS_PATH))
	if not parsed is Dictionary:
		return result
	var rows: Variant = parsed.get("opponents", [])
	if not rows is Array:
		return result

	for row_variant: Variant in rows:
		if not row_variant is Dictionary:
			continue
		var row: Dictionary = row_variant
		if not _has_opponent_shape(row):
			continue
		result.append(row.duplicate(true))
	return result


static func begin(state: Dictionary, npc_id: String, stance: String, now: int) -> Dictionary:
	if not VALID_STANCES.has(stance):
		return _failure("請選擇有效的戰鬥方針。")
	if not state.has("pet") or not state["pet"] is Dictionary:
		return _failure("目前沒有可出戰的怪獸。")

	var pet: Dictionary = state["pet"]
	if pet.is_empty():
		return _failure("目前沒有可出戰的怪獸。")

	var pending_variant: Variant = state.get("pending_battle", {})
	if not pending_variant is Dictionary:
		return _failure("戰鬥資料無法讀取，請先完成存檔修復。")

	var conditions_variant: Variant = pet.get("conditions", {})
	var conditions: Dictionary = conditions_variant if conditions_variant is Dictionary else {}
	if bool(conditions.get("hibernating", false)):
		return _failure("怪獸正在保護性休眠，請先喚醒。")
	if str(pet.get("behavior", "idle")) == "sleeping":
		return _failure("怪獸正在睡覺，請先開燈或喚醒。")
	if bool(conditions.get("injured", false)):
		return _failure("受傷中，暫時不能戰鬥。")
	if bool(conditions.get("sick", false)):
		return _failure("生病中，暫時不能戰鬥。")

	var energy: float = float(pet.get("energy", 0.0))
	if energy < float(ENERGY_COST):
		return _failure("精力不足，至少需要 %d 點才能戰鬥。" % ENERGY_COST)

	var pending: Dictionary = pending_variant
	if not pending.is_empty() and not bool(pending.get("settled", false)):
		return _failure("還有一場戰鬥尚未結算。")

	var npc: Dictionary = _find_opponent(npc_id)
	if npc.is_empty():
		return _failure("找不到這名對手。")

	var sequence: int = _to_int(state.get("battle_sequence", 0), 0) + 1
	var pet_id: String = str(pet.get("id", "pet"))
	var battle_id: String = "%s-%04d" % [pet_id, sequence]
	var seed: int = _make_seed(pet_id, npc_id, stance, now, sequence)

	var player_snapshot: Dictionary = _make_player_snapshot(pet, stance)
	var enemy_snapshot: Dictionary = npc.duplicate(true)
	var resolved: Dictionary = resolve_battle(player_snapshot, enemy_snapshot, stance, seed)
	var new_pending: Dictionary = {
		"version": 1,
		"id": battle_id,
		"seed": seed,
		"npc_id": npc_id,
		"npc_name": str(npc.get("name", npc_id)),
		"stance": stance,
		"player": player_snapshot,
		"enemy": enemy_snapshot,
		"rounds": resolved.get("rounds", []),
		"outcome": str(resolved.get("outcome", "draw")),
		"settled": false,
		"started_at": now,
		"max_rounds": MAX_ROUNDS,
	}

	# All validation and resolution happen before any state mutation.
	pet["energy"] = energy - float(ENERGY_COST)
	state["battle_sequence"] = sequence
	state["pending_battle"] = new_pending

	return {
		"ok": true,
		"message": "戰鬥已開始，戰報已準備完成。",
		"battle": new_pending.duplicate(true),
	}


static func finish(state: Dictionary, now: int) -> Dictionary:
	if not state.has("pending_battle") or not state["pending_battle"] is Dictionary:
		return _finish_failure("目前沒有可結算的戰鬥。")
	var pending: Dictionary = state["pending_battle"]
	if pending.is_empty():
		return _finish_failure("目前沒有可結算的戰鬥。")
	if not _has_pending_shape(pending):
		return _finish_failure("戰鬥資料不完整，無法結算。")

	var outcome: String = str(pending.get("outcome", "draw"))
	if bool(pending.get("settled", false)):
		return {
			"ok": true,
			"message": "這場戰鬥已結算，不會重複發獎。",
			"outcome": outcome,
			"already_settled": true,
			"battle": pending.duplicate(true),
		}

	if not state.has("pet") or not state["pet"] is Dictionary:
		return _finish_failure("目前沒有可更新的怪獸資料。")
	var pet: Dictionary = state["pet"]
	if pet.is_empty():
		return _finish_failure("目前沒有可更新的怪獸資料。")
	if str(pet.get("id", "")) != str(pending.get("player", {}).get("id", "")):
		return _finish_failure("這場戰鬥屬於另一位小夥伴，無法轉移結算。")

	var settled_battle: Dictionary = pending.duplicate(true)
	settled_battle["settled"] = true
	settled_battle["finished_at"] = now
	state["pending_battle"] = settled_battle

	var wins: int = _to_int(pet.get("wins", 0), 0)
	var losses: int = _to_int(pet.get("losses", 0), 0)
	var draws: int = _to_int(pet.get("draws", 0), 0)
	var battles: int = _to_int(pet.get("battles", 0), 0)
	var mood_delta: int = 0
	match outcome:
		"win":
			wins += 1
			mood_delta = 3
		"loss":
			losses += 1
			mood_delta = -2
		_:
			draws += 1
			mood_delta = 1
	battles += 1
	pet["wins"] = wins
	pet["losses"] = losses
	pet["draws"] = draws
	pet["battles"] = battles
	if pet.has("mood"):
		pet["mood"] = clampi(_to_int(pet.get("mood", 0), 0) + mood_delta, 0, 100)
	var knocked_out: bool = outcome == "loss" and not pending.rounds.is_empty() and int(pending.rounds.back().player_hp) == 0
	if knocked_out:
		pet["conditions"]["injured"] = true

	var history_entry: Dictionary = {
		"type": "battle",
		"battle_id": str(pending.get("id", "")),
		"npc_id": str(pending.get("npc_id", "")),
		"outcome": outcome,
		"at": now,
	}
	var pet_history_variant: Variant = pet.get("history", [])
	var pet_history: Array = pet_history_variant if pet_history_variant is Array else []
	pet_history.append(history_entry)
	pet["history"] = pet_history

	var battle_history_variant: Variant = state.get("battle_history", [])
	var battle_history: Array = battle_history_variant if battle_history_variant is Array else []
	battle_history.append(settled_battle.duplicate(true))
	state["battle_history"] = battle_history

	return {
		"ok": true,
		"message": "這次受了點傷，到療護頁貼上繃帶，休息 30 分鐘就會恢復。" if knocked_out else _outcome_message(outcome),
		"outcome": outcome,
		"already_settled": false,
		"reward": {
			"mood_delta": mood_delta,
			"stat_growth": 0,
		},
		"battle": settled_battle.duplicate(true),
	}


## Deterministic resolver used by begin() and headless tests.
## The snapshots already contain stance-adjusted player stats.
static func resolve_battle(player: Dictionary, enemy: Dictionary, stance: String, seed: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else 1

	var player_hp: int = clampi(_to_int(player.get("max_hp", 1), 1), 1, 999)
	var enemy_hp: int = clampi(_to_int(enemy.get("max_hp", 1), 1), 1, 999)
	var player_skill_used: bool = false
	var enemy_skill_used: bool = false
	var rounds: Array = []
	var player_first: bool = true

	for action_index: int in range(1, MAX_ROUNDS + 1):
		if player_hp <= 0 or enemy_hp <= 0:
			break

		# Initiative chooses order within a two-action round. Both living
		# combatants receive their turn, even with a large agility difference.
		if action_index % 2 == 1:
			var player_initiative: int = _to_int(player.get("agility", 1), 1) + rng.randi_range(0, 4)
			var enemy_initiative: int = _to_int(enemy.get("agility", 1), 1) + rng.randi_range(0, 4)
			player_first = player_initiative >= enemy_initiative
		var actor_is_player: bool = player_first if action_index % 2 == 1 else not player_first
		var attacker: Dictionary = player if actor_is_player else enemy
		var defender: Dictionary = enemy if actor_is_player else player
		var actor: String = "player" if actor_is_player else "enemy"
		var attacker_name: String = str(attacker.get("name", "芽芽" if actor_is_player else "對手"))
		var defender_name: String = str(defender.get("name", "對手" if actor_is_player else "芽芽"))

		var skill_used: bool = player_skill_used if actor_is_player else enemy_skill_used
		var skill_chance: int = clampi(_to_int(attacker.get("skill_chance_percent", 16), 16), 0, 100)
		var skill: bool = not skill_used and rng.randi_range(1, 100) <= skill_chance
		if skill:
			if actor_is_player:
				player_skill_used = true
			else:
				enemy_skill_used = true

		var attacker_agility: int = clampi(_to_int(attacker.get("agility", 1), 1), 1, 999)
		var defender_agility: int = clampi(_to_int(defender.get("agility", 1), 1), 1, 999)
		var miss_chance: int = clampi(10 + defender_agility - attacker_agility, 5, 20)
		var miss: bool = rng.randi_range(1, 100) <= miss_chance
		var damage: int = 0
		var text: String
		if miss:
			text = "%s 的%s落空了。" % [attacker_name, "技能" if skill else "攻擊"]
		else:
			var attack: int = clampi(_to_int(attacker.get("attack", 1), 1), 1, 999)
			var defense: int = clampi(_to_int(defender.get("defense", 1), 1), 1, 999)
			var variance: int = rng.randi_range(-2, 3)
			var bonus_percent: int = clampi(_to_int(attacker.get("skill_bonus_percent", 30), 30), 0, 100)
			var skill_bonus: int = int(ceil(float(attack * bonus_percent) / 100.0)) if skill else 0
			damage = clampi(attack + variance + skill_bonus - int(round(float(defense) * 0.55)), 1, 60)
			if actor_is_player:
				enemy_hp = maxi(enemy_hp - damage, 0)
			else:
				player_hp = maxi(player_hp - damage, 0)
			var skill_name: String = str(attacker.get("skill_name", "招牌技能"))
			text = "%s %s造成 %d 點傷害。" % [attacker_name, ("使出%s，" % skill_name) if skill else "的攻擊", damage]
			if (actor_is_player and enemy_hp == 0) or (not actor_is_player and player_hp == 0):
				text += "%s 倒下了。" % defender_name

		rounds.append({
			"round": action_index,
			"actor": actor,
			"damage": damage,
			"skill": skill,
			"miss": miss,
			"player_hp": player_hp,
			"enemy_hp": enemy_hp,
			"text": text,
		})

	var outcome: String = _determine_outcome(player_hp, enemy_hp, player, enemy)
	return {
		"rounds": rounds,
		"outcome": outcome,
		"player_hp": player_hp,
		"enemy_hp": enemy_hp,
		"stance": stance,
	}


static func _determine_outcome(player_hp: int, enemy_hp: int, player: Dictionary, enemy: Dictionary) -> String:
	if player_hp <= 0 and enemy_hp <= 0:
		return "draw"
	if enemy_hp <= 0:
		return "win"
	if player_hp <= 0:
		return "loss"

	var player_ratio: float = float(player_hp) / float(maxi(_to_int(player.get("max_hp", 1), 1), 1))
	var enemy_ratio: float = float(enemy_hp) / float(maxi(_to_int(enemy.get("max_hp", 1), 1), 1))
	if is_equal_approx(player_ratio, enemy_ratio):
		return "draw"
	return "win" if player_ratio > enemy_ratio else "loss"


static func _make_player_snapshot(pet: Dictionary, stance: String) -> Dictionary:
	var base_stats: Dictionary = _stats_from_pet(pet)
	var stance_stats: Dictionary = _apply_stance(base_stats, stance)
	return {
		"id": str(pet.get("id", "pet")),
		"name": str(pet.get("name", "芽芽")),
		"species": str(pet.get("species", "sprout")),
		"stage": str(pet.get("stage", "baby")),
		"attack": stance_stats["attack"],
		"defense": stance_stats["defense"],
		"agility": stance_stats["agility"],
		"max_hp": stance_stats["max_hp"],
		"base_attack": base_stats["attack"],
		"base_defense": base_stats["defense"],
		"base_agility": base_stats["agility"],
		"skill_name": {"sprout": "芽芽突進", "bloom": "葉角拍擊", "ember": "暖焰抱擊", "moss": "苔甲盾擊", "breeze": "風耳迅步"}.get(str(pet.get("species", "sprout")), "芽芽突進"),
		"skill_chance_percent": 16,
		"skill_bonus_percent": 30,
	}


static func _stats_from_pet(pet: Dictionary) -> Dictionary:
	var model_stats: Dictionary = PetModelScript.stats(pet)
	return _sanitize_stats(model_stats)


static func _sanitize_stats(source: Dictionary) -> Dictionary:
	return {
		"attack": clampi(_to_int(source.get("attack", 1), 1), 1, 999),
		"defense": clampi(_to_int(source.get("defense", 1), 1), 1, 999),
		"agility": clampi(_to_int(source.get("agility", 1), 1), 1, 999),
		"max_hp": clampi(_to_int(source.get("max_hp", 1), 1), 1, 999),
	}


static func _apply_stance(base_stats: Dictionary, stance: String) -> Dictionary:
	var attack: int = _to_int(base_stats.get("attack", 1), 1)
	var defense: int = _to_int(base_stats.get("defense", 1), 1)
	var agility: int = _to_int(base_stats.get("agility", 1), 1)
	var max_hp: int = _to_int(base_stats.get("max_hp", 1), 1)
	match stance:
		"assault":
			attack = int(ceil(float(attack) * 1.15))
			defense = maxi(int(floor(float(defense) * 0.85)), 1)
			agility += 1
		"defend":
			attack = maxi(int(floor(float(attack) * 0.85)), 1)
			defense = int(ceil(float(defense) * 1.15))
			agility = maxi(agility - 1, 1)
	return {
		"attack": clampi(attack, 1, 999),
		"defense": clampi(defense, 1, 999),
		"agility": clampi(agility, 1, 999),
		"max_hp": clampi(max_hp, 1, 999),
	}


static func _find_opponent(npc_id: String) -> Dictionary:
	for candidate_variant: Variant in opponents():
		if candidate_variant is Dictionary:
			var candidate: Dictionary = candidate_variant
			if str(candidate.get("id", "")) == npc_id:
				return candidate
	return {}


static func _has_opponent_shape(row: Dictionary) -> bool:
	for key: String in ["id", "name", "attack", "defense", "agility", "max_hp", "species", "description"]:
		if not row.has(key):
			return false
	return str(row.get("id", "")) != "" and str(row.get("name", "")) != ""


static func _has_pending_shape(pending: Dictionary) -> bool:
	for key: String in PENDING_KEYS:
		if not pending.has(key):
			return false
	if not pending.get("rounds", []) is Array:
		return false
	return ["win", "loss", "draw"].has(str(pending.get("outcome", "")))


static func _make_seed(pet_id: String, npc_id: String, stance: String, now: int, sequence: int) -> int:
	var source: String = "%s|%s|%s|%d|%d" % [pet_id, npc_id, stance, now, sequence]
	var result: int = source.hash()
	if result < 0:
		result = -result
	if result == 0:
		result = 1
	return result


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message, "battle": {}}


static func _finish_failure(message: String) -> Dictionary:
	return {"ok": false, "message": message, "outcome": "", "already_settled": false}


static func _outcome_message(outcome: String) -> String:
	match outcome:
		"win":
			return "戰鬥勝利！芽芽的信心增加了。"
		"loss":
			return "這次落敗了，芽芽需要休息；不會失去生命。"
		_:
			return "雙方勢均力敵，這場戰鬥以平手結束。"


static func _to_int(value: Variant, default_value: int) -> int:
	if value == null:
		return default_value
	if value is bool:
		return 1 if value else 0
	return int(value)
