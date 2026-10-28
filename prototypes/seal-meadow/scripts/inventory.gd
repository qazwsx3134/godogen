extends RefCounted
## The bag: `capacity` slots, each holding one item id up to its stack limit. Every change is all-or-nothing:
## add() either fits everything or changes nothing (a full bag never eats part of a pickup).
## Items: {id: {name, stack}} in res://scripts/items.gd.

const Items = preload("res://scripts/items.gd")
const DEFAULT_CAPACITY := 12

var capacity: int = DEFAULT_CAPACITY
## Stackable items use {id, count}; equipment additionally has a stable uid and its own refine level.
var slots: Array[Dictionary] = []


static func new_equipment_uid() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


static func equipment_record(id: String, level: int = 0, uid: String = "") -> Dictionary:
	return {"id": id, "count": 1, "uid": uid if not uid.is_empty() else new_equipment_uid(),
		"refine": clampi(level, 0, 6)}


func _init(slot_count: int = DEFAULT_CAPACITY) -> void:
	capacity = slot_count


func count(id: String) -> int:
	var n := 0
	for s in slots:
		if s.id == id:
			n += s.count
	return n


## Adds `amount` of `id`. Returns false and leaves the bag untouched when it does not all fit.
func add(id: String, amount: int) -> bool:
	if amount <= 0 or not Items.ALL.has(id):
		return false
	var trial: Array[Dictionary] = slots.duplicate(true)
	var left := amount
	var stack: int = Items.ALL[id].stack
	for s in trial:
		if s.id == id and s.count < stack:
			var put := mini(left, stack - s.count)
			s.count += put
			left -= put
	while left > 0 and trial.size() < capacity:
		var put := mini(left, stack)
		trial.append(equipment_record(id) if Items.ALL[id].has("slot") else {"id": id, "count": put})
		left -= put
	if left > 0:
		return false
	slots = trial
	return true


## Move a specific equipment instance without throwing away its identity or refinement.
func take_equipment(id: String, uid: String = "") -> Dictionary:
	for i in slots.size():
		var item: Dictionary = slots[i]
		if item.id == id and Items.ALL[id].has("slot") and (uid.is_empty() or item.get("uid", "") == uid):
			slots.remove_at(i)
			return item.duplicate(true)
	return {}


func put_equipment(item: Dictionary) -> bool:
	var id: String = item.get("id", "")
	var uid: String = item.get("uid", "")
	if not Items.ALL.has(id) or not Items.ALL[id].has("slot") or uid.is_empty() or slots.size() >= capacity:
		return false
	for existing: Dictionary in slots:
		if existing.get("uid", "") == uid:
			return false
	slots.append(equipment_record(id, int(item.get("refine", 0)), uid))
	return true


## Removes `amount` of `id`. Returns false and changes nothing when there is not enough.
func remove(id: String, amount: int) -> bool:
	if amount <= 0 or count(id) < amount:
		return false
	var left := amount
	for i in range(slots.size() - 1, -1, -1):
		if slots[i].id != id:
			continue
		var take := mini(left, slots[i].count)
		slots[i].count -= take
		left -= take
		if slots[i].count == 0:
			slots.remove_at(i)
		if left == 0:
			break
	return true


## A copy to try a multi-step change on; assign its slots back to commit.
func duplicate_bag() -> RefCounted:
	var copy: RefCounted = (get_script() as GDScript).new(capacity)
	copy.slots = slots.duplicate(true)
	return copy


func to_data() -> Array:
	return slots.duplicate(true)


## Unknown ids (removed content) are dropped; counts are clamped to the stack limit.
func load_data(data: Array) -> void:
	slots.clear()
	var seen_uids := {}
	for s in data:
		if s is Dictionary and Items.ALL.has(s.get("id", "")) and slots.size() < capacity:
			var n := clampi(int(s.get("count", 0)), 0, Items.ALL[s.id].stack)
			if n > 0:
				if Items.ALL[s.id].has("slot"):
					var uid: String = s.get("uid", "")
					if uid.is_empty() or seen_uids.has(uid):
						uid = new_equipment_uid()
					seen_uids[uid] = true
					slots.append(equipment_record(String(s.id), int(s.get("refine", 0)), uid))
				else:
					slots.append({"id": String(s.id), "count": n})
