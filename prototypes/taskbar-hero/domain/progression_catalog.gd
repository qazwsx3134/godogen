extends RefCounted
class_name ProgressionCatalog
## Immutable progression definitions. Player-owned levels, loadouts and training live in Game.

const HERO_OWNER: String = "hero"
const MONSTER_IDS: Array[String] = ["sprout", "fox", "aqua", "mushroom"]
const OWNERS: Array[String] = ["hero", "sprout", "fox", "aqua", "mushroom"]
const HERO_SLOTS: Array[String] = ["weapon", "shield", "armor", "helmet", "boots", "accessory"]
const MONSTER_SLOTS: Array[String] = ["necklace", "badge", "armor", "claws", "cape", "accessory"]
const TRAINING_NAMES: Array[String] = ["劍術", "耐力", "速度", "休息"]
const STAT_KEYS: Array[String] = ["attack", "defense", "health", "speed", "crit", "regen"]
const TRAINING_CAP: int = 99
const MONSTER_LEVEL_CAP: int = 99
const EQUIPMENT_LEVEL_CAP: int = 99
const KILL_MONSTER_XP: int = 12
const MAX_XP: int = 999999999

## icon_index is a stable zero-based catalog index for the UI's reference atlas mapping.
const ITEMS: Array[Dictionary] = [
	{"id": "hero_sword", "name": "鐵劍", "slot": "weapon", "kind": "weapon", "owner_type": "hero", "icon_index": 0, "bonus_per_level": {"attack": 1.2}},
	{"id": "hero_bow", "name": "獵弓", "slot": "weapon", "kind": "weapon", "owner_type": "hero", "icon_index": 1, "bonus_per_level": {"attack": 0.8, "speed": 0.2}},
	{"id": "hero_staff", "name": "湛藍法杖", "slot": "weapon", "kind": "weapon", "owner_type": "hero", "icon_index": 2, "bonus_per_level": {"attack": 0.6, "regen": 0.5}},
	{"id": "hero_shield", "name": "圓盾", "slot": "shield", "kind": "armor", "owner_type": "hero", "icon_index": 3, "bonus_per_level": {"defense": 1.0}},
	{"id": "hero_armor", "name": "冒險者鎧甲", "slot": "armor", "kind": "armor", "owner_type": "hero", "icon_index": 4, "bonus_per_level": {"health": 4.5, "defense": 0.2}},
	{"id": "hero_helmet", "name": "羽飾頭盔", "slot": "helmet", "kind": "armor", "owner_type": "hero", "icon_index": 5, "bonus_per_level": {"defense": 1.0, "health": 1.5}},
	{"id": "hero_boots", "name": "旅人靴", "slot": "boots", "kind": "armor", "owner_type": "hero", "icon_index": 6, "bonus_per_level": {"speed": 0.4}},
	{"id": "hero_ring", "name": "紅寶石戒指", "slot": "accessory", "kind": "accessory", "owner_type": "both", "icon_index": 7, "bonus_per_level": {"crit": 0.8, "attack": 0.2}},
	{"id": "monster_necklace", "name": "翡翠項圈", "slot": "necklace", "kind": "accessory", "owner_type": "monster", "icon_index": 8, "bonus_per_level": {"regen": 0.8}},
	{"id": "monster_badge", "name": "翠葉徽章", "slot": "badge", "kind": "other", "owner_type": "monster", "icon_index": 9, "bonus_per_level": {"health": 2.5, "defense": 0.2}},
	{"id": "monster_armor", "name": "獸族護甲", "slot": "armor", "kind": "armor", "owner_type": "monster", "icon_index": 10, "bonus_per_level": {"defense": 1.0, "health": 2.0}},
	{"id": "monster_claws", "name": "利爪護套", "slot": "claws", "kind": "accessory", "owner_type": "monster", "icon_index": 11, "bonus_per_level": {"attack": 0.9}},
	{"id": "monster_blue_cape", "name": "藍紋披風", "slot": "cape", "kind": "armor", "owner_type": "monster", "icon_index": 12, "bonus_per_level": {"defense": 0.4, "speed": 0.3}},
	{"id": "monster_red_cape", "name": "赤焰披風", "slot": "cape", "kind": "armor", "owner_type": "monster", "icon_index": 13, "bonus_per_level": {"health": 2.0, "crit": 0.3}},
	{"id": "monster_tail_flower", "name": "尾羽花飾", "slot": "accessory", "kind": "accessory", "owner_type": "monster", "icon_index": 14, "bonus_per_level": {"regen": 0.5, "crit": 0.4}},
]

const MONSTERS: Dictionary = {
	"sprout": {
		"name": "芽芽",
		"base": {"attack": 10.0, "defense": 3.0, "health": 48.0, "speed": 9.0, "crit": 3.0, "regen": 2.0},
		"growth": {"attack": 2.0, "defense": 0.8, "health": 12.0, "speed": 0.4, "crit": 0.25, "regen": 0.5},
	},
	"fox": {
		"name": "小狐",
		"base": {"attack": 14.0, "defense": 4.0, "health": 40.0, "speed": 13.0, "crit": 8.0, "regen": 0.5},
		"growth": {"attack": 2.4, "defense": 0.6, "health": 9.0, "speed": 0.8, "crit": 0.5, "regen": 0.2},
	},
	"aqua": {
		"name": "水靈",
		"base": {"attack": 11.0, "defense": 5.0, "health": 55.0, "speed": 10.0, "crit": 4.0, "regen": 3.0},
		"growth": {"attack": 1.8, "defense": 1.0, "health": 13.0, "speed": 0.4, "crit": 0.2, "regen": 0.8},
	},
	"mushroom": {
		"name": "蘑菇仔",
		"base": {"attack": 12.0, "defense": 6.0, "health": 60.0, "speed": 8.0, "crit": 5.0, "regen": 2.5},
		"growth": {"attack": 2.0, "defense": 1.1, "health": 14.0, "speed": 0.3, "crit": 0.2, "regen": 0.7},
	},
}

static func default_training() -> Array[int]:
	# Fresh sessions start at level one in each hero-only track; v1 gold is migrated separately.
	return [1, 1, 1, 1]


static func default_monsters() -> Dictionary:
	var result: Dictionary = {}
	for monster_id: String in MONSTER_IDS:
		result[monster_id] = {"level": 1, "xp": 0}
	return result


static func default_deployed() -> Array[String]:
	return MONSTER_IDS.duplicate()


static func default_loadouts() -> Dictionary:
	var result: Dictionary = {}
	for owner: String in OWNERS:
		var layout: Dictionary = {}
		for slot: String in owner_slots(owner):
			layout[slot] = ""
		result[owner] = layout
	result["hero"].merge({
		"weapon": "hero_sword",
		"shield": "hero_shield",
		"armor": "hero_armor",
		"helmet": "hero_helmet",
		"boots": "hero_boots",
		"accessory": "hero_ring",
	}, true)
	result["sprout"].merge({
		"necklace": "monster_necklace",
		"badge": "monster_badge",
		"armor": "monster_armor",
		"claws": "monster_claws",
		"cape": "monster_blue_cape",
		"accessory": "monster_tail_flower",
	}, true)
	return result


static func default_equipment_levels() -> Dictionary:
	return {
		"hero_sword": 10,
		"hero_bow": 8,
		"hero_staff": 6,
		"hero_shield": 8,
		"hero_armor": 8,
		"hero_helmet": 6,
		"hero_boots": 6,
		"hero_ring": 8,
		"monster_necklace": 8,
		"monster_badge": 6,
		"monster_armor": 8,
		"monster_claws": 6,
		"monster_blue_cape": 5,
		"monster_red_cape": 5,
		"monster_tail_flower": 6,
	}


static func default_progression() -> Dictionary:
	return {
		"training": default_training(),
		"monsters": default_monsters(),
		"deployed": default_deployed(),
		"loadouts": default_loadouts(),
		"equipment_levels": default_equipment_levels(),
	}


static func owner_type(owner: String) -> String:
	if owner == HERO_OWNER:
		return "hero"
	if MONSTER_IDS.has(owner):
		return "monster"
	return ""


static func owner_slots(owner: String) -> Array[String]:
	if owner == HERO_OWNER:
		return HERO_SLOTS.duplicate()
	if MONSTER_IDS.has(owner):
		return MONSTER_SLOTS.duplicate()
	return []


static func item_by_id(item_id: String) -> Dictionary:
	for item: Dictionary in ITEMS:
		if str(item["id"]) == item_id:
			return item.duplicate(true)
	return {}


static func has_item(item_id: String) -> bool:
	return not item_by_id(item_id).is_empty()


static func item_accepts_owner(item: Dictionary, owner: String) -> bool:
	var category: String = owner_type(owner)
	var accepted_type: String = str(item.get("owner_type", ""))
	return not category.is_empty() and (accepted_type == category or accepted_type == "both")


static func item_accepts_owner_slot(item_id: String, owner: String, slot: String) -> bool:
	var item: Dictionary = item_by_id(item_id)
	return not item.is_empty() \
		and owner_slots(owner).has(slot) \
		and str(item.get("slot", "")) == slot \
		and item_accepts_owner(item, owner)


static func training_cost(index: int, current_level: int) -> int:
	if index < 0 or index >= TRAINING_NAMES.size() or current_level >= TRAINING_CAP:
		return 0
	var base_costs: Array[int] = [35, 30, 25, 20]
	var growth_costs: Array[int] = [16, 14, 12, 10]
	return base_costs[index] + (current_level - 1) * growth_costs[index]


static func xp_to_next(level: int) -> int:
	if level >= MONSTER_LEVEL_CAP:
		return 0
	return 80 + maxi(level - 1, 0) * 24


static func equipment_upgrade_cost(current_level: int) -> int:
	if current_level >= EQUIPMENT_LEVEL_CAP:
		return 0
	return 20 + current_level * 18


static func monster_base_stats(monster_id: String, level: int) -> Dictionary:
	var definition: Dictionary = MONSTERS.get(monster_id, {})
	if definition.is_empty():
		return _zero_stats()
	var base: Dictionary = definition["base"]
	var growth: Dictionary = definition["growth"]
	var stats: Dictionary = {}
	for key: String in STAT_KEYS:
		stats[key] = float(base.get(key, 0.0)) + float(growth.get(key, 0.0)) * float(maxi(level - 1, 0))
	return stats


static func item_bonus(item_id: String, level: int) -> Dictionary:
	var stats: Dictionary = _zero_stats()
	var item: Dictionary = item_by_id(item_id)
	if item.is_empty():
		return stats
	var per_level: Dictionary = item.get("bonus_per_level", {})
	for key: String in STAT_KEYS:
		stats[key] = float(per_level.get(key, 0.0)) * float(level)
	return stats


static func _zero_stats() -> Dictionary:
	return {"attack": 0.0, "defense": 0.0, "health": 0.0, "speed": 0.0, "crit": 0.0, "regen": 0.0}
