extends "res://addons/proto_kit/test_kit.gd"
## Self-test for the kit: godot --headless --path . --script res://tests/test_proto_kit.gd

const Synth = preload("res://addons/proto_kit/synth.gd")
const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
const DIR: String = "user://proto_kit_test"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_synth()
	_test_atomic_file()
	await _test_harness_input()
	_finish("PROTO KIT TESTS")


func _test_synth() -> void:
	_expect(Synth.ramp(200.0, 400.0, 0.5).data.size() == int(0.5 * Synth.RATE) * 2, "ramp length")
	_expect(Synth.notes([440.0, 660.0], 0.1).data.size() == int(Synth.RATE * 0.1) * 2 * 2, "notes length")
	_expect(Synth.click(0.1).data == Synth.click(0.1).data, "click is deterministic")
	_expect(Synth.notes([440.0], 0.1, true).data != Synth.notes([440.0], 0.1).data, "soft changes the wave")


func _test_atomic_file() -> void:
	var path: String = DIR + "/nested/save.json"
	_cleanup()
	_expect(AtomicFile.write_text(path, "first") == OK, "write creates missing directories")
	_expect(AtomicFile.write_text(path, "second") == OK, "write replaces an existing file")
	_expect(AtomicFile.read_bytes(path).get_string_from_utf8() == "second", "read returns the last write")
	_expect(not FileAccess.file_exists(path + ".tmp") and not FileAccess.file_exists(path + ".old"),
		"commit leaves no sidecars")
	_expect(AtomicFile.write_text("", "x") != OK, "empty path is rejected")
	_expect(AtomicFile.read_bytes(DIR + "/missing").is_empty(), "missing file reads empty")

	var payload: Dictionary = {"node": "intro", "step": 3, "flags": {"a": true}, "items": ["milk"]}
	var var_path: String = DIR + "/slot.save"
	_expect(AtomicFile.write_var(var_path, payload) == OK, "write_var succeeds")
	var file: FileAccess = FileAccess.open(var_path, FileAccess.READ)
	_expect(file != null and file.get_var(false) == payload, "FileAccess.get_var reads write_var")
	var reference_path: String = DIR + "/reference.save"
	var reference: FileAccess = FileAccess.open(reference_path, FileAccess.WRITE)
	reference.store_var(payload, false)
	reference.close()
	_expect(AtomicFile.read_bytes(var_path) == AtomicFile.read_bytes(reference_path),
		"write_var bytes match FileAccess.store_var")
	_cleanup()


func _test_harness_input() -> void:
	root.size = Vector2i(480, 360)  # headless windows start at 64x64
	var button := Button.new()
	button.text = "Tap"
	button.position = Vector2(40, 40)
	button.size = Vector2(120, 60)
	root.add_child(button)
	var presses: Array[int] = [0]
	button.pressed.connect(func() -> void: presses[0] += 1)
	await _frames(2)
	await _tap(button.get_global_rect().get_center())
	_expect(presses[0] == 1, "_tap presses a button")
	await _press(button)
	_expect(presses[0] == 2, "_press presses a button")
	var ready_at: int = Time.get_ticks_msec() + 50
	await _until(func() -> bool: return Time.get_ticks_msec() >= ready_at, "until waits for a condition")
	_expect(not failures.any(func(f: String) -> bool: return f.begins_with("timed out")), "until returns before its timeout")
	button.queue_free()


func _cleanup() -> void:
	for path: String in [DIR + "/nested/save.json", DIR + "/slot.save", DIR + "/reference.save"]:
		for suffix: String in ["", ".tmp", ".old"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
