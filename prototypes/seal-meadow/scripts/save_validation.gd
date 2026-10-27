extends RefCounted
## Validate the types used by the runtime before loading; optional fields keep older saves migratable.

const Items = preload("res://scripts/items.gd")


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func valid(data: Dictionary) -> bool:
	if data.get("_invalid_schema", false):
		return false
	for key: String in ["level", "xp", "x", "z", "gold", "tutorial"]:
		if data.has(key) and not _number(data[key]):
			return false
	for key: String in ["quests", "pet", "equipped", "refine_receipt", "settings", "collection"]:
		if data.has(key) and not data[key] is Dictionary:
			return false
	if data.has("bag"):
		if not data.bag is Array:
			return false
		var seen := {}
		for item: Variant in data.bag:
			if not item is Dictionary or not item.get("id", "") is String or not _number(item.get("count", 0)):
				return false
			var count: float = float(item.get("count", 0))
			var item_id: String = item.get("id", "")
			if count < 1.0 or floorf(count) != count:
				return false
			if not Items.ALL.has(item_id) or count > int(Items.ALL[item_id].stack):
				return false
			if item.has("refine") and not _number(item.refine):
				return false
			if item.has("uid") and not item.uid is String:
				return false
			if Items.ALL[item_id].has("slot"):
				var uid: String = item.get("uid", "")
				if uid.is_empty() or seen.has(uid):
					return false
				seen[uid] = true
	var seen_gear := {}
	for item: Dictionary in data.get("bag", []):
		if item.has("uid"):
			seen_gear[item.uid] = true
	for slot: String in ["weapon", "body"]:
		var item: Variant = data.get("equipped", {}).get(slot, {})
		if not item is Dictionary:
			return false
		if item.has("id") and not item.id is String:
			return false
		if item.has("uid") and not item.uid is String:
			return false
		if item.has("refine") and not _number(item.refine):
			return false
		if not item.is_empty():
			var id: String = item.get("id", "")
			var uid: String = item.get("uid", "")
			if not Items.ALL.has(id) or Items.ALL[id].get("slot", "") != slot or uid.is_empty() or seen_gear.has(uid):
				return false
			seen_gear[uid] = true
	var quests: Dictionary = data.get("quests", {})
	for key: String in ["index", "progress"]:
		if quests.has(key) and not _number(quests[key]):
			return false
	if quests.has("accepted") and not quests.accepted is bool:
		return false
	var pet: Dictionary = data.get("pet", {})
	for key: String in ["stage", "level", "xp", "hunger"]:
		if pet.has(key) and not _number(pet[key]):
			return false
	for key: String in ["egg", "type", "wants"]:
		if pet.has(key) and not pet[key] is String:
			return false
	for key: String in ["rare", "alive"]:
		if pet.has(key) and not pet[key] is bool:
			return false
	var receipt: Dictionary = data.get("refine_receipt", {})
	if receipt.has("seq") and not _number(receipt.seq):
		return false
	if receipt.has("result") and not receipt.result is Dictionary:
		return false
	if int(receipt.get("seq", 0)) > 0:
		var result: Dictionary = receipt.get("result", {})
		if not result.get("ok") is bool or not _number(result.get("level")) \
				or not result.get("stone") is String or not result.get("uid") is String:
			return false
	var settings: Dictionary = data.get("settings", {})
	for key: String in ["sound", "large_text", "reduced_motion"]:
		if settings.has(key) and not settings[key] is bool:
			return false
	var collection: Dictionary = data.get("collection", {})
	if collection.has("kills") and not collection.kills is Dictionary:
		return false
	if collection.has("claimed") and not collection.claimed is Array:
		return false
	for value: Variant in collection.get("kills", {}).values():
		if not _number(value):
			return false
	for id: Variant in collection.get("claimed", []):
		if not id is String:
			return false
	return true
