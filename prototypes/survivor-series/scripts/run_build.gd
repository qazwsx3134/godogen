extends RefCounted
## A run's mutable choices. Never writes back into shared Resource definitions.
## Weapons and passives fill separate slots; an evolution replaces its base weapon in place.
var config: Resource
## Permanent shop bonuses by stat name; added on top of passives.
var bonus: Dictionary = {}
## Achievement ids unlocked in the meta save.
var unlocked: Dictionary = {}
var level: int = 1
var experience: float = 0.0
var total_experience: float = 0.0
var pending_choices: int = 0
var levels: Dictionary = {}
var weapons: Array[StringName] = []
var passives: Array[StringName] = []
var picked_ids: Array[StringName] = []
var rng := RandomNumberGenerator.new()
## Fusion ids the player has already discovered (card shows its real name).
var discovered: Dictionary = {}

func _init(definition: Resource, meta_bonus: Dictionary = {}, unlocks: Array = [], opening: StringName = &"") -> void:
	config = definition
	bonus = meta_bonus.duplicate()
	for id: Variant in unlocks:
		unlocked[StringName(id)] = true
	rng.randomize()
	var first: StringName = opening if opening != &"" else config.start_weapon
	if first != &"":
		levels[first] = 1
		weapons.append(first)

func threshold() -> int:
	var late: int = maxi(0, level - config.late_level) * config.late_xp_growth
	return maxi(1, config.first_level_xp + (level - 1) * config.level_xp_growth + late)

func award(amount: float) -> void:
	if amount <= 0.0:
		return
	var gained: float = amount * (1.0 + stat(&"growth"))
	experience += gained
	total_experience += gained
	while experience >= threshold():
		experience -= threshold()
		level += 1
		pending_choices += 1

func count(id: StringName) -> int:
	return int(levels.get(id, 0))

func definition(id: StringName) -> Resource:
	for item: Resource in config.items:
		if item.id == id:
			return item
	for item: Resource in config.fillers:
		if item.id == id:
			return item
	return null

func available(item: Resource) -> bool:
	return item.unlock == &"" or unlocked.has(item.unlock)

func eligible(item: Resource) -> bool:
	if item == null or not available(item):
		return false
	match item.slot:
		"weapon":
			if count(item.id) > 0:
				return count(item.id) < item.max_level
			return weapons.size() < config.weapon_slots and not (item.evolve_into != &"" and count(item.evolve_into) > 0) and not fused_away(item.id)
		"passive":
			if count(item.id) > 0:
				return count(item.id) < item.max_level
			return passives.size() < config.passive_slots
		"evolution":
			var base: Resource = definition(item.replaces)
			return count(item.id) == 0 and base != null and count(base.id) >= base.max_level and count(base.evolve_passive) > 0
		"fusion":
			return count(item.id) == 0 and count(item.fuse_a) >= item.fuse_level and count(item.fuse_b) >= item.fuse_level
	return false

## True when a fusion built from this weapon is already owned; the parts do not come back as new cards.
func fused_away(id: StringName) -> bool:
	for item: Resource in config.items:
		if item.slot == "fusion" and count(item.id) > 0 and (item.fuse_a == id or item.fuse_b == id):
			return true
	return false

func offers() -> Array[Resource]:
	var result: Array[Resource] = []
	var pool: Array[Resource] = []
	# The first level-up offers only new weapons, so every run picks a direction early.
	var opening: bool = picked_ids.is_empty()
	for item: Resource in config.items:
		if eligible(item) and (not opening or (item.slot == "weapon" and count(item.id) == 0)):
			if item.slot == "evolution" or item.slot == "fusion":
				result.append(item)
			else:
				pool.append(item)
	while result.size() < 3 and not pool.is_empty():
		var index: int = rng.randi_range(0, pool.size() - 1)
		result.append(pool[index])
		pool.remove_at(index)
	if result.is_empty():
		for item: Resource in config.fillers:
			result.append(item)
	return result.slice(0, 3)

func pick(id: StringName) -> bool:
	var item: Resource = definition(id)
	if pending_choices <= 0 or item == null:
		return false
	if item.slot == "filler":
		if not offers().has(item):
			return false
	elif not eligible(item):
		return false
	match item.slot:
		"weapon":
			if count(id) == 0:
				weapons.append(id)
			levels[id] = count(id) + 1
		"passive":
			if count(id) == 0:
				passives.append(id)
			levels[id] = count(id) + 1
		"evolution":
			weapons[weapons.find(item.replaces)] = id
			levels.erase(item.replaces)
			levels[id] = 1
		"fusion":
			for part: StringName in [item.fuse_a, item.fuse_b]:
				weapons.erase(part)
				levels.erase(part)
			weapons.append(id)
			levels[id] = 1
	picked_ids.append(id)
	pending_choices -= 1
	return true

## Passive levels plus permanent shop bonus for one stat.
func stat(name: StringName) -> float:
	var total: float = float(bonus.get(name, 0.0))
	for id: StringName in passives:
		var item: Resource = definition(id)
		if item.stat == name:
			total += item.per_level * count(id)
	return total

func weapon_stats(id: StringName) -> Dictionary:
	var item: Resource = definition(id)
	var at: int = maxi(1, count(id))
	var amount: int = item.amount
	for grow_at: int in item.amount_levels:
		if at >= grow_at:
			amount += 1
	var base_cooldown: float = item.cooldown * maxf(0.2, 1.0 - item.cooldown_per_level * (at - 1))
	return {
		"id": id,
		"kind": item.kind,
		"variant": item.variant,
		"level": at,
		"damage": (item.damage + item.damage_per_level * (at - 1)) * (1.0 + stat(&"might")),
		"cooldown": maxf(0.08, base_cooldown * maxf(0.4, 1.0 - stat(&"cooldown"))),
		"amount": amount,
		"area": (item.area + item.area_per_level * (at - 1)) * (1.0 + stat(&"area")),
		"speed": item.speed,
		"duration": item.duration,
		"pierce": item.pierce,
		"knockback": item.knockback,
		"slow": item.slow,
		"pull": item.pull,
		"blast_on_end": item.blast_on_end,
		"special": item.special_level > 0 and at >= item.special_level,
		"projectile": item.projectile,
	}

func card_note(item: Resource) -> String:
	var at: int = count(item.id)
	if at == 0 or item.slot != "weapon" and item.slot != "passive":
		return item.description
	var index: int = at - 1
	return item.level_notes[index] if index < item.level_notes.size() else item.description

func summary() -> String:
	var lines: PackedStringArray = []
	for id: StringName in weapons + passives:
		var item: Resource = definition(id)
		lines.append("%s %d" % [item.title, count(id)] if item.slot != "evolution" and item.slot != "fusion" else item.title)
	return "、".join(lines)
