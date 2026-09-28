extends Node

signal changed
signal gold_changed(value: int)
signal kills_changed(value: int)
signal stage_changed(value: String)
signal combat_pause_changed(paused: bool)

const Catalog = preload("res://domain/progression_catalog.gd")
const NEW_GAME_GOLD: int = 500
const MAX_COUNTER: int = 999999999

var gold: int = NEW_GAME_GOLD
var kills: int = 0
var current_stage: String = "1-1"
var combat_paused: bool = false
var current_view: String = "adventure"

var training: Array[int] = Catalog.default_training()
var monsters: Dictionary = Catalog.default_monsters()
var deployed: Array[String] = Catalog.default_deployed()
var loadouts: Dictionary = Catalog.default_loadouts()
var equipment_levels: Dictionary = Catalog.default_equipment_levels()


func add_kill_reward(gold_reward: int) -> void:
	kills = mini(kills + 1, MAX_COUNTER)
	kills_changed.emit(kills)
	gold = mini(gold + maxi(gold_reward, 0), MAX_COUNTER)
	gold_changed.emit(gold)
	for monster_id: String in Catalog.MONSTER_IDS:
		if deployed.has(monster_id):
			_grant_monster_xp(monster_id, Catalog.KILL_MONSTER_XP)
	changed.emit()


func set_combat_paused(value: bool) -> void:
	if combat_paused == value:
		return
	combat_paused = value
	combat_pause_changed.emit(combat_paused)
	changed.emit()


func restore_session(data: Dictionary) -> void:
	var restored_gold: int = int(data.get("gold", NEW_GAME_GOLD))
	var restored_kills: int = int(data.get("kills", 0))
	var restored_stage: String = str(data.get("current_stage", "1-1"))
	gold = restored_gold
	kills = restored_kills
	current_stage = restored_stage
	var progression: Variant = data.get("progression", null)
	if typeof(progression) == TYPE_DICTIONARY:
		_apply_progression(progression as Dictionary)
	else:
		_apply_progression(Catalog.default_progression())
	gold_changed.emit(gold)
	kills_changed.emit(kills)
	stage_changed.emit(current_stage)
	changed.emit()


func save_snapshot() -> Dictionary:
	return {
		"version": 2,
		"last_active_timestamp": int(Time.get_unix_time_from_system()),
		"gold": gold,
		"kills": kills,
		"current_stage": current_stage,
		"progression": {
			"training": training.duplicate(),
			"monsters": monsters.duplicate(true),
			"deployed": deployed.duplicate(),
			"loadouts": loadouts.duplicate(true),
			"equipment_levels": equipment_levels.duplicate(true),
		},
	}


func monster_ids() -> Array[String]:
	return Catalog.MONSTER_IDS.duplicate()


func training_cost(index: int) -> int:
	if index < 0 or index >= training.size():
		return 0
	return Catalog.training_cost(index, training[index])


func train(index: int) -> Dictionary:
	if index < 0 or index >= training.size():
		return _failure("找不到這項訓練。")
	if training[index] >= Catalog.TRAINING_CAP:
		return _failure("這項訓練已達等級上限。")
	var cost: int = training_cost(index)
	if gold < cost:
		return _failure("金幣不足，訓練未開始。")
	gold -= cost
	training[index] += 1
	gold_changed.emit(gold)
	changed.emit()
	return _success("訓練完成，等級提升。")


func hero_info() -> Dictionary:
	var base: Dictionary = {
		"attack": 16.0 + float(training[0] - 1) * 2.0,
		"defense": 5.0,
		"health": 82.0 + float(training[1] - 1) * 8.0,
		"speed": 12.0 + float(training[2] - 1) * 0.8,
		"crit": 5.0,
		"regen": float(training[3] - 1) * 1.0,
	}
	var bonus: Dictionary = _equipment_bonus_for(Catalog.HERO_OWNER)
	return {
		"name": "騎士",
		"level": _hero_level(),
		"xp": 0,
		"xp_next": 0,
		"stats": _sum_stats(base, bonus),
		"base": base,
		"bonus": bonus,
		"deployed": true,
	}


func monster_info(monster_id: String) -> Dictionary:
	if not monsters.has(monster_id) or not Catalog.MONSTERS.has(monster_id):
		return {}
	var progression: Dictionary = monsters[monster_id]
	var level: int = int(progression.get("level", 1))
	var xp: int = int(progression.get("xp", 0))
	var base: Dictionary = Catalog.monster_base_stats(monster_id, level)
	var bonus: Dictionary = _equipment_bonus_for(monster_id)
	return {
		"name": str(Catalog.MONSTERS[monster_id]["name"]),
		"level": level,
		"xp": xp,
		"xp_next": Catalog.xp_to_next(level),
		"stats": _sum_stats(base, bonus),
		"base": base,
		"bonus": bonus,
		"deployed": deployed.has(monster_id),
	}


func items_for(owner: String, filter: String = "all") -> Array[Dictionary]:
	var owner_type: String = Catalog.owner_type(owner)
	var valid_filters: Array[String] = ["all", "weapon", "armor", "accessory", "other"]
	var items: Array[Dictionary] = []
	if owner_type.is_empty() or not valid_filters.has(filter):
		return items
	for definition: Dictionary in Catalog.ITEMS:
		if not Catalog.item_accepts_owner(definition, owner):
			continue
		if filter != "all" and str(definition["kind"]) != filter:
			continue
		var item_id: String = str(definition["id"])
		items.append({
			"id": item_id,
			"name": str(definition["name"]),
			"slot": str(definition["slot"]),
			"level": int(equipment_levels.get(item_id, 1)),
			"kind": str(definition["kind"]),
			"owner_type": str(definition["owner_type"]),
			"icon_index": int(definition["icon_index"]),
			"equipped_by": _equipped_by(item_id),
		})
	return items


func equipment_for(owner: String) -> Dictionary:
	if not loadouts.has(owner) or Catalog.owner_type(owner).is_empty():
		return {}
	return (loadouts[owner] as Dictionary).duplicate(true)


func equip(owner: String, item_id: String) -> Dictionary:
	if not loadouts.has(owner) or Catalog.owner_type(owner).is_empty():
		return _failure("找不到裝備角色。")
	var item: Dictionary = Catalog.item_by_id(item_id)
	if item.is_empty():
		return _failure("找不到這件裝備。")
	var slot: String = str(item["slot"])
	if not Catalog.item_accepts_owner_slot(item_id, owner, slot):
		return _failure("這件裝備不適用於該角色。")
	var current_layout: Dictionary = loadouts[owner]
	if str(current_layout.get(slot, "")) == item_id:
		return _success("裝備已穿戴。")
	# Validate everything first, then clear any prior slot and install the item as one mutation.
	for equipped_owner: String in Catalog.OWNERS:
		var layout: Dictionary = loadouts[equipped_owner]
		for equipped_slot: String in Catalog.owner_slots(equipped_owner):
			if str(layout.get(equipped_slot, "")) == item_id:
				layout[equipped_slot] = ""
	var destination: Dictionary = loadouts[owner]
	destination[slot] = item_id
	loadouts[owner] = destination
	changed.emit()
	return _success("裝備已穿戴。")


func unequip(owner: String, slot: String) -> Dictionary:
	if not loadouts.has(owner) or not Catalog.owner_slots(owner).has(slot):
		return _failure("找不到這個裝備欄位。")
	var layout: Dictionary = loadouts[owner]
	if str(layout.get(slot, "")).is_empty():
		return _failure("這個欄位目前是空的。")
	layout[slot] = ""
	loadouts[owner] = layout
	changed.emit()
	return _success("已卸下裝備。")


func upgrade_cost(item_id: String) -> int:
	if not Catalog.has_item(item_id):
		return 0
	return Catalog.equipment_upgrade_cost(int(equipment_levels.get(item_id, 1)))


func upgrade_equipment(item_id: String) -> Dictionary:
	if not Catalog.has_item(item_id):
		return _failure("找不到這件裝備。")
	var current_level: int = int(equipment_levels.get(item_id, 1))
	if current_level >= Catalog.EQUIPMENT_LEVEL_CAP:
		return _failure("裝備已達等級上限。")
	var cost: int = upgrade_cost(item_id)
	if gold < cost:
		return _failure("金幣不足，強化未完成。")
	gold -= cost
	equipment_levels[item_id] = current_level + 1
	gold_changed.emit(gold)
	changed.emit()
	return _success("裝備強化完成。")


func toggle_deployment(monster_id: String) -> Dictionary:
	if not Catalog.MONSTER_IDS.has(monster_id):
		return _failure("找不到這隻怪獸。")
	if deployed.has(monster_id):
		deployed.erase(monster_id)
		changed.emit()
		return _success("怪獸已撤下。")
	deployed.append(monster_id)
	changed.emit()
	return _success("怪獸已加入出戰。")


func add_monster_xp(monster_id: String, amount: int) -> void:
	if _grant_monster_xp(monster_id, amount):
		changed.emit()


func _grant_monster_xp(monster_id: String, amount: int) -> bool:
	if amount <= 0 or not monsters.has(monster_id):
		return false
	var progression: Dictionary = monsters[monster_id]
	var level: int = int(progression.get("level", 1))
	if level >= Catalog.MONSTER_LEVEL_CAP:
		return false
	var xp: int = mini(int(progression.get("xp", 0)) + amount, Catalog.MAX_XP)
	while level < Catalog.MONSTER_LEVEL_CAP:
		var threshold: int = Catalog.xp_to_next(level)
		if xp < threshold:
			break
		xp -= threshold
		level += 1
	if level >= Catalog.MONSTER_LEVEL_CAP:
		xp = 0
	progression["level"] = level
	progression["xp"] = xp
	monsters[monster_id] = progression
	return true


func _apply_progression(progression: Dictionary) -> void:
	training.clear()
	for level: Variant in progression.get("training", Catalog.default_training()):
		training.append(int(level))
	monsters = (progression.get("monsters", Catalog.default_monsters()) as Dictionary).duplicate(true)
	deployed.clear()
	for monster_id: Variant in progression.get("deployed", Catalog.default_deployed()):
		deployed.append(str(monster_id))
	loadouts = (progression.get("loadouts", Catalog.default_loadouts()) as Dictionary).duplicate(true)
	equipment_levels = (progression.get("equipment_levels", Catalog.default_equipment_levels()) as Dictionary).duplicate(true)


func _hero_level() -> int:
	var total: int = 0
	for level: int in training:
		total += level
	return maxi(total - (Catalog.TRAINING_NAMES.size() - 1), 1)


func _equipment_bonus_for(owner: String) -> Dictionary:
	var bonus: Dictionary = _zero_stats()
	var layout: Dictionary = loadouts.get(owner, {})
	for slot: String in Catalog.owner_slots(owner):
		var item_id: String = str(layout.get(slot, ""))
		if item_id.is_empty():
			continue
		var item_level: int = int(equipment_levels.get(item_id, 1))
		var item_bonus: Dictionary = Catalog.item_bonus(item_id, item_level)
		for stat: String in Catalog.STAT_KEYS:
			bonus[stat] = float(bonus[stat]) + float(item_bonus[stat])
	return bonus


func _sum_stats(base: Dictionary, bonus: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for stat: String in Catalog.STAT_KEYS:
		result[stat] = float(base.get(stat, 0.0)) + float(bonus.get(stat, 0.0))
	return result


func _zero_stats() -> Dictionary:
	return {"attack": 0.0, "defense": 0.0, "health": 0.0, "speed": 0.0, "crit": 0.0, "regen": 0.0}


func _equipped_by(item_id: String) -> String:
	for owner: String in Catalog.OWNERS:
		var layout: Dictionary = loadouts[owner]
		for slot: String in Catalog.owner_slots(owner):
			if str(layout.get(slot, "")) == item_id:
				return owner
	return ""


func _success(message: String) -> Dictionary:
	return {"ok": true, "message": message}


func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
