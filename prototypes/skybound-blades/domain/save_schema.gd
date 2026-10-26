extends RefCounted
## Validate JSON before typed constructors touch it. Content IDs are checked against current tuning.
const Tuning = preload("res://domain/tuning.gd")
const RUN_KEYS := ["id", "generation", "level", "experience", "gold", "kills", "stacks", "issued", "gear", "equipped",
	"quests", "receipts", "next_seq"]


static func number(value: Variant, minimum: float = 0.0, whole: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum \
		and (not whole or float(value) == floorf(float(value)))


static func strings(value: Variant) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value:
		if not entry is String:
			return false
	return true


static func counts(value: Variant, allowed: Dictionary = {}) -> bool:
	if not value is Dictionary:
		return false
	for key: Variant in value:
		if not key is String or not number(value[key], 0.0, true) or (not allowed.is_empty() and not allowed.has(key)):
			return false
	return true


static func gear(value: Variant, tuning: RefCounted) -> bool:
	if not value is Dictionary:
		return false
	for key: Variant in value:
		var item: Variant = value[key]
		if not key is String or not item is Dictionary or not item.has_all(["id", "template", "quality", "bonus", "issued"]):
			return false
		if item.id != key or not item.template is String or not tuning.equipment.has(item.template) \
				or item.quality not in ["plain", "fine", "rare", "named"] or not item.issued is bool or not item.bonus is Dictionary:
			return false
		for stat: Variant in item.bonus:
			if not stat is String or not number(item.bonus[stat], -1000000.0):
				return false
	return true


static func profile(value: Variant, tuning: RefCounted) -> bool:
	if not value is Dictionary:
		return false
	if not number(value.get("generation", 1), 1.0, true) or not number(value.get("warehouse_gold", 0), 0.0, true):
		return false
	if not counts(value.get("warehouse_items", {}), tuning.items) or not gear(value.get("warehouse_gear", {}), tuning):
		return false
	if not value.get("memorial", []) is Array or not value.get("seen_monsters", {}) is Dictionary:
		return false
	for record: Variant in value.get("memorial", []):
		if not record is Dictionary:
			return false
	return true


static func valid(doc: Dictionary) -> bool:
	if not number(doc.get("schema"), 1.0, true) or doc.schema != 1 or not doc.has("run"):
		return false
	var tuning := Tuning.load_default()
	if not profile(doc.get("profile"), tuning):
		return false
	var run: Variant = doc.run
	if run == null:
		return true
	if not run is Dictionary or not run.has_all(RUN_KEYS) or not run.id is String or run.id.is_empty():
		return false
	for key: String in ["generation", "level", "next_seq"]:
		if not number(run[key], 1.0, true):
			return false
	for key: String in ["gold", "kills"]:
		if not number(run[key], 0.0, true):
			return false
	if not number(run.experience) or not number(run.get("clock_ms", 0)):
		return false
	if not counts(run.stacks, tuning.items) or not counts(run.issued, tuning.items) or not gear(run.gear, tuning):
		return false
	if not strings(run.receipts) or not run.equipped is Dictionary or not run.quests is Dictionary:
		return false
	for role: Variant in run.equipped:
		if role not in ["leader", "guardian", "support"] or not run.equipped[role] is Dictionary:
			return false
		for slot: Variant in run.equipped[role]:
			var id: Variant = run.equipped[role][slot]
			if not id is String or (id != "" and (not run.gear.has(id) or tuning.equipment[run.gear[id].template].slot != slot)):
				return false
	for definition: Dictionary in tuning.data.quest_definitions:
		if int(definition.floor) == 1 and not run.quests.has(definition.id):
			return false
	for id: Variant in run.quests:
		var quest: Variant = run.quests[id]
		if not tuning.quests.has(id) or not quest is Dictionary or not quest.has_all(["progress", "claims", "available_at_ms"]):
			return false
		if not number(quest.progress, 0.0, true) or not number(quest.claims, 0.0, true) or not number(quest.available_at_ms):
			return false
	if run.has("trip"):
		var trip: Variant = run.trip
		if not trip is Dictionary or not trip.has_all(["kills", "exp", "gold", "items", "gear", "used"]):
			return false
		if not number(trip.kills) or not number(trip.exp) or not number(trip.gold) or not counts(trip.items) \
				or not counts(trip.used) or not strings(trip.gear):
			return false
	if run.has("learned"):
		if not run.has_all(["slots", "chains", "seals"]) or not run.learned is Dictionary \
				or not run.slots is Dictionary or not run.chains is Dictionary or not number(run.seals, 0.0, true) \
				or not strings(run.get("seal_receipts", [])):
			return false
		for role: Variant in run.learned:
			if role not in ["leader", "guardian", "support"] or not run.learned[role] is Dictionary:
				return false
			for id: Variant in run.learned[role]:
				var entry: Variant = run.learned[role][id]
				if not tuning.skills.has(id) or not entry is Dictionary or not number(entry.get("level"), 1.0, true) \
						or not number(entry.get("exp")):
					return false
		for collection: Dictionary in [run.slots, run.chains]:
			for role: Variant in collection:
				if not run.learned.has(role) or not strings(collection[role]):
					return false
				for id: String in collection[role]:
					if id != "" and not run.learned[role].has(id):
						return false
	return true
