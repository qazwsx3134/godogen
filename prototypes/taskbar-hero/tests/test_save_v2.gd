extends "res://addons/proto_kit/test_kit.gd"

const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
const TestBootstrap = preload("res://tests/test_bootstrap.gd")
const Catalog = preload("res://domain/progression_catalog.gd")

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	TestBootstrap.add_services(root)
	var game: Node = root.get_node("Game")
	var save_script: Script = load("res://autoload/save_manager.gd") as Script
	var manager: Node = save_script.new() as Node
	manager.name = "SaveManagerV2UnderTest"
	var base: String = "user://taskbar-growth-tests/save_v2"
	var fresh_path: String = base + "_fresh.json"
	var v1_path: String = base + "_v1.json"
	var recovery_path: String = base + "_recovery.json"
	var future_path: String = base + "_future.json"
	var future_backup_path: String = base + "_future_backup.json"
	var malformed_path: String = base + "_malformed.json"
	for path: String in [fresh_path, v1_path, recovery_path, future_path, future_backup_path, malformed_path]:
		_remove_files(path)
	manager.set("save_path", fresh_path)
	root.add_child(manager)
	await _frames(1)

	var fresh_load: Dictionary = manager.call("load_profile", fresh_path)
	_expect(fresh_load.is_empty(), "missing primary and backup start a new profile")
	_expect(manager.get("last_load_source") == "new" and not manager.get("writes_blocked"), "fresh state remains writable")
	_expect(game.get("gold") == 500, "new game gold baseline is available without changing old saves")

	# JSON parsing recreates nested arrays as untyped Variants for malformed fixtures.
	var snapshot: Dictionary = _json_copy(game.call("save_snapshot"))
	_expect(snapshot.get("version") == 2 and snapshot.has("progression"), "game snapshots use save schema v2")
	_expect(snapshot["progression"].keys().size() == 5, "v2 progression contains all five contract sections")
	_expect(manager.call("save_profile", snapshot, fresh_path) == OK, "first v2 profile writes atomically")
	var next_snapshot: Dictionary = snapshot.duplicate(true)
	next_snapshot["gold"] = 450
	next_snapshot["kills"] = 3
	_expect(manager.call("save_profile", next_snapshot, fresh_path) == OK, "second v2 write commits through the existing atomic backup path")
	var saved: Dictionary = manager.call("load_profile", fresh_path)
	_expect(saved.get("version") == 2 and saved.get("gold") == 450, "v2 primary reloads with normalized integer fields")
	var saved_backup: Dictionary = manager.call("load_profile", fresh_path + ".bak")
	_expect(saved_backup.get("gold") == 500, "previous valid v2 primary becomes the backup")

	var v1: Dictionary = _v1_profile(371, 22, "3-2", 1700000000)
	var migrated_result: Dictionary = manager.call("_normalize_profile", v1)
	_expect(bool(migrated_result.get("valid", false)), "valid v1 profiles migrate")
	var migrated: Dictionary = migrated_result.get("data", {})
	_expect(migrated.get("version") == 2, "v1 migration writes the current schema in memory")
	_expect(migrated.get("gold") == 371 and migrated.get("kills") == 22 and migrated.get("current_stage") == "3-2", "v1 migration preserves old gold, kills and stage exactly")
	_expect(migrated.get("progression") == Catalog.default_progression(), "v1 migration fills only the agreed progression defaults")
	_atomic_write(v1_path, JSON.stringify(v1))
	var loaded_v1: Dictionary = manager.call("load_profile", v1_path)
	_expect(loaded_v1.get("version") == 2 and loaded_v1.get("gold") == 371, "file load migrates v1 before restoring gameplay")
	manager.set("save_path", v1_path)
	game.call("restore_session", loaded_v1)
	_expect(game.get("gold") == 371 and game.get("kills") == 22 and game.get("current_stage") == "3-2", "game restoration keeps migrated v1 progress")
	_expect(manager.call("save_game") == OK, "manual save upgrades a restored v1 profile to v2")
	var upgraded_v1: Dictionary = manager.call("load_profile", v1_path)
	_expect(upgraded_v1.get("version") == 2 and upgraded_v1.get("gold") == 371, "v1 values survive the first v2 save")

	var invalid: Dictionary = snapshot.duplicate(true)
	invalid["unexpected"] = true
	_expect(not bool(manager.call("_normalize_profile", invalid).get("valid", false)), "unknown v2 top-level fields are rejected")
	invalid = snapshot.duplicate(true)
	invalid["progression"]["training"] = [1.5, 1, 1, 1]
	_expect(not bool(manager.call("_normalize_profile", invalid).get("valid", false)), "fractional training levels are rejected")
	invalid = snapshot.duplicate(true)
	invalid["progression"]["training"] = [INF, 1, 1, 1]
	_expect(not bool(manager.call("_normalize_profile", invalid).get("valid", false)), "non-finite progression numbers are rejected")
	invalid = snapshot.duplicate(true)
	invalid["progression"]["monsters"].erase("aqua")
	_expect(not bool(manager.call("_normalize_profile", invalid).get("valid", false)), "monster keys must match all four known monster IDs")
	invalid = snapshot.duplicate(true)
	invalid["progression"]["monsters"]["unknown"] = {"level": 1, "xp": 0}
	_expect(not bool(manager.call("_normalize_profile", invalid).get("valid", false)), "unknown monster IDs are rejected")
	invalid = snapshot.duplicate(true)
	invalid["progression"]["deployed"] = ["sprout", "sprout"]
	_expect(not bool(manager.call("_normalize_profile", invalid).get("valid", false)), "duplicate deployed monsters are rejected")
	invalid = snapshot.duplicate(true)
	invalid["progression"]["deployed"] = ["slime"]
	_expect(not bool(manager.call("_normalize_profile", invalid).get("valid", false)), "unknown deployed IDs are rejected")
	invalid = snapshot.duplicate(true)
	invalid["progression"]["loadouts"]["hero"]["weapon"] = "monster_necklace"
	_expect(not bool(manager.call("_normalize_profile", invalid).get("valid", false)), "equipment slot and owner compatibility are validated")
	invalid = snapshot.duplicate(true)
	invalid["progression"]["loadouts"]["sprout"]["accessory"] = "hero_ring"
	_expect(not bool(manager.call("_normalize_profile", invalid).get("valid", false)), "one unique item cannot appear in two loadouts")
	invalid = snapshot.duplicate(true)
	invalid["progression"]["loadouts"]["hero"]["extra"] = ""
	_expect(not bool(manager.call("_normalize_profile", invalid).get("valid", false)), "loadout slot sets are exact")
	invalid = snapshot.duplicate(true)
	invalid["progression"]["equipment_levels"]["hero_sword"] = 1.25
	_expect(not bool(manager.call("_normalize_profile", invalid).get("valid", false)), "fractional equipment levels are rejected")
	invalid = snapshot.duplicate(true)
	invalid["progression"]["equipment_levels"]["not-an-item"] = 1
	_expect(not bool(manager.call("_normalize_profile", invalid).get("valid", false)), "unknown equipment IDs are rejected")
	invalid = snapshot.duplicate(true)
	invalid["progression"]["unknown_section"] = {}
	_expect(not bool(manager.call("_normalize_profile", invalid).get("valid", false)), "progression section keys are exact")

	var future_v3: Dictionary = snapshot.duplicate(true)
	future_v3["version"] = 3
	future_v3["future_payload"] = {"newer": true}
	var future_backup: Dictionary = next_snapshot.duplicate(true)
	_atomic_write(future_path, JSON.stringify(future_v3))
	_atomic_write(future_path + ".bak", JSON.stringify(future_backup))
	var future_primary_bytes: PackedByteArray = AtomicFile.read_bytes(future_path)
	var future_old_backup_bytes: PackedByteArray = AtomicFile.read_bytes(future_path + ".bak")
	manager.set("save_path", future_path)
	_expect(manager.call("load_profile", future_path).is_empty(), "v3 primary refuses to load over an older backup")
	_expect(manager.get("writes_blocked") and manager.get("last_load_source") == "future_version", "future primary blocks all writes")
	_expect(manager.call("save_profile", snapshot, future_path) == ERR_UNAVAILABLE, "manual v2 write refuses a future primary")
	_expect(manager.call("save_game") == ERR_UNAVAILABLE, "game save also refuses a future primary")
	manager.set("autosave_elapsed", 60.0)
	manager.call("_process", 60.0)
	_expect(AtomicFile.read_bytes(future_path) == future_primary_bytes, "autosave leaves future primary byte-for-byte intact")
	_expect(AtomicFile.read_bytes(future_path + ".bak") == future_old_backup_bytes, "autosave leaves existing backup byte-for-byte intact")

	var current_primary: Dictionary = snapshot.duplicate(true)
	var future_backup_profile: Dictionary = future_v3.duplicate(true)
	_atomic_write(future_backup_path, JSON.stringify(current_primary))
	_atomic_write(future_backup_path + ".bak", JSON.stringify(future_backup_profile))
	var current_primary_bytes: PackedByteArray = AtomicFile.read_bytes(future_backup_path)
	var future_backup_bytes: PackedByteArray = AtomicFile.read_bytes(future_backup_path + ".bak")
	manager.set("save_path", future_backup_path)
	var primary_with_future_backup: Dictionary = manager.call("load_profile", future_backup_path)
	_expect(primary_with_future_backup.get("gold") == 500, "valid current primary remains loadable beside a future backup")
	_expect(manager.get("writes_blocked"), "future backup blocks writes while preserving the current primary")
	_expect(manager.call("save_profile", snapshot, future_backup_path) == ERR_UNAVAILABLE, "save refuses a future backup")
	_expect(AtomicFile.read_bytes(future_backup_path) == current_primary_bytes, "future backup guard retains the primary bytes")
	_expect(AtomicFile.read_bytes(future_backup_path + ".bak") == future_backup_bytes, "future backup bytes remain untouched")

	var malformed: Dictionary = snapshot.duplicate(true)
	malformed["progression"]["training"] = [1, 2.25, 1, 1]
	var malformed_bytes: String = JSON.stringify(malformed)
	var malformed_backup_bytes: String = "{ broken nested backup"
	_atomic_write(malformed_path, malformed_bytes)
	_atomic_write(malformed_path + ".bak", malformed_backup_bytes)
	var retained_primary: PackedByteArray = AtomicFile.read_bytes(malformed_path)
	var retained_backup: PackedByteArray = AtomicFile.read_bytes(malformed_path + ".bak")
	manager.set("save_path", malformed_path)
	_expect(manager.call("load_profile", malformed_path).is_empty(), "two malformed current-schema profiles are not reset")
	_expect(manager.get("writes_blocked") and manager.get("last_load_source") == "corrupt", "two malformed files block writes")
	_expect(manager.call("save_profile", snapshot, malformed_path) == ERR_UNAVAILABLE, "malformed primary and backup refuse replacement")
	_expect(AtomicFile.read_bytes(malformed_path) == retained_primary, "malformed primary remains available for inspection")
	_expect(AtomicFile.read_bytes(malformed_path + ".bak") == retained_backup, "malformed backup remains available for inspection")

	var recovery_primary: String = "{ not a v2 save"
	_atomic_write(recovery_path, recovery_primary)
	_atomic_write(recovery_path + ".bak", JSON.stringify(v1))
	var recovered: Dictionary = manager.call("load_profile", recovery_path)
	_expect(recovered.get("gold") == 371 and recovered.get("version") == 2, "valid v1 backup still recovers after migration")
	_expect(manager.get("last_load_source") == "backup", "fallback reports the backup recovery source")
	_expect(AtomicFile.read_bytes(recovery_path).get_string_from_utf8() == recovery_primary, "recovery preserves the damaged primary file")

	_finish("SAVE V2 MIGRATION AND VALIDATION")


func _v1_profile(gold: int, kills: int, stage: String, timestamp: int) -> Dictionary:
	return {
		"version": 1,
		"last_active_timestamp": timestamp,
		"gold": gold,
		"kills": kills,
		"current_stage": stage,
	}


func _json_copy(value: Dictionary) -> Dictionary:
	var parser := JSON.new()
	var parse_error: Error = parser.parse(JSON.stringify(value))
	if parse_error != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	return parser.data


func _atomic_write(path: String, text: String) -> void:
	_expect(AtomicFile.write_text(path, text) == OK, "fixture write succeeds: " + path.get_file())


func _remove_files(path: String) -> void:
	for candidate: String in [path, path + ".bak", path + ".tmp", path + ".old"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
