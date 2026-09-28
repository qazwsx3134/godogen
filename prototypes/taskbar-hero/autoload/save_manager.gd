extends Node

signal save_completed(success: bool, message: String)

const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
const Catalog = preload("res://domain/progression_catalog.gd")
const SAVE_PATH: String = "user://save.json"
const SAVE_VERSION: int = 2
const MAX_COUNTER: int = 999999999
const MAX_TIMESTAMP: int = 4102444800

@export_file var save_path: String = SAVE_PATH
var autosave_elapsed: float = 0.0
var last_load_source: String = "new"
var last_load_message: String = ""
var writes_blocked: bool = false

@onready var _game: Node = get_node("/root/Game")


func _ready() -> void:
	var loaded: Dictionary = load_profile(save_path)
	if not loaded.is_empty():
		_game.call("restore_session", loaded)


func _process(delta: float) -> void:
	autosave_elapsed += delta
	if autosave_elapsed >= 60.0:
		autosave_elapsed = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


func save_game() -> Error:
	var result: Error = save_profile(_game.call("save_snapshot"), save_path)
	autosave_elapsed = 0.0
	var message: String = "記錄已安全寫入。" if result == OK else error_string(result)
	if result != OK and not last_load_message.is_empty():
		message = last_load_message
	elif result == ERR_UNAVAILABLE:
		message = "存檔狀態不安全，已停止寫入。"
	save_completed.emit(result == OK, message)
	return result


func save_profile(data: Dictionary, target_path: String = "") -> Error:
	var path: String = target_path if not target_path.is_empty() else save_path
	var normalized: Dictionary = _normalize_profile(data)
	if not bool(normalized.get("valid", false)):
		return ERR_INVALID_DATA

	var current: Dictionary = _read_profile(path)
	var backup: Dictionary = _read_profile(path + ".bak")
	if str(current.get("reason", "")) == "future_version" \
			or str(backup.get("reason", "")) == "future_version":
		if path == save_path:
			writes_blocked = true
			if str(current.get("reason", "")) == "future_version":
				last_load_source = "future_version"
				last_load_message = "存檔來自較新版本；自動與手動寫入均已停用，原檔保留。"
			else:
				last_load_source = "primary_backup_future"
				last_load_message = "備份來自較新版本；寫入已停用，原檔保留。"
		return ERR_UNAVAILABLE

	var current_is_valid: bool = bool(current.get("valid", false))
	var backup_is_valid: bool = bool(backup.get("valid", false))
	var current_is_missing: bool = str(current.get("reason", "")) == "missing"
	var backup_is_missing: bool = str(backup.get("reason", "")) == "missing"
	if not current_is_valid and not backup_is_valid and not (current_is_missing and backup_is_missing):
		return ERR_UNAVAILABLE

	if current_is_valid:
		var backup_error: Error = AtomicFile.write_text(path + ".bak", JSON.stringify(current["data"]))
		if backup_error != OK:
			return backup_error

	var write_error: Error = AtomicFile.write_text(path, JSON.stringify(normalized["data"]))
	if write_error == OK and path == save_path:
		writes_blocked = false
		last_load_source = "primary"
		last_load_message = ""
	return write_error


func load_profile(target_path: String = "") -> Dictionary:
	var path: String = target_path if not target_path.is_empty() else save_path
	var primary: Dictionary = _read_profile(path)
	var backup: Dictionary = _read_profile(path + ".bak")
	writes_blocked = false
	last_load_message = ""

	if str(primary.get("reason", "")) == "future_version":
		writes_blocked = true
		last_load_source = "future_version"
		last_load_message = "存檔來自較新版本；自動與手動寫入均已停用，原檔保留。"
		return {}
	if str(backup.get("reason", "")) == "future_version":
		writes_blocked = true
		last_load_message = "備份來自較新版本；寫入已停用，原檔保留。"
		if bool(primary.get("valid", false)):
			last_load_source = "primary_backup_future"
			return primary["data"]
		last_load_source = "future_version"
		return {}
	if bool(primary.get("valid", false)):
		last_load_source = "primary"
		return primary["data"]
	if bool(backup.get("valid", false)):
		last_load_source = "backup"
		last_load_message = "主存檔無效，已從有效備份恢復。"
		return backup["data"]

	var primary_missing: bool = str(primary.get("reason", "")) == "missing"
	var backup_missing: bool = str(backup.get("reason", "")) == "missing"
	if primary_missing and backup_missing:
		last_load_source = "new"
		return {}

	writes_blocked = true
	last_load_source = "corrupt"
	last_load_message = "存檔與備份都無法驗證；檔案已保留。請手動移開損壞檔後重啟。"
	return {}


func _read_profile(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"valid": false, "reason": "missing"}
	var bytes: PackedByteArray = AtomicFile.read_bytes(path)
	if bytes.is_empty():
		return {"valid": false, "reason": "corrupt"}
	var parser := JSON.new()
	var parse_error: Error = parser.parse(bytes.get_string_from_utf8())
	if parse_error != OK:
		return {"valid": false, "reason": "corrupt"}
	return _normalize_profile(parser.data)


func _normalize_profile(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {"valid": false, "reason": "corrupt"}
	var source: Dictionary = value
	if not source.has("version"):
		return {"valid": false, "reason": "corrupt"}
	var version_result: Dictionary = _whole_number(source.get("version"), 0, 999)
	if not bool(version_result.get("valid", false)):
		return {"valid": false, "reason": "corrupt"}
	var version: int = int(version_result["value"])
	if version > SAVE_VERSION:
		return {"valid": false, "reason": "future_version", "version": version}
	if version < 1:
		return {"valid": false, "reason": "unsupported_version", "version": version}

	var expected_keys: Array[String] = ["version", "last_active_timestamp", "gold", "kills", "current_stage"]
	if version == SAVE_VERSION:
		expected_keys.append("progression")
	if not _has_exact_keys(source, expected_keys):
		return {"valid": false, "reason": "corrupt"}

	var timestamp_result: Dictionary = _whole_number(source.get("last_active_timestamp"), 0, MAX_TIMESTAMP)
	var gold_result: Dictionary = _whole_number(source.get("gold"), 0, MAX_COUNTER)
	var kills_result: Dictionary = _whole_number(source.get("kills"), 0, MAX_COUNTER)
	if not bool(timestamp_result.get("valid", false)) \
			or not bool(gold_result.get("valid", false)) \
			or not bool(kills_result.get("valid", false)):
		return {"valid": false, "reason": "corrupt"}
	if typeof(source.get("current_stage")) != TYPE_STRING:
		return {"valid": false, "reason": "corrupt"}
	var stage: String = str(source["current_stage"])
	if not _is_valid_stage(stage):
		return {"valid": false, "reason": "corrupt"}

	var progression: Dictionary = Catalog.default_progression()
	if version == SAVE_VERSION:
		var progression_result: Dictionary = _normalize_progression(source["progression"])
		if not bool(progression_result.get("valid", false)):
			return {"valid": false, "reason": "corrupt"}
		progression = progression_result["data"]

	return {
		"valid": true,
		"reason": "",
		"data": {
			"version": SAVE_VERSION,
			"last_active_timestamp": int(timestamp_result["value"]),
			"gold": int(gold_result["value"]),
			"kills": int(kills_result["value"]),
			"current_stage": stage,
			"progression": progression,
		},
	}


func _normalize_progression(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {"valid": false}
	var source: Dictionary = value
	if not _has_exact_keys(source, ["training", "monsters", "deployed", "loadouts", "equipment_levels"]):
		return {"valid": false}

	var training_value: Variant = source["training"]
	if typeof(training_value) != TYPE_ARRAY or (training_value as Array).size() != 4:
		return {"valid": false}
	var training: Array[int] = []
	for raw_level: Variant in training_value:
		var level_result: Dictionary = _whole_number(raw_level, 1, Catalog.TRAINING_CAP)
		if not bool(level_result.get("valid", false)):
			return {"valid": false}
		training.append(int(level_result["value"]))

	var monsters_value: Variant = source["monsters"]
	if typeof(monsters_value) != TYPE_DICTIONARY:
		return {"valid": false}
	var monsters_source: Dictionary = monsters_value
	if not _has_exact_keys(monsters_source, Catalog.MONSTER_IDS):
		return {"valid": false}
	var monsters: Dictionary = {}
	for monster_id: String in Catalog.MONSTER_IDS:
		var monster_value: Variant = monsters_source[monster_id]
		if typeof(monster_value) != TYPE_DICTIONARY:
			return {"valid": false}
		var monster: Dictionary = monster_value
		if not _has_exact_keys(monster, ["level", "xp"]):
			return {"valid": false}
		var monster_level_result: Dictionary = _whole_number(monster["level"], 1, Catalog.MONSTER_LEVEL_CAP)
		var xp_result: Dictionary = _whole_number(monster["xp"], 0, Catalog.MAX_XP)
		if not bool(monster_level_result.get("valid", false)) or not bool(xp_result.get("valid", false)):
			return {"valid": false}
		var monster_level: int = int(monster_level_result["value"])
		var monster_xp: int = int(xp_result["value"])
		if monster_level == Catalog.MONSTER_LEVEL_CAP and monster_xp != 0:
			return {"valid": false}
		if monster_level < Catalog.MONSTER_LEVEL_CAP and monster_xp >= Catalog.xp_to_next(monster_level):
			return {"valid": false}
		monsters[monster_id] = {"level": monster_level, "xp": monster_xp}

	var deployed_value: Variant = source["deployed"]
	if typeof(deployed_value) != TYPE_ARRAY:
		return {"valid": false}
	var deployed: Array[String] = []
	for raw_id: Variant in deployed_value:
		if typeof(raw_id) != TYPE_STRING or not Catalog.MONSTER_IDS.has(raw_id):
			return {"valid": false}
		var monster_id: String = str(raw_id)
		if deployed.has(monster_id):
			return {"valid": false}
		deployed.append(monster_id)

	var loadouts_value: Variant = source["loadouts"]
	if typeof(loadouts_value) != TYPE_DICTIONARY:
		return {"valid": false}
	var loadouts_source: Dictionary = loadouts_value
	if not _has_exact_keys(loadouts_source, Catalog.OWNERS):
		return {"valid": false}
	var loadouts: Dictionary = {}
	var equipped_items: Dictionary = {}
	for owner: String in Catalog.OWNERS:
		var layout_value: Variant = loadouts_source[owner]
		if typeof(layout_value) != TYPE_DICTIONARY:
			return {"valid": false}
		var layout_source: Dictionary = layout_value
		var slots: Array[String] = Catalog.owner_slots(owner)
		if not _has_exact_keys(layout_source, slots):
			return {"valid": false}
		var layout: Dictionary = {}
		for slot: String in slots:
			var item_value: Variant = layout_source[slot]
			if typeof(item_value) != TYPE_STRING:
				return {"valid": false}
			var item_id: String = str(item_value)
			if not item_id.is_empty():
				if equipped_items.has(item_id) or not Catalog.item_accepts_owner_slot(item_id, owner, slot):
					return {"valid": false}
				equipped_items[item_id] = owner
			layout[slot] = item_id
		loadouts[owner] = layout

	var equipment_value: Variant = source["equipment_levels"]
	if typeof(equipment_value) != TYPE_DICTIONARY:
		return {"valid": false}
	var equipment_source: Dictionary = equipment_value
	var expected_item_ids: Array[String] = []
	for item: Dictionary in Catalog.ITEMS:
		expected_item_ids.append(str(item["id"]))
	if not _has_exact_keys(equipment_source, expected_item_ids):
		return {"valid": false}
	var equipment_levels: Dictionary = {}
	for item_id: String in expected_item_ids:
		var level_result: Dictionary = _whole_number(equipment_source[item_id], 1, Catalog.EQUIPMENT_LEVEL_CAP)
		if not bool(level_result.get("valid", false)):
			return {"valid": false}
		equipment_levels[item_id] = int(level_result["value"])

	return {
		"valid": true,
		"data": {
			"training": training,
			"monsters": monsters,
			"deployed": deployed,
			"loadouts": loadouts,
			"equipment_levels": equipment_levels,
		},
	}


func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: Variant in expected:
		if not value.has(key):
			return false
	return true


func _whole_number(value: Variant, minimum: int, maximum: int) -> Dictionary:
	var number: float
	if typeof(value) == TYPE_INT:
		number = float(value)
	elif typeof(value) == TYPE_FLOAT:
		number = float(value)
		if not is_finite(number) or floorf(number) != number:
			return {"valid": false}
	else:
		return {"valid": false}
	if number < float(minimum) or number > float(maximum):
		return {"valid": false}
	return {"valid": true, "value": int(number)}


func _is_valid_stage(stage: String) -> bool:
	if stage.length() > 24:
		return false
	var parts: PackedStringArray = stage.split("-", false)
	return parts.size() == 2 \
		and parts[0].is_valid_int() \
		and parts[1].is_valid_int() \
		and int(parts[0]) > 0 and int(parts[0]) <= 99 \
		and int(parts[1]) > 0 and int(parts[1]) <= 99
