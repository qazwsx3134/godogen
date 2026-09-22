extends RefCounted
class_name PetModel

## Pure dictionary state factory and derived pet values for the pixel-monster
## prototype.  This class deliberately has no Node or wall-clock dependency.

const SCHEMA_VERSION: int = 1
const CareServiceScript = preload("res://domain/care_service.gd")


static func create_state(now: int) -> Dictionary:
	var settings_balance: Dictionary = _dict(CareServiceScript.balance().get("settings_defaults", {}))
	return {
		"schema_version": SCHEMA_VERSION,
		"saved_at": now,
		"last_tick": now,
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
			"sleep_hour": int(settings_balance.get("sleep_hour", 22)),
			"wake_hour": int(settings_balance.get("wake_hour", 7)),
			"timezone_offset_minutes": int(settings_balance.get("timezone_offset_minutes", 480)),
			"debug_time_offset": int(settings_balance.get("debug_time_offset", 0)),
		},
	}


static func create_pet(now: int) -> Dictionary:
	var pet_balance: Dictionary = _dict(CareServiceScript.balance().get("pet", {}))
	var initial: Dictionary = _dict(pet_balance.get("initial", {}))
	return {
		"id": "pet-%d" % now,
		"name": "芽芽",
		"species": "sprout",
		"stage": "baby",
		"born_at": now,
		"stage_started_at": now,
		"age_seconds": 0,
		"fullness": float(initial.get("fullness", 70.0)),
		"mood": float(initial.get("mood", 75.0)),
		"energy": float(initial.get("energy", 80.0)),
		"health": float(initial.get("health", 100.0)),
		"cleanliness": float(initial.get("cleanliness", 100.0)),
		"weight": float(initial.get("weight", 2.0)),
		"training": {
			"power": 0,
			"guard": 0,
			"swift": 0,
		},
		"training_count": 0,
		"wins": 0,
		"losses": 0,
		"draws": 0,
		"battles": 0,
		"care_mistakes": 0,
		"sleep_seconds": 0,
		"behavior": "idle",
		"sleep_reason": "",
		"conditions": {
			"injured": false,
			"sick": false,
			"hibernating": false,
		},
		"lights_on": true,
		"poop": [],
		"poop_queue": [],
		"cooldowns": {},
		"care_timers": {},
		"need_events": {},
		"history": [],
		"evolutions": [],
		"evolution_modifiers": {
			"care": 0,
			"sleep": 0,
			"battle": 0,
		},
	}


static func stats(pet: Dictionary) -> Dictionary:
	var balance: Dictionary = CareServiceScript.balance()
	var pet_balance: Dictionary = _dict(balance.get("pet", {}))
	var evolution_balance: Dictionary = _dict(balance.get("evolution", {}))
	var stage: String = str(pet.get("stage", "baby"))
	var stage_base_config: Dictionary = _dict(pet_balance.get("stage_base_stats", {}))
	var stage_base: Dictionary = _dict(stage_base_config.get(stage, stage_base_config.get("baby", {})))
	var training_variant: Variant = pet.get("training", {})
	var training: Dictionary = training_variant if training_variant is Dictionary else {}
	var training_cap: int = int(pet_balance.get("training_stat_cap", 12))
	var power: int = clampi(int(training.get("power", 0)), 0, training_cap)
	var guard: int = clampi(int(training.get("guard", 0)), 0, training_cap)
	var swift: int = clampi(int(training.get("swift", 0)), 0, training_cap)

	var species_bonus_config: Dictionary = _dict(pet_balance.get("species_bonus", {}))
	var species_mod: Dictionary = _dict(species_bonus_config.get(str(pet.get("species", "sprout")), {}))
	var branch_config: Dictionary = _dict(evolution_balance.get("branch_modifiers", {}))
	var branch_mod: Dictionary = _dict(branch_config.get(str(pet.get("evolution_branch", "")), {}))

	# These modifiers are intentionally bounded.  Care history and battle
	# results can influence a mature profile without creating an infinite stat
	# loop in a long-running save.
	var finite_config: Dictionary = _dict(evolution_balance.get("finite_modifiers", {}))
	var care_modifier_config: Dictionary = _dict(finite_config.get("care", {}))
	var mistakes: int = clampi(int(pet.get("care_mistakes", 0)), 0, int(care_modifier_config.get("mistakes_cap", 3)))
	var care_modifier: int = clampi(
		int(care_modifier_config.get("base", 2)) - mistakes,
		int(care_modifier_config.get("min", -2)),
		int(care_modifier_config.get("max", 2))
	)
	var sleep_modifier_config: Dictionary = _dict(finite_config.get("sleep", {}))
	var sleep_seconds_per_hour: int = maxi(1, int(sleep_modifier_config.get("seconds_per_hour", 3600)))
	var sleep_hours: int = clampi(
		int(int(pet.get("sleep_seconds", 0)) / sleep_seconds_per_hour),
		int(sleep_modifier_config.get("min", 0)),
		int(sleep_modifier_config.get("max", 3))
	)
	var wins: int = int(pet.get("wins", 0))
	var losses: int = int(pet.get("losses", 0))
	var battle_modifier_config: Dictionary = _dict(finite_config.get("battle", {}))
	var battle_modifier: int = clampi(
		wins - losses,
		int(battle_modifier_config.get("min", -2)),
		int(battle_modifier_config.get("max", 3))
	)

	var attack: int = int(stage_base.get("attack", 8)) + power + int(species_mod.get("attack", 0))
	attack += int(branch_mod.get("attack", 0)) + care_modifier + battle_modifier
	var defense: int = int(stage_base.get("defense", 8)) + guard + int(species_mod.get("defense", 0))
	defense += int(branch_mod.get("defense", 0)) + care_modifier + sleep_hours
	var agility: int = int(stage_base.get("agility", 8)) + swift + int(species_mod.get("agility", 0))
	agility += int(branch_mod.get("agility", 0)) + care_modifier + battle_modifier
	var max_hp: int = int(stage_base.get("max_hp", 40)) + guard * 2 + care_modifier + sleep_hours + battle_modifier
	var stat_floor: int = int(pet_balance.get("stat_floor", 1))

	return {
		"attack": maxi(stat_floor, attack),
		"defense": maxi(stat_floor, defense),
		"agility": maxi(stat_floor, agility),
		"max_hp": maxi(stat_floor, max_hp),
	}


static func ideal_weight(pet: Dictionary) -> Vector2:
	var pet_balance: Dictionary = _dict(CareServiceScript.balance().get("pet", {}))
	var stage: String = str(pet.get("stage", "baby"))
	var ranges: Dictionary = _dict(pet_balance.get("ideal_weight", {}))
	var base: Dictionary = _dict(ranges.get(stage, ranges.get("baby", {})))
	var offsets: Dictionary = _dict(pet_balance.get("species_weight_offset", {}))
	var species_offset: float = float(offsets.get(str(pet.get("species", "sprout")), 0.0))
	return Vector2(float(base.get("min", 1.5)) + species_offset, float(base.get("max", 3.2)) + species_offset)


static func stage_name(pet: Dictionary) -> String:
	match str(pet.get("stage", "baby")):
		"baby":
			return "幼年"
		"growing":
			return "成長"
		"mature":
			return "成熟"
		_:
			return "未知"


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
