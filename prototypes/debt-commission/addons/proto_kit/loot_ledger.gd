extends RefCounted
## Boss drops and the permanent gear collection of a survivor-like: zones in order, each with timed bosses that each
## drop one item at a chance; collected items stay forever, one per slot is worn and adds its stats. Beating a zone's
## final boss opens the next zone. `const LootLedger = preload("res://addons/proto_kit/loot_ledger.gd")`
##
##   var ledger := LootLedger.new([
##       {"id": "forest", "tier": 0, "bosses": [
##           {"id": "hogger", "at": 180, "chance": 0.6, "item": {"id": "recruit_helm", "slot": "head", "stats": {"hp": 20}}},
##           {"id": "vancleef", "at": 960, "final": true, "chance": 0.6, "item": {...}}]},
##       {"id": "duskwood", "tier": 1, "bosses": [...]}])
##   var item := ledger.roll_drop("forest", "hogger", rng)   # {} on a miss or an item already owned
##   if not item.is_empty(): ledger.collect(item.id)         # the game may show it first; collect() equips if the slot is free
##   ledger.defeat_final("forest")                           # unlocks "duskwood"
##   ledger.worn_stats()                                     # {"hp": 20}
##   ledger.wanted(5)                                        # the next items to farm, nearest zone first
##
## An item's tier is its zone's tier unless the item sets one. `luck` adds to the drop chance (0.05 = +5 points).

var unlocked: int = 1

var _zones: Array = []
var _items: Dictionary = {}     # item id -> item (with "zone", "boss", "tier", "chance")
var _owned: Dictionary = {}     # item id -> true
var _worn: Dictionary = {}      # slot -> item id


func _init(zones: Array) -> void:
	_zones = zones
	for zone: Dictionary in zones:
		for boss: Dictionary in zone.get("bosses", []):
			var item: Dictionary = boss.item.duplicate(true)
			item["zone"] = zone.id
			item["boss"] = boss.id
			item["tier"] = int(item.get("tier", zone.get("tier", 0)))
			item["chance"] = float(boss.get("chance", 1.0))
			_items[item.id] = item


func zone_ids() -> Array[String]:
	var out: Array[String] = []
	for zone: Dictionary in _zones:
		out.append(zone.id)
	return out


func is_unlocked(zone_id: String) -> bool:
	return zone_ids().find(zone_id) in range(unlocked)


## Opens the zone after this one (the final boss died). Returns the zone id it opened, or "".
func defeat_final(zone_id: String) -> String:
	var index := zone_ids().find(zone_id)
	if index < 0 or index + 1 >= _zones.size() or index + 1 < unlocked:
		return ""
	unlocked = index + 2
	return _zones[index + 1].id


## The boss's item if the roll succeeds and it is not owned yet; {} otherwise (show gold instead, for example).
func roll_drop(zone_id: String, boss_id: String, rng: RandomNumberGenerator, luck: float = 0.0) -> Dictionary:
	for item: Dictionary in _items.values():
		if item.zone == zone_id and item.boss == boss_id:
			if _owned.has(item.id) or rng.randf() >= item.chance + luck:
				return {}
			return item
	return {}


## Adds an item to the collection for good; wears it when its slot is empty. False if unknown or already owned.
func collect(item_id: String) -> bool:
	if not _items.has(item_id) or _owned.has(item_id):
		return false
	_owned[item_id] = true
	var slot: String = _items[item_id].slot
	if not _worn.has(slot):
		_worn[slot] = item_id
	return true


func owns(item_id: String) -> bool:
	return _owned.has(item_id)


func wear(item_id: String) -> bool:
	if not _owned.has(item_id):
		return false
	_worn[_items[item_id].slot] = item_id
	return true


func worn() -> Dictionary:
	return _worn.duplicate()


func worn_stats() -> Dictionary:
	var out := {}
	for item_id: String in _worn.values():
		var stats: Dictionary = _items[item_id].get("stats", {})
		for stat: String in stats:
			out[stat] = out.get(stat, 0.0) + float(stats[stat])
	return out


## Owned / total, overall or for one tier.
func progress(tier: int = -1) -> Vector2i:
	var have := 0
	var total := 0
	for item: Dictionary in _items.values():
		if tier < 0 or item.tier == tier:
			total += 1
			if _owned.has(item.id):
				have += 1
	return Vector2i(have, total)


## Items still missing in unlocked zones, zone order then boss time: what the next runs should farm.
func wanted(limit: int = 5) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index in mini(unlocked, _zones.size()):
		var bosses: Array = _zones[index].get("bosses", []).duplicate()
		bosses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("at", 0)) < float(b.get("at", 0)))
		for boss: Dictionary in bosses:
			if not _owned.has(boss.item.id) and out.size() < limit:
				out.append(_items[boss.item.id])
	return out


func to_dict() -> Dictionary:
	return {"unlocked": unlocked, "owned": _owned.keys(), "worn": _worn.duplicate()}


func from_dict(data: Dictionary) -> void:
	unlocked = clampi(int(data.get("unlocked", 1)), 1, maxi(1, _zones.size()))
	_owned.clear()
	for id in data.get("owned", []):
		if _items.has(id):
			_owned[id] = true
	_worn.clear()
	var saved: Dictionary = data.get("worn", {})
	for slot in saved:
		if _owned.has(saved[slot]) and _items[saved[slot]].slot == slot:
			_worn[slot] = saved[slot]
