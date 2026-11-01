extends "res://addons/proto_kit/test_kit.gd"
## Persisted files replaced during a running game must not be silently downgraded.
const SaveSlots = preload("res://addons/proto_kit/save_slots.gd")
const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
const BASE := "user://test_save_protection/"
var main: Node3D

func _init() -> void:
	_run.call_deferred()

func _open(name: String) -> void:
	if main:
		main.queue_free()
		await _frames(2)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = BASE.path_join(name + ".json")
	root.add_child(main)
	await _frames(3)
	main.set_process(false)
	main.player.set_process(false)
	for monster: Node3D in get_nodes_in_group("monster"):
		monster.set_process(false)

func _clear(name: String) -> String:
	var path := BASE.path_join(name + ".json")
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)
	return path

func _run() -> void:
	var replacements := {
		"future": '{"version":999,"data":{"gold":999}}',
		"fractional_future": '{"version":6.5,"data":{"gold":999}}',
		"string_version": '{"version":"6","data":{}}',
		"bool_version": '{"version":true,"data":{}}',
		"truncated": '{"version":6,',
		"empty": '',
		"bad_payload": '{"version":6,"data":{"bag":"broken"}}',
	}
	for name: String in replacements:
		var path := _clear(name)
		await _open(name)
		_expect(main.save_game() == OK, "valid initial save " + name)
		_expect(main.save_game() == OK, "valid initial backup " + name)
		AtomicFile.write_text(path, replacements[name])
		var before: PackedByteArray = AtomicFile.read_bytes(path)
		var backup: PackedByteArray = AtomicFile.read_bytes(path + ".bak")
		main._on_backgrounded(true)
		_expect(AtomicFile.read_bytes(path) == before and AtomicFile.read_bytes(path + ".bak") == backup,
			"background save preserves replaced primary and backup: " + name)
		_expect(not main.save_blocked_reason.is_empty() and main.save_game() != OK,
			"replacement locks subsequent saves: " + name)
	var path := _clear("invalid_snapshot")
	await _open("invalid_snapshot")
	main.save_game()
	main.save_game()
	var before: PackedByteArray = AtomicFile.read_bytes(path)
	var backup: PackedByteArray = AtomicFile.read_bytes(path + ".bak")
	for i in 13:
		main.player.bag.slots.append({"id": "apple", "count": 1})
	_expect(main.save_game() != OK and AtomicFile.read_bytes(path) == before
		and AtomicFile.read_bytes(path + ".bak") == backup, "invalid outgoing snapshot preserves both saved files")
	path = _clear("recovery_race")
	SaveSlots.save(path, {"level": 3}, 6)
	SaveSlots.save(path, {"level": 5}, 6)
	AtomicFile.write_text(path, '{"version":6,"data":null}')
	await _open("recovery_race")
	_expect(main.player.level == 3, "pending recovery loads validated backup")
	AtomicFile.write_text(path, '{"version":999,"data":{"level":99}}')
	before = AtomicFile.read_bytes(path)
	backup = AtomicFile.read_bytes(path + ".bak")
	_expect(main.save_game() != OK and AtomicFile.read_bytes(path) == before
		and AtomicFile.read_bytes(path + ".bak") == backup, "pending recovery cannot replace a newly supplied future primary")
	path = _clear("future_backup")
	await _open("future_backup")
	main.save_game()
	AtomicFile.write_text(path + ".bak", '{"version":999,"data":{"level":99}}')
	before = AtomicFile.read_bytes(path)
	backup = AtomicFile.read_bytes(path + ".bak")
	_expect(main.save_game() != OK and AtomicFile.read_bytes(path) == before
		and AtomicFile.read_bytes(path + ".bak") == backup, "save rotation preserves a newly supplied future backup")
	for name: String in ["fractional_future", "string_version", "bool_version"]:
		path = _clear("load_" + name)
		AtomicFile.write_text(path, replacements[name])
		before = AtomicFile.read_bytes(path)
		await _open("load_" + name)
		_expect(not main.save_blocked_reason.is_empty() and main.save_game() != OK
			and AtomicFile.read_bytes(path) == before, "loading rejects invalid envelope version: " + name)
	# Positive compatibility prevents an overly strict reader from locking valid legacy saves.
	for version in range(1, 7):
		path = _clear("legacy_%d" % version)
		SaveSlots.save(path, {"level": 3, "xp": 7}, version)
		await _open("legacy_%d" % version)
		_expect(main.player.level == 3 and main.player.xp == 7 and main.save_blocked_reason == ""
			and main.save_game() == OK, "supported v%d save still loads, migrates and writes" % version)
		var migrated: Dictionary = SaveSlots.restore(path, 6)
		_expect(migrated.error == "" and int(migrated.data.level) == 3, "v%d upgrades to a readable v6 checkpoint" % version)
	path = _clear("header_backup")
	SaveSlots.save(path, {"level": 4}, 6)
	SaveSlots.save(path, {"level": 5}, 6)
	AtomicFile.write_text(path, replacements.string_version)
	await _open("header_backup")
	_expect(main.player.level == 4 and main.save_game() == OK, "invalid header restores a valid backup and can checkpoint")
	path = _clear("replaced_recovery_backup")
	SaveSlots.save(path, {"level": 3}, 6)
	SaveSlots.save(path, {"level": 5}, 6)
	AtomicFile.write_text(path, '{"version":6,"data":null}')
	await _open("replaced_recovery_backup")
	AtomicFile.write_text(path + ".bak", '{"version":6,"data":{"level":88}}')
	before = AtomicFile.read_bytes(path)
	backup = AtomicFile.read_bytes(path + ".bak")
	_expect(main.save_game() != OK and AtomicFile.read_bytes(path) == before
		and AtomicFile.read_bytes(path + ".bak") == backup, "pending recovery preserves a replaced same-version backup")
	main.queue_free()
	await _frames(2)
	_finish("SEAL MEADOW SAVE PROTECTION TESTS")
