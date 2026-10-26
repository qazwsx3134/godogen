extends RefCounted
## Validated profile snapshots, atomic commit, and last-known-good backup.

const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
const Catalog = preload("res://domain/catalog.gd")
const VERSION: int = 1
var path: String
var read_only: bool = false
var catalog: RefCounted


func _init(file: String = "user://profile.json", definitions: RefCounted = null) -> void:
	path = file
	catalog = definitions if definitions != null else Catalog.new()


func restore() -> Dictionary:
	read_only = false
	var found: bool = false
	for source: String in ["main", "backup"]:
		var target: String = path if source == "main" else path + ".bak"
		if not FileAccess.file_exists(target): continue
		found = true
		var document: Dictionary = _read(target)
		if int(document.get("version", 0)) > VERSION:
			read_only = true
			return {"state": {}, "source": "newer", "message": "存檔來自較新版本。本次僅試玩，不會覆寫原檔。"}
		if int(document.get("version", 0)) == VERSION and document.get("state") is Dictionary and valid(document.state):
			return {"state": _normalize(document.state), "source": source,
				"message": "已恢復上一份合法備份。" if source == "backup" else "旅程進度已載入。"}
	if found:
		read_only = true
		return {"state": {}, "source": "corrupt", "message": "存檔與備份無法讀取。本次僅試玩，原檔保留。"}
	return {"state": {}, "source": "new", "message": "新的旅程開始了。"}


func save(profile: Dictionary) -> Error:
	if read_only: return ERR_UNAUTHORIZED
	if not valid(profile): return ERR_INVALID_DATA
	var current: Dictionary = _read(path)
	if int(current.get("version", 0)) > VERSION:
		read_only = true
		return ERR_UNAUTHORIZED
	if int(current.get("version", 0)) == VERSION and current.get("state") is Dictionary and valid(current.state):
		var backup_error: Error = AtomicFile.write_bytes(path + ".bak", AtomicFile.read_bytes(path))
		if backup_error != OK: return backup_error
	return AtomicFile.write_text(path, JSON.stringify({"version": VERSION, "state": profile}))


func valid(s: Dictionary) -> bool:
	for key: String in ["roster", "equipped", "talents"]:
		if not s.get(key) is Dictionary: return false
	for key: String in ["deployed", "items", "pending", "cleared", "journal"]:
		if not s.get(key) is Array: return false
	for key: String in ["gold", "next_item", "stage", "kills", "defeats", "earned", "encounter", "blocked_drops"]:
		if not _whole(s.get(key), 0, 1000000000000.0): return false
	if not _whole(s.get("best_stage"), -1, catalog.stages.size() - 1): return false
	if not _number(s.get("played"), 0, 1e12): return false
	for key: String in ["auto_advance", "muted", "tutorial_seen"]:
		if not s.get(key) is bool: return false
	if int(s.stage) >= catalog.stages.size() or int(s.stage) > int(s.best_stage) + 1: return false
	if s.roster.is_empty() or s.roster.size() > catalog.units.size(): return false
	for id: String in s.roster:
		if not catalog.units.has(id) or not s.roster[id] is Dictionary: return false
		var progress: Dictionary = s.roster[id]
		if not _whole(progress.get("level"), 1, catalog.level_cap): return false
		if not _whole(progress.get("xp"), 0, 24 + 12 * int(progress.level) - 1): return false
	if not s.talents.get("levels") is Dictionary: return false
	var ranks: Dictionary = s.talents.levels
	for id: String in ranks:
		var definition: Dictionary = catalog.talent(id)
		if definition.is_empty() or not _whole(ranks[id], 0, int(definition.max_level)): return false
	for id: String in ["company", "tempo"]:
		if int(ranks.get(id, 0)) > 0 and int(ranks.get("might", 0)) < 1: return false
	for id: String in ["fortune", "echo"]:
		if int(ranks.get(id, 0)) > 0 and int(ranks.get("vitality", 0)) < 1: return false
	if s.deployed.is_empty() or s.deployed.size() > 2 + int(ranks.get("company", 0)): return false
	var seen: Dictionary = {}
	for id: Variant in s.deployed:
		if not id is String or not s.roster.has(id) or seen.has(id): return false
		seen[id] = true
	var item_ids: Dictionary = {}
	var highest_uid: int = 0
	for collection: Array in [s.items, s.pending]:
		for entry: Variant in collection:
			if not entry is Dictionary: return false
			if not entry.get("uid") is String or not str(entry.uid).begins_with("gear_"): return false
			if item_ids.has(entry.uid) or not catalog.gear.has(str(entry.get("id", ""))): return false
			if str(entry.get("slot", "")) != str(catalog.gear[entry.id].slot): return false
			if not entry.get("name") is String or not entry.get("locked") is bool: return false
			for key: String in ["attack", "hp", "defense", "price", "quality"]:
				if not _whole(entry.get(key), 0, 1000000): return false
			item_ids[entry.uid] = entry
			highest_uid = maxi(highest_uid, int(str(entry.uid).trim_prefix("gear_")))
	if int(s.next_item) <= highest_uid: return false
	if s.pending.size() > catalog.pending_capacity: return false
	var held: Dictionary = {}
	for id: String in s.equipped:
		if not s.roster.has(id) or not s.equipped[id] is Dictionary: return false
		for slot: String in ["weapon", "armor"]:
			if not s.equipped[id].get(slot) is String: return false
			var uid: String = s.equipped[id][slot]
			if uid.is_empty(): continue
			if held.has(uid) or not item_ids.has(uid) or str(item_ids[uid].slot) != slot: return false
			if item_ids[uid] in s.pending: return false
			held[uid] = true
	for id: String in s.roster:
		if not s.equipped.has(id): return false
	if s.items.size() - held.size() > catalog.bag_capacity: return false
	if s.cleared.size() != int(s.best_stage) + 1: return false
	var completed: Dictionary = {}
	for value: Variant in s.cleared:
		if not _whole(value, 0, catalog.stages.size() - 1): return false
		completed[int(value)] = true
	if completed.size() != s.cleared.size(): return false
	for i: int in range(int(s.best_stage) + 1):
		if not completed.has(i): return false
	if s.journal.size() > 80: return false
	for entry: Variant in s.journal:
		if not entry is Dictionary or not entry.get("message") is String or not entry.get("kind") is String: return false
		if not _whole(entry.get("seconds"), 0, 1e12): return false
	for key: String in ["combat_rng", "loot_rng"]:
		if not s.get(key) is String or not str(s[key]).is_valid_int(): return false
	return true


static func _normalize(profile: Dictionary) -> Dictionary:
	var result: Dictionary = profile.duplicate(true)
	for key: String in ["gold", "next_item", "stage", "best_stage", "kills", "defeats", "earned", "encounter", "blocked_drops"]:
		result[key] = int(result[key])
	for i: int in result.cleared.size(): result.cleared[i] = int(result.cleared[i])
	for id: String in result.roster:
		result.roster[id].level = int(result.roster[id].level)
		result.roster[id].xp = int(result.roster[id].xp)
	for id: String in result.talents.levels: result.talents.levels[id] = int(result.talents.levels[id])
	for collection: Array in [result.items, result.pending]:
		for entry: Dictionary in collection:
			for key: String in ["attack", "hp", "defense", "price", "quality"]: entry[key] = int(entry[key])
	for entry: Dictionary in result.journal: entry.seconds = int(entry.seconds)
	return result


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


static func _whole(value: Variant, minimum: float, maximum: float) -> bool:
	return _number(value, minimum, maximum) and float(value) == floor(float(value))


static func _read(file: String) -> Dictionary:
	var bytes: PackedByteArray = AtomicFile.read_bytes(file)
	if bytes.is_empty(): return {}
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary: return {}
	return parser.data
