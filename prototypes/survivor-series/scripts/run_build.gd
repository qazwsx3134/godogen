extends RefCounted
## A run's mutable choices. Never writes back into shared Resource definitions.
var config: Resource
var level: int = 1
var experience: int = 0
var total_experience: int = 0
var pending_choices: int = 0
var stacks: Dictionary = {}
var picked_ids: Array[StringName] = []
var rng := RandomNumberGenerator.new()

func _init(definition: Resource) -> void:
	config = definition
	rng.randomize()

func threshold() -> int:
	return maxi(1, config.first_level_xp + (level - 1) * config.level_xp_growth)

func award(amount: int) -> void:
	if amount <= 0:
		return
	experience += amount
	total_experience += amount
	while experience >= threshold():
		experience -= threshold()
		level += 1
		pending_choices += 1

func count(id: StringName) -> int:
	return int(stacks.get(id, 0))

func definition(id: StringName) -> Resource:
	for item: Resource in config.upgrades:
		if item.id == id:
			return item
	return null

func eligible(item: Resource) -> bool:
	return item != null and count(item.id) < item.max_stacks and (item.prerequisite == &"" or count(item.prerequisite) > 0)

func offers() -> Array[Resource]:
	var result: Array[Resource] = []
	if picked_ids.is_empty():
		for id: StringName in config.first_choices:
			if result.size() >= 3:
				break
			var item: Resource = definition(id)
			if eligible(item) and not result.has(item):
				result.append(item)
	var pool: Array[Resource] = []
	for item: Resource in config.upgrades:
		if eligible(item) and not result.has(item):
			pool.append(item)
	while result.size() < 3 and not pool.is_empty():
		var index: int = rng.randi_range(0, pool.size() - 1)
		result.append(pool[index])
		pool.remove_at(index)
	return result

func pick(id: StringName) -> bool:
	if pending_choices <= 0 or not eligible(definition(id)):
		return false
	stacks[id] = count(id) + 1
	picked_ids.append(id)
	pending_choices -= 1
	return true

func value(id: StringName) -> float:
	var item: Resource = definition(id)
	return item.value * count(id) if item != null else 0.0

func damage(base: float) -> float:
	return base * (1.0 + value(&"power"))

func interval(base: float) -> float:
	return maxf(0.16, base / (1.0 + value(&"speed")))

func reach(base: float) -> float:
	return base + value(&"reach")

func force() -> float:
	return 1.0 + value(&"force")

func summary() -> String:
	var lines: PackedStringArray = []
	for item: Resource in config.upgrades:
		if count(item.id) > 0:
			lines.append("%s ×%d" % [item.title, count(item.id)])
	return "、".join(lines) if not lines.is_empty() else "基礎拳擊"
