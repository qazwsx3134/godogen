extends RefCounted
## What outlives a generation: the warehouse (gold, items, gear), the memorial and counters.
## Only the camp moves things in or out (see field camp actions); a fallen leader never touches it.

var warehouse_gold: int = 0
var warehouse_items: Dictionary = {}  # item id -> qty
var warehouse_gear: Dictionary = {}  # instance id -> instance (same shape as Run.gear)
var memorial: Array = []  # [{generation, level, kills, cause, floor}]
var generation: int = 1
var seen_monsters: Dictionary = {}


func deposit_gold(run: RefCounted, amount: int) -> bool:
	if amount <= 0 or run.gold < amount:
		return false
	run.gold -= amount
	warehouse_gold += amount
	return true


func withdraw_gold(run: RefCounted, amount: int) -> bool:
	if amount <= 0 or warehouse_gold < amount:
		return false
	warehouse_gold -= amount
	run.gold += amount
	return true


## Free (non-issued) stock only.
func deposit_item(run: RefCounted, item_id: String, qty: int) -> bool:
	if not run.take_free(item_id, qty):
		return false
	warehouse_items[item_id] = int(warehouse_items.get(item_id, 0)) + qty
	return true


func withdraw_item(run: RefCounted, item_id: String, qty: int) -> bool:
	if qty <= 0 or int(warehouse_items.get(item_id, 0)) < qty:
		return false
	warehouse_items[item_id] = int(warehouse_items[item_id]) - qty
	if warehouse_items[item_id] == 0:
		warehouse_items.erase(item_id)
	run.add_item(item_id, qty)
	return true


## Bag gear only (not worn, not issued).
func deposit_gear(run: RefCounted, instance_id: String) -> bool:
	if not run.gear.has(instance_id) or run.holder_of(instance_id) != "" or bool(run.gear[instance_id].issued):
		return false
	warehouse_gear[instance_id] = run.gear[instance_id]
	run.gear.erase(instance_id)
	return true


func withdraw_gear(run: RefCounted, instance_id: String) -> bool:
	if not warehouse_gear.has(instance_id):
		return false
	run.gear[instance_id] = warehouse_gear[instance_id]
	warehouse_gear.erase(instance_id)
	return true


func record_death(run: RefCounted, cause: String) -> void:
	memorial.append({"generation": run.generation, "level": run.level, "kills": run.kills, "cause": cause, "floor": 1})
	generation = run.generation + 1


func to_dict() -> Dictionary:
	return {"warehouse_gold": warehouse_gold, "warehouse_items": warehouse_items, "warehouse_gear": warehouse_gear,
		"memorial": memorial, "generation": generation, "seen_monsters": seen_monsters}


static func from_dict(d: Dictionary) -> RefCounted:
	var p: RefCounted = load("res://domain/profile.gd").new()
	p.warehouse_gold = int(d.get("warehouse_gold", 0))
	p.warehouse_items = _int_values(d.get("warehouse_items", {}))
	p.warehouse_gear = d.get("warehouse_gear", {})
	p.memorial = d.get("memorial", [])
	p.generation = int(d.get("generation", 1))
	p.seen_monsters = d.get("seen_monsters", {})
	return p


## JSON numbers come back as floats; counts are whole.
static func _int_values(d: Dictionary) -> Dictionary:
	var out := {}
	for k: String in d:
		out[k] = int(d[k])
	return out
