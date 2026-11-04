extends RefCounted
## Weighted upgrade drafts from {id, kind, weight, max_level, branch, requires} cards.
## `const CardDraft = preload("res://addons/proto_kit/card_draft.gd")`
## Ultimate cards do not occupy skill slots; ultimate_need defaults to 3.
## from_dict restores the state of the caller-provided RNG; use a dedicated RNG.

var current: Array[String] = []
var rerolls_left: int
var banishes_left: int
var _cards: Dictionary = {}
var _levels: Dictionary = {}
var _banished: Array[String] = []
var _rng: RandomNumberGenerator
var _slots: int
var _offer_count: int = 3

func _init(pool: Array[Dictionary], rng: RandomNumberGenerator, options: Dictionary = {}) -> void:
	_rng = rng
	_slots = int(options.get("slots", 7))
	rerolls_left = int(options.get("rerolls", 0))
	banishes_left = int(options.get("banishes", 0))
	for card: Dictionary in pool:
		_cards[str(card.id)] = card.duplicate(true)

func level(id: String) -> int:
	return int(_levels.get(id, 0))

func slots_used() -> int:
	var count: int = 0
	for id: String in _cards:
		if _cards[id].get("kind", "upgrade") == "skill" and level(id) > 0:
			count += 1
	return count

func branch_progress(branch: String) -> int:
	var count: int = 0
	for id: String in _cards:
		if str(_cards[id].get("branch", "")) == branch:
			count += level(id)
	return count

func ultimate_ready(branch: String, need: int) -> bool:
	return branch_progress(branch) >= need

func _eligible(id: String) -> bool:
	var card: Dictionary = _cards[id]
	if id in _banished or level(id) >= int(card.get("max_level", 1)) or float(card.get("weight", 1.0)) <= 0.0:
		return false
	for required: Variant in card.get("requires", []):
		if level(str(required)) == 0:
			return false
	if card.get("kind", "upgrade") == "skill" and level(id) == 0 and slots_used() >= _slots:
		return false
	if card.get("kind", "upgrade") == "ultimate":
		return ultimate_ready(str(card.get("branch", "")), int(card.get("ultimate_need", 3)))
	return true

func _draw(count: int, excluded: Array[String], avoid: Array[String]) -> Array[String]:
	var preferred: Array[String] = []
	var fallback: Array[String] = []
	for id: String in _cards:
		if _eligible(id) and id not in excluded:
			if id in avoid:
				fallback.append(id)
			else:
				preferred.append(id)
	var result: Array[String] = []
	while result.size() < count and (not preferred.is_empty() or not fallback.is_empty()):
		var candidates: Array[String] = preferred if not preferred.is_empty() else fallback
		var total: float = 0.0
		for id: String in candidates:
			total += float(_cards[id].get("weight", 1.0))
		var roll: float = _rng.randf() * total
		var chosen: String = candidates.back()
		for id: String in candidates:
			roll -= float(_cards[id].get("weight", 1.0))
			if roll <= 0.0:
				chosen = id
				break
		result.append(chosen)
		candidates.erase(chosen)
	return result

func offer(count: int = 3) -> Array:
	_offer_count = maxi(0, count)
	current = _draw(_offer_count, [], [])
	return current.duplicate()

func pick(id: String) -> bool:
	if id not in current:
		return false
	_levels[id] = level(id) + 1
	current.clear()
	return true

func reroll() -> bool:
	if rerolls_left <= 0 or current.is_empty():
		return false
	rerolls_left -= 1
	current = _draw(_offer_count, [], current)
	return true

func banish(id: String) -> bool:
	if banishes_left <= 0 or id not in current:
		return false
	banishes_left -= 1
	_banished.append(id)
	current.erase(id)
	current.append_array(_draw(1, current, []))
	return true

func to_dict() -> Dictionary:
	return {"levels": _levels.duplicate(), "banished": _banished.duplicate(), "rerolls": rerolls_left, "banishes": banishes_left, "current": current.duplicate(), "offer_count": _offer_count, "rng_state": str(_rng.state)}

func from_dict(data: Dictionary) -> void:
	_levels.clear()
	for id: String in data.get("levels", {}):
		if _cards.has(id):
			_levels[id] = clampi(int(data.levels[id]), 0, int(_cards[id].get("max_level", 1)))
	_banished.clear()
	for id: Variant in data.get("banished", []):
		if _cards.has(str(id)) and str(id) not in _banished:
			_banished.append(str(id))
	rerolls_left = maxi(0, int(data.get("rerolls", 0)))
	banishes_left = maxi(0, int(data.get("banishes", 0)))
	_offer_count = maxi(0, int(data.get("offer_count", 3)))
	current.clear()
	for id: Variant in data.get("current", []):
		if _cards.has(str(id)) and _eligible(str(id)) and str(id) not in current:
			current.append(str(id))
	if data.has("rng_state"):
		_rng.state = int(data.rng_state)
