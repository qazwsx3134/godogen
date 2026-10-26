extends RefCounted
## Definition tables are immutable. Runtime state lives in GameModel.

var units: Dictionary = {}
var stages: Array[Dictionary] = []
var talents: Array[Dictionary] = []
var gear: Dictionary = {}
var bag_capacity: int = 36
var pending_capacity: int = 64
var level_cap: int = 20
var errors: Array[String] = []


func _init(document: Dictionary = {}) -> void:
	if document.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
		if not parsed is Dictionary:
			errors.append("catalog.json 必須是物件")
			return
		document = parsed
	bag_capacity = int(document.get("bag_capacity", 36))
	pending_capacity = int(document.get("pending_capacity", 64))
	level_cap = int(document.get("level_cap", 20))
	for kind: String in ["units", "stages", "talents", "gear"]:
		var seen: Dictionary = {}
		for definition: Dictionary in document.get(kind, []):
			var id: String = str(definition.get("id", ""))
			if id.is_empty() or seen.has(id):
				errors.append("%s ID重複或空白：%s" % [kind, id])
				continue
			seen[id] = true
			match kind:
				"units": units[id] = definition.duplicate(true)
				"stages": stages.append(definition.duplicate(true))
				"talents": talents.append(definition.duplicate(true))
				"gear": gear[id] = definition.duplicate(true)
	if units.is_empty() or stages.is_empty() or talents.is_empty() or gear.is_empty():
		errors.append("內容表不可為空")
	if bag_capacity < 1 or pending_capacity < 1 or level_cap < 1:
		errors.append("容量與等級上限必須大於0")
	for id: String in units:
		for key: String in ["hp", "attack", "interval", "speed", "range"]:
			if float(units[id].get(key, 0)) <= 0:
				errors.append("%s 的 %s 必須大於0" % [id, key])


func talent(id: String) -> Dictionary:
	for entry: Dictionary in talents:
		if entry.id == id:
			return entry
	return {}
