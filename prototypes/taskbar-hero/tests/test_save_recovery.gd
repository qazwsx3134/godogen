extends "res://addons/proto_kit/test_kit.gd"

const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const TestBootstrap = preload("res://tests/test_bootstrap.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	TestBootstrap.add_services(root)
	var save_manager: Node = root.get_node("SaveManager")
	var save_script: Script = load("res://autoload/save_manager.gd") as Script
	var manager: Node = save_script.new() as Node
	manager.name = "SaveManagerUnderTest"
	var base: String = "user://taskbar-hero-tests/save"
	var first_run_path: String = base + "_fresh.json"
	var recovery_path: String = base + "_recovery.json"
	var future_path: String = base + "_future.json"
	var future_backup_path: String = base + "_future_backup.json"
	var corrupt_path: String = base + "_corrupt.json"
	var fractional_path: String = base + "_fractional.json"
	for path: String in [first_run_path, recovery_path, future_path, future_backup_path, corrupt_path, fractional_path]:
		_remove_files(path)
	manager.set("save_path", first_run_path)
	root.add_child(manager)
	await _frames(1)

	var fresh: Dictionary = manager.call("load_profile", first_run_path)
	_expect(fresh.is_empty(), "missing save files start a new profile")
	_expect(manager.get("last_load_source") == "new" and not manager.get("writes_blocked"), "fresh install is not mistaken for corruption")

	var float_profile: Dictionary = _profile(42.0, 5.0, 1200.0)
	var save_result: int = manager.call("save_profile", float_profile, recovery_path)
	_expect(save_result == OK, "finite whole-number JSON values normalize for save")
	var normalized: Dictionary = manager.call("load_profile", recovery_path)
	_expect(normalized.get("gold") == 42 and normalized.get("kills") == 5, "whole-number numeric values load as integers")
	var newer_profile: Dictionary = _profile(50, 7, 1300)
	_expect(manager.call("save_profile", newer_profile, recovery_path) == OK, "second save commits and backs up the verified first profile")
	var broken_primary: String = "{ this file is intentionally damaged"
	_atomic_write(recovery_path, broken_primary)
	var recovered: Dictionary = manager.call("load_profile", recovery_path)
	_expect(recovered.get("gold") == 42, "valid backup recovers a corrupted primary")
	_expect(manager.get("last_load_source") == "backup", "recovery source is reported")
	_expect(not str(manager.get("last_load_message")).is_empty(), "backup recovery has visible explanation")
	_expect(AtomicFile.read_bytes(recovery_path).get_string_from_utf8() == broken_primary, "load recovery preserves damaged primary for inspection")

	var fractional_profile: Dictionary = _profile(4.5, 1, 1400)
	_atomic_write(fractional_path, JSON.stringify(fractional_profile))
	var fractional: Dictionary = manager.call("load_profile", fractional_path)
	_expect(fractional.is_empty() and manager.get("writes_blocked"), "fractional save values are rejected")
	var out_of_range: Dictionary = _profile(1000000000, 1, 1400)
	_expect(not bool(manager.call("_normalize_profile", out_of_range).get("valid", false)), "out-of-range counters are rejected")

	var v1_backup: Dictionary = _profile(31, 4, 1500)
	var future_expanded: Dictionary = {
		"version": 3,
		"last_active_timestamp": 1700,
		"gold": 99,
		"kills": 8,
		"current_stage": "1-1",
		"inventory": [{"uid": "future-item-1"}],
	}
	_atomic_write(future_path, JSON.stringify(future_expanded))
	_atomic_write(future_path + ".bak", JSON.stringify(v1_backup))
	var future_main_bytes: PackedByteArray = AtomicFile.read_bytes(future_path)
	var old_backup_bytes: PackedByteArray = AtomicFile.read_bytes(future_path + ".bak")
	var future_load: Dictionary = manager.call("load_profile", future_path)
	_expect(future_load.is_empty(), "future v3 is detected before current exact-key validation")
	_expect(manager.get("writes_blocked") and manager.get("last_load_source") == "future_version", "future primary blocks all writes despite old backup")
	manager.set("save_path", future_path)
	_expect(manager.call("save_profile", _profile(0, 0, 1800), future_path) == ERR_UNAVAILABLE, "manual save refuses future profile")
	_expect(manager.get("writes_blocked") and not str(manager.get("last_load_message")).is_empty(), "direct save refusal retains visible future-version block")
	_expect(manager.call("save_game") == ERR_UNAVAILABLE, "manual game save remains blocked for future profile")
	manager.set("autosave_elapsed", 60.0)
	manager.call("_process", 60.0)
	_expect(AtomicFile.read_bytes(future_path) == future_main_bytes, "manual/autosave leave future primary byte-identical")
	_expect(AtomicFile.read_bytes(future_path + ".bak") == old_backup_bytes, "manual/autosave leave valid old backup byte-identical")

	var current_profile: Dictionary = _profile(15, 2, 1900)
	var future_backup: Dictionary = future_expanded.duplicate(true)
	_atomic_write(future_backup_path, JSON.stringify(current_profile))
	_atomic_write(future_backup_path + ".bak", JSON.stringify(future_backup))
	var current_bytes: PackedByteArray = AtomicFile.read_bytes(future_backup_path)
	var future_backup_bytes: PackedByteArray = AtomicFile.read_bytes(future_backup_path + ".bak")
	manager.set("save_path", future_backup_path)
	var current_load: Dictionary = manager.call("load_profile", future_backup_path)
	_expect(current_load.get("gold") == 15, "current primary still loads beside a future backup")
	_expect(manager.get("writes_blocked") and not str(manager.get("last_load_message")).is_empty(), "future backup surfaces a write-block warning")
	manager.set("writes_blocked", false)
	manager.set("last_load_message", "")
	_expect(manager.call("save_profile", _profile(0, 0, 2000), future_backup_path) == ERR_UNAVAILABLE, "direct save refuses a future backup")
	_expect(manager.get("writes_blocked") and not str(manager.get("last_load_message")).is_empty(), "direct future-backup refusal sets the persistent write block")
	manager.set("save_path", future_backup_path)
	_expect(manager.call("save_game") == ERR_UNAVAILABLE, "future backup blocks manual save")
	manager.set("autosave_elapsed", 60.0)
	manager.call("_process", 60.0)
	_expect(AtomicFile.read_bytes(future_backup_path) == current_bytes, "primary remains unchanged beside future backup")
	_expect(AtomicFile.read_bytes(future_backup_path + ".bak") == future_backup_bytes, "future backup remains unchanged")

	var corrupt_primary: String = "not-json-primary"
	var corrupt_backup: String = "not-json-backup"
	_atomic_write(corrupt_path, corrupt_primary)
	_atomic_write(corrupt_path + ".bak", corrupt_backup)
	var corrupt_main_bytes: PackedByteArray = AtomicFile.read_bytes(corrupt_path)
	var corrupt_backup_bytes: PackedByteArray = AtomicFile.read_bytes(corrupt_path + ".bak")
	var no_recovery: Dictionary = manager.call("load_profile", corrupt_path)
	_expect(no_recovery.is_empty() and manager.get("writes_blocked"), "two corrupt files block writes instead of resetting")
	_expect(not str(manager.get("last_load_message")).is_empty(), "two corrupt files produce a visible recovery message")
	manager.set("save_path", corrupt_path)
	_expect(manager.call("save_game") == ERR_UNAVAILABLE, "both corrupt files reject manual save")
	manager.set("autosave_elapsed", 60.0)
	manager.call("_process", 60.0)
	_expect(AtomicFile.read_bytes(corrupt_path) == corrupt_main_bytes, "autosave preserves corrupt primary byte-for-byte")
	_expect(AtomicFile.read_bytes(corrupt_path + ".bak") == corrupt_backup_bytes, "autosave preserves corrupt backup byte-for-byte")

	var old_global_message: String = str(save_manager.get("last_load_message"))
	save_manager.set("last_load_message", str(manager.get("last_load_message")))
	root.size = Vector2i(320, 568)
	var main: Control = MAIN_SCENE.instantiate() as Control
	root.add_child(main)
	await _frames(3)
	var status: Label = main.get_node("MessagePanel/MessageText") as Label
	_expect(status.text == str(manager.get("last_load_message")), "Main scene surfaces the damaged-save warning")
	_expect(main.get_node("SettingsPanel/SaveNotice").text == str(manager.get("last_load_message")), "settings retains save warning after transient message expires")
	save_manager.set("last_load_message", old_global_message)

	_finish("SAVE MIGRATION AND RECOVERY")

func _profile(gold_value: Variant, kills_value: Variant, timestamp: Variant) -> Dictionary:
	return {
		"version": 1,
		"last_active_timestamp": timestamp,
		"gold": gold_value,
		"kills": kills_value,
		"current_stage": "1-1",
	}

func _atomic_write(path: String, text: String) -> void:
	var error: Error = AtomicFile.write_text(path, text)
	_expect(error == OK, "fixture write succeeds: " + path.get_file())

func _remove_files(path: String) -> void:
	for candidate: String in [path, path + ".bak", path + ".tmp", path + ".old"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
