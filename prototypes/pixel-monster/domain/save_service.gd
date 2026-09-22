extends RefCounted
class_name SaveService

## JSON save boundary with a validated schema and crash-tolerant replacement.
##
## Save order:
## 1. Validate and serialize the complete in-memory dictionary.
## 2. Write + flush `path.tmp`.
## 3. If the current primary is valid, atomically replace `path.bak` with it.
## 4. Atomically replace the primary with the flushed temp file.
##
## A corrupt primary never overwrites a valid backup.  `load_state` falls back
## to that backup and leaves it in place for a second recovery attempt.

const CURRENT_SCHEMA_VERSION: int = 1
const REQUIRED_KEYS: Array[String] = [
	"schema_version",
	"saved_at",
	"last_tick",
	"pet",
	"egg",
	"collection",
	"pending_battle",
	"battle_history",
	"step_ledger",
	"step_debug",
	"settings",
]

const PET_REQUIRED_KEYS: Array = [
	"id",
	"name",
	"species",
	"stage",
	"born_at",
	"stage_started_at",
	"fullness",
	"mood",
	"energy",
	"health",
	"cleanliness",
	"weight",
	"training",
	"training_count",
	"wins",
	"losses",
	"draws",
	"battles",
	"care_mistakes",
	"sleep_seconds",
	"behavior",
	"conditions",
	"lights_on",
	"poop",
	"poop_queue",
	"cooldowns",
	"history",
	"evolutions",
]
const PET_REQUIRED_STRING_KEYS: Array = ["id", "name", "species", "stage", "behavior"]
const PET_TIME_KEYS: Array = ["born_at", "stage_started_at"]
const PET_COUNTER_KEYS: Array = [
	"training_count",
	"wins",
	"losses",
	"draws",
	"battles",
	"care_mistakes",
	"sleep_seconds",
]
const PET_BOUNDED_KEYS: Array = ["fullness", "mood", "energy", "health", "cleanliness"]
const PET_TRAINING_KEYS: Array = ["power", "guard", "swift"]
const PET_CONDITION_KEYS: Array = ["injured", "sick", "hibernating"]
const PET_REQUIRED_ARRAY_KEYS: Array = ["poop", "poop_queue", "history", "evolutions"]
const PET_OPTIONAL_DICT_KEYS: Array = ["care_timers", "need_events", "evolution_modifiers"]

const SETTINGS_BOOL_KEYS: Array = ["sound", "music", "vibration", "auto_lights"]
const SETTINGS_INTEGER_KEYS: Array = [
	"sleep_hour",
	"wake_hour",
	"timezone_offset_minutes",
	"debug_time_offset",
]

const EGG_REQUIRED_KEYS: Array = [
	"id",
	"kind",
	"started_at",
	"target_steps",
	"credited_steps",
	"mode",
	"hatched",
	"hatched_at",
]
const EGG_OPTIONAL_DICT_KEYS: Array = ["step_coverage", "step_buckets", "step_ledger"]

const PENDING_REQUIRED_KEYS: Array = [
	"id",
	"seed",
	"npc_id",
	"npc_name",
	"stance",
	"player",
	"enemy",
	"rounds",
	"outcome",
	"settled",
	"started_at",
]
const ROUND_REQUIRED_KEYS: Array = [
	"round",
	"actor",
	"damage",
	"skill",
	"miss",
	"player_hp",
	"enemy_hp",
	"text",
]

static func save(state: Dictionary, path: String = "user://pocket_diary.json") -> Error:
	if not validate_state(state):
		return ERR_INVALID_DATA
	var serialized: String = JSON.stringify(state)
	if serialized.is_empty():
		return ERR_INVALID_DATA

	var primary: Dictionary = _read_save(path)
	var primary_is_valid: bool = bool(primary.get("ok", false))
	if primary_is_valid:
		var backup_error: Error = _write_atomically(path + ".bak", String(primary.get("text", "")))
		if backup_error != OK:
			return backup_error

	var save_error: Error = _write_atomically(path, serialized)
	if save_error != OK:
		return save_error
	return OK

static func load_state(path: String = "user://pocket_diary.json") -> Dictionary:
	var primary: Dictionary = _read_save(path)
	if bool(primary.get("ok", false)):
		return primary.get("state", {})

	var backup: Dictionary = _read_save(path + ".bak")
	if not bool(backup.get("ok", false)):
		return {}

	# Repair the primary using the valid backup, but never rewrite the backup
	# itself.  If the repair cannot be completed, the valid dictionary is still
	# returned and the backup remains available for the next launch.
	_write_atomically(path, String(backup.get("text", "")))
	return backup.get("state", {})

static func validate_state(state: Dictionary) -> bool:
	if state.is_empty():
		return false
	for key in REQUIRED_KEYS:
		if not state.has(key):
			return false
	if not _is_integer_number(state.get("schema_version")):
		return false
	if int(state.get("schema_version")) != CURRENT_SCHEMA_VERSION:
		return false
	if not _is_integer_number(state.get("saved_at")) or not _is_integer_number(state.get("last_tick")):
		return false
	if not (state.get("pet") is Dictionary):
		return false
	if not (state.get("egg") is Dictionary):
		return false
	if not _validate_collection(state.get("collection")):
		return false
	if not (state.get("pending_battle") is Dictionary):
		return false
	if not (state.get("battle_history") is Array):
		return false
	if not (state.get("step_ledger") is Dictionary):
		return false
	if not (state.get("step_debug") is Dictionary):
		return false
	if not (state.get("settings") is Dictionary):
		return false
	if not _validate_pet(state.get("pet")):
		return false
	if not _validate_egg(state.get("egg")):
		return false
	if not _validate_pending_battle(state.get("pending_battle")):
		return false
	if not _validate_settings(state.get("settings")):
		return false
	return true

static func _validate_collection(value: Variant) -> bool:
	if not (value is Array):
		return false
	var collection: Array = value
	for entry_value: Variant in collection:
		if not (entry_value is Dictionary):
			return false
		var entry: Dictionary = entry_value
		if entry.is_empty():
			return false
		# Current EvolutionService stores the archived pet directly. Keep the
		# UI's existing `{pet: archived_pet}` compatibility shape as well.
		var archived_value: Variant = entry.get("pet", entry)
		if not (archived_value is Dictionary):
			return false
		var archived_pet: Dictionary = archived_value
		if archived_pet.is_empty() or not _validate_pet(archived_pet):
			return false
	return true

static func _validate_pet(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var pet: Dictionary = value
	# The empty dictionary is the documented pre-hatch state.
	if pet.is_empty():
		return true
	if not _has_keys(pet, PET_REQUIRED_KEYS):
		return false
	for key in PET_REQUIRED_STRING_KEYS:
		if not _is_nonempty_string(pet.get(key)):
			return false
	if not ["sprout", "bloom", "ember", "moss", "breeze"].has(String(pet.get("species"))):
		return false
	if not ["baby", "growing", "mature"].has(String(pet.get("stage"))):
		return false
	if not ["idle", "sleeping"].has(String(pet.get("behavior"))):
		return false
	for key in PET_TIME_KEYS:
		if not _is_integer_number(pet.get(key)):
			return false
	for key in PET_COUNTER_KEYS:
		if not _is_nonnegative_integer(pet.get(key)):
			return false
	for key in PET_BOUNDED_KEYS:
		if not _is_number_between(pet.get(key), 0.0, 100.0):
			return false
	# Weight is a positive physical quantity, separate from the 0..100 needs.
	if not _is_finite_number(pet.get("weight")) or float(pet.get("weight")) <= 0.0:
		return false

	var training_value: Variant = pet.get("training")
	if not (training_value is Dictionary):
		return false
	var training: Dictionary = training_value
	if not _has_keys(training, PET_TRAINING_KEYS):
		return false
	for key in PET_TRAINING_KEYS:
		if not _is_integer_between(training.get(key), 0, 100):
			return false

	var conditions_value: Variant = pet.get("conditions")
	if not (conditions_value is Dictionary):
		return false
	var conditions: Dictionary = conditions_value
	if not _has_keys(conditions, PET_CONDITION_KEYS):
		return false
	for key in PET_CONDITION_KEYS:
		if typeof(conditions.get(key)) != TYPE_BOOL:
			return false
	if typeof(pet.get("lights_on")) != TYPE_BOOL:
		return false
	for key in PET_REQUIRED_ARRAY_KEYS:
		if not (pet.get(key) is Array):
			return false
	if not (pet.get("cooldowns") is Dictionary):
		return false

	# These are already emitted by the current PetModel, but remain optional so
	# a compatible older save and future additive fields are not rejected.
	for key in PET_OPTIONAL_DICT_KEYS:
		if pet.has(key) and not (pet.get(key) is Dictionary):
			return false
	if pet.has("age_seconds") and not _is_nonnegative_integer(pet.get("age_seconds")):
		return false
	if pet.has("sleep_reason") and typeof(pet.get("sleep_reason")) != TYPE_STRING:
		return false
	return true

static func _validate_egg(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var egg: Dictionary = value
	# The empty dictionary is the documented no-active-egg state.
	if egg.is_empty():
		return true
	if not _has_keys(egg, EGG_REQUIRED_KEYS):
		return false
	if not _is_nonempty_string(egg.get("id")) or not _is_nonempty_string(egg.get("kind")):
		return false
	if not _is_integer_number(egg.get("started_at")):
		return false
	if not _is_integer_between(egg.get("target_steps"), 1, 2147483647):
		return false
	var target_steps: int = int(egg.get("target_steps"))
	if not _is_integer_between(egg.get("credited_steps"), 0, target_steps):
		return false
	var mode: String = String(egg.get("mode"))
	if not ["steps", "time"].has(mode):
		return false
	if typeof(egg.get("hatched")) != TYPE_BOOL:
		return false
	if not _is_nonnegative_integer(egg.get("hatched_at")):
		return false
	if mode == "time":
		if not egg.has("time_started_at") or not egg.has("time_required_seconds"):
			return false
		if not _is_integer_number(egg.get("time_started_at")):
			return false
		if not _is_integer_between(egg.get("time_required_seconds"), 1, 2147483647):
			return false
	for key in EGG_OPTIONAL_DICT_KEYS:
		if egg.has(key) and not (egg.get(key) is Dictionary):
			return false
	if egg.has("step_source") and typeof(egg.get("step_source")) != TYPE_STRING:
		return false
	if egg.has("last_sync") and not _is_integer_number(egg.get("last_sync")):
		return false
	return true

static func _validate_settings(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var settings: Dictionary = value
	if not _has_keys(settings, SETTINGS_BOOL_KEYS) or not _has_keys(settings, SETTINGS_INTEGER_KEYS):
		return false
	for key in SETTINGS_BOOL_KEYS:
		if typeof(settings.get(key)) != TYPE_BOOL:
			return false
	if not _is_integer_between(settings.get("sleep_hour"), 0, 23):
		return false
	if not _is_integer_between(settings.get("wake_hour"), 0, 23):
		return false
	if not _is_integer_number(settings.get("timezone_offset_minutes")):
		return false
	if not _is_integer_number(settings.get("debug_time_offset")):
		return false
	return true

static func _validate_pending_battle(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var pending: Dictionary = value
	# No pending battle is the normal state.
	if pending.is_empty():
		return true
	if not _has_keys(pending, PENDING_REQUIRED_KEYS):
		return false
	for key in ["id", "npc_id", "npc_name"]:
		if not _is_nonempty_string(pending.get(key)):
			return false
	if not _is_integer_number(pending.get("seed")):
		return false
	if not ["balanced", "assault", "defend"].has(String(pending.get("stance"))):
		return false
	var player_value: Variant = pending.get("player")
	var enemy_value: Variant = pending.get("enemy")
	if not (player_value is Dictionary) or (player_value as Dictionary).is_empty():
		return false
	if not (enemy_value is Dictionary) or (enemy_value as Dictionary).is_empty():
		return false
	if not (pending.get("rounds") is Array):
		return false
	if not ["win", "loss", "draw"].has(String(pending.get("outcome"))):
		return false
	if typeof(pending.get("settled")) != TYPE_BOOL:
		return false
	if not _is_integer_number(pending.get("started_at")):
		return false
	if pending.has("version") and not _is_integer_number(pending.get("version")):
		return false
	if pending.has("max_rounds") and not _is_integer_number(pending.get("max_rounds")):
		return false
	if pending.has("finished_at") and not _is_integer_number(pending.get("finished_at")):
		return false
	for round_value: Variant in pending.get("rounds"):
		if not _validate_round(round_value):
			return false
	return true

static func _validate_round(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var round: Dictionary = value
	if not _has_keys(round, ROUND_REQUIRED_KEYS):
		return false
	if not _is_integer_between(round.get("round"), 1, 2147483647):
		return false
	if not ["player", "enemy"].has(String(round.get("actor"))):
		return false
	if not _is_nonnegative_integer(round.get("damage")):
		return false
	if typeof(round.get("skill")) != TYPE_BOOL or typeof(round.get("miss")) != TYPE_BOOL:
		return false
	if not _is_nonnegative_integer(round.get("player_hp")) or not _is_nonnegative_integer(round.get("enemy_hp")):
		return false
	return typeof(round.get("text")) == TYPE_STRING

static func _has_keys(dictionary: Dictionary, keys: Array) -> bool:
	for key: String in keys:
		if not dictionary.has(key):
			return false
	return true

static func _is_nonempty_string(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not String(value).strip_edges().is_empty()

static func _is_nonnegative_integer(value: Variant) -> bool:
	return _is_integer_number(value) and int(value) >= 0

static func _is_integer_between(value: Variant, minimum: int, maximum: int) -> bool:
	return _is_integer_number(value) and int(value) >= minimum and int(value) <= maximum

static func _is_number_between(value: Variant, minimum: float, maximum: float) -> bool:
	if not _is_finite_number(value):
		return false
	var numeric: float = float(value)
	return numeric >= minimum and numeric <= maximum

static func _is_finite_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var numeric: float = float(value)
	return not is_nan(numeric) and not is_inf(numeric)

static func _is_integer_number(value: Variant) -> bool:
	if not _is_finite_number(value):
		return false
	if typeof(value) == TYPE_INT:
		return true
	return float(value) == floorf(float(value))

static func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "reason": "missing"}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "reason": "open"}
	var text: String = file.get_as_text()
	file.close()
	if text.is_empty():
		return {"ok": false, "reason": "empty"}
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(text)
	if parse_error != OK or not (json.data is Dictionary):
		return {"ok": false, "reason": "json"}
	var state: Dictionary = json.data
	if not validate_state(state):
		return {"ok": false, "reason": "schema"}
	return {
		"ok": true,
		"state": state,
		"text": text,
	}

static func _write_atomically(path: String, text: String) -> Error:
	var parent_error: Error = _ensure_parent(path)
	if parent_error != OK:
		return parent_error
	var temporary_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		_remove_file(temporary_path)
		return write_error

	var rename_error: Error = _replace_file(temporary_path, path)
	if rename_error != OK:
		_remove_file(temporary_path)
	return rename_error

static func _ensure_parent(path: String) -> Error:
	var global_path: String = ProjectSettings.globalize_path(path)
	var parent: String = global_path.get_base_dir()
	if parent.is_empty() or DirAccess.dir_exists_absolute(parent):
		return OK
	return DirAccess.make_dir_recursive_absolute(parent)

static func _replace_file(temporary_path: String, target_path: String) -> Error:
	var temporary_global: String = ProjectSettings.globalize_path(temporary_path)
	var target_global: String = ProjectSettings.globalize_path(target_path)
	var rename_error: Error = DirAccess.rename_absolute(temporary_global, target_global)
	if rename_error == OK:
		return OK
	# POSIX rename replaces an existing file.  Keep a portable fallback for
	# platforms where the engine rejects replace-by-rename; the caller has a
	# .bak checkpoint before changing a primary.
	if FileAccess.file_exists(target_path):
		var remove_error: Error = DirAccess.remove_absolute(target_global)
		if remove_error != OK:
			return remove_error
		return DirAccess.rename_absolute(temporary_global, target_global)
	return rename_error

static func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
