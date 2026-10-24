extends RefCounted
## Read-only view of design/tuning-draft.json: the single source of every combat number.
## Derived stats live here so the battle, the HUD and tests agree on one formula.

const PATH := "res://design/tuning-draft.json"

var data: Dictionary
var monsters: Dictionary = {}
var items: Dictionary = {}
var equipment: Dictionary = {}
var skills: Dictionary = {}
var quests: Dictionary = {}
var utilities: Dictionary = {}
var weapon_speed: Dictionary = {}


static func load_default() -> RefCounted:
	var file := FileAccess.open(PATH, FileAccess.READ)
	assert(file != null, "tuning missing: " + PATH)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert(parsed is Dictionary, "tuning is not a JSON object")
	return new(parsed)


func _init(source: Dictionary) -> void:
	data = source
	for list_name: String in ["monsters", "items", "equipment_templates", "skills", "quest_definitions"]:
		var target: Dictionary = {"monsters": monsters, "items": items, "equipment_templates": equipment,
			"skills": skills, "quest_definitions": quests}[list_name]
		for entry: Dictionary in data[list_name]:
			target[entry.id] = entry
	for entry: Dictionary in data.party.utilities:
		utilities[entry.id] = entry
	for entry: Dictionary in data.weapon_profiles:
		weapon_speed[entry.id] = float(entry.speed_ratio)
	# The two formulas are implemented below, not evaluated; editing the text must fail loudly.
	assert(data.simulation.level_xp_formula == "ceil(200 * level ** 1.8)", "update xp_needed()")
	assert(data.simulation.low_level_xp_formula == "max(0.1, 0.8 ** max(0, team_level - monster_level - 3))",
		"update xp_penalty()")


func section(name: String) -> Dictionary:
	return data[name]


func step_ms() -> int:
	return int(data.simulation.step_ms)


func xp_needed(level: int) -> int:
	return ceili(200.0 * pow(level, 1.8))


func xp_penalty(team_level: int, monster_level: int) -> float:
	return maxf(0.1, pow(0.8, maxi(0, team_level - monster_level - 3)))


## Final stats of a party member at an expedition level: role-scaled base plus gear.
func member_stats(role: String, level: int) -> Dictionary:
	var hero: Dictionary = data.hero
	var ratio: Dictionary = data.party.roles[role]
	var base_hp: float = hero.hp_base + hero.hp_per_level * (level - 1)
	var base_atk: float = hero.attack_base + hero.attack_per_level * (level - 1)
	var base_def: float = hero.defense_base + hero.defense_per_level * (level - 1)
	var stats := {
		"max_hp": base_hp * ratio.hp_ratio,
		"attack": base_atk * ratio.attack_ratio,
		"defense": base_def * ratio.defense_ratio,
		"agility": float(hero.agility_base + hero.agility_per_level * (level - 1)),
		"crit_chance": float(data.combat.crit_chance),
		"block_chance": 0.0,
		"style": "sword",
		"shield": false,
	}
	for item_id: String in data.party.initial_equipment[role]:
		var template: Dictionary = equipment[item_id]
		if template.slot == "weapon":
			stats.style = template.style
		if template.slot == "offhand":
			stats.shield = true
		for key: String in template.bonus:
			stats[key] = stats.get(key, 0.0) + float(template.bonus[key])
	stats.attack_ms = attack_interval_ms(stats.agility, stats.style, stats.shield)
	return stats


func attack_interval_ms(agility: float, style: String, shield: bool) -> float:
	var combat: Dictionary = data.combat
	var speed: float = weapon_speed[style]
	if shield and style != "mace":
		speed *= float(combat.shield_speed_ratio_non_mace)
	return maxf(float(combat.attack_min_ms), float(combat.attack_base_ms) / (1.0 + agility / 100.0) / speed)
