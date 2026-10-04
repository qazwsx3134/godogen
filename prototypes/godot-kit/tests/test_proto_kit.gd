extends "res://addons/proto_kit/test_kit.gd"
## Self-test for the kit: godot --headless --path . --script res://tests/test_proto_kit.gd

const Synth = preload("res://addons/proto_kit/synth.gd")
const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const FontCheck = preload("res://addons/proto_kit/font_check.gd")
const SfxBank = preload("res://addons/proto_kit/sfx_bank.gd")
const Haptics = preload("res://addons/proto_kit/haptics.gd")
const TimeControl = preload("res://addons/proto_kit/time_control.gd")
const Music = preload("res://addons/proto_kit/music.gd")
const CameraShake = preload("res://addons/proto_kit/camera_shake.gd")
const FloatingStick = preload("res://addons/proto_kit/floating_stick.gd")
const SceneLoader = preload("res://addons/proto_kit/scene_loader.gd")
const DIR: String = "user://proto_kit_test"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_synth()
	_test_atomic_file()
	_test_scene_builder()
	_test_font_check()
	await _test_sfx_bank()
	_test_haptics()
	await _test_time_control()
	await _test_music()
	_test_camera_shake()
	await _test_floating_stick()
	await _test_scene_loader()
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


## Collects push_error text, so a test can assert an expected failure.
class ErrorLog extends Logger:
	var messages: Array[String] = []

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		messages.append(rationale if not rationale.is_empty() else code)


func _test_scene_builder() -> void:
	var dir: String = DIR + "/scenes"
	var child_path: String = dir + "/child.tscn"
	var parent_path: String = dir + "/nested/parent.tscn"
	_remove_tree(dir)

	var child_root := _named("Child")
	child_root.position = Vector2(5, 7)
	SceneBuilder.add(child_root, Node2D.new(), "Inner")
	var child: Dictionary = SceneBuilder.save_scene(child_root, child_path)
	_expect(child.ok and child.nodes == 2 and child.refs.is_empty() and child.error == "", "scene_builder saves a plain tree")
	_expect(not is_instance_valid(child_root), "scene_builder frees the root it saved")
	if not child.ok:
		_remove_tree(dir)
		return

	var parent_root := _named("Parent")
	SceneBuilder.add(parent_root, SceneBuilder.unique(Label.new()), "Title")
	SceneBuilder.add(parent_root, SceneBuilder.instance(child_path), "ChildA")
	var holder: Node = SceneBuilder.add(parent_root, Node2D.new(), "Holder")
	SceneBuilder.add(holder, SceneBuilder.unique(SceneBuilder.instance(child_path)), "ChildB")
	var parent: Dictionary = SceneBuilder.save_scene(parent_root, parent_path, {"expected_refs": [child_path]})
	_expect(parent.ok and parent.error == "", "scene_builder saves a tree with sub-scene instances (%s)" % parent.error)
	_expect(parent.nodes == 7, "nodes counts the inner nodes of instances too (%d)" % parent.nodes)
	_expect(parent.refs.size() == 1 and parent.refs[0] == child_path, "refs lists each sub-scene path once")
	_expect(FileAccess.file_exists(parent_path), "scene_builder creates missing folders")

	var packed := ResourceLoader.load(parent_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		_expect(false, "the saved scene loads")
		_remove_tree(dir)
		return
	var state: SceneState = packed.get_state()
	var saved_names: Array[String] = []
	var overrides: int = -1
	for index: int in state.get_node_count():
		saved_names.append(String(state.get_node_name(index)))
		if state.get_node_name(index) == &"ChildA":
			overrides = state.get_node_property_count(index)
	_expect(state.get_node_count() == 5 and not saved_names.has("Inner"), "inner nodes of a sub-scene are not saved as the parent's own nodes (%s)" % [saved_names])
	_expect(overrides == 0, "instance() saves a clean reference: the sub-scene root's own properties are not copied (%d overrides)" % overrides)
	var scene: Node = packed.instantiate()
	var title: Node = scene.get_node_or_null("%Title")
	_expect(title is Label and title.get_meta_list().is_empty(), "unique() node resolves as %Title without a leftover meta")
	_expect(scene.get_node_or_null("%ChildB") != null, "unique() works on a sub-scene instance root")
	scene.free()

	var plain := Node.new()
	var first: Node = SceneBuilder.add(plain, Label.new())
	var second: Node = SceneBuilder.add(plain, Label.new())
	_expect(first.name == &"Label" and second.name == &"Label2", "add names unnamed nodes after their type, numbered on a clash (%s, %s)" % [first.name, second.name])
	plain.free()

	var md5: String = FileAccess.get_md5(parent_path)
	var doomed := _named("Other")
	var skipped: Dictionary = SceneBuilder.save_scene(doomed, parent_path)
	_expect(skipped.ok and skipped.skipped and skipped.nodes == 0, "an existing file is skipped by default")
	_expect(FileAccess.get_md5(parent_path) == md5, "skipping leaves the file byte-identical")
	_expect(not is_instance_valid(doomed), "skipping frees the root")
	var replaced: Dictionary = SceneBuilder.save_scene(_named("Other"), parent_path, {"overwrite": true})
	_expect(replaced.ok and not replaced.skipped and FileAccess.get_md5(parent_path) != md5, "overwrite replaces an existing file")

	# overwrite is checked against the file just written, not a cached copy of the old one
	var cached_path: String = dir + "/cached.tscn"
	SceneBuilder.save_scene(_named("Old"), cached_path)
	var stale: PackedScene = load(cached_path)
	var fresh_root := _named("New")
	SceneBuilder.add(fresh_root, SceneBuilder.instance(child_path), "Child")
	var fresh: Dictionary = SceneBuilder.save_scene(fresh_root, cached_path, {"overwrite": true, "expected_refs": [child_path]})
	_expect(stale != null and fresh.ok, "overwrite is verified against the new file, not the cached old one (%s)" % fresh.error)

	var errors := ErrorLog.new()
	OS.add_logger(errors)
	print("(expected) the ERROR lines below are save_scene failures under test")
	var missing_path: String = dir + "/missing.tscn"
	var missing: Dictionary = SceneBuilder.save_scene(_named("Bad"), dir + "/bad.tscn", {"expected_refs": [missing_path]})
	var dropped_root := _named("Dropped")
	var inner_instance: Node = SceneBuilder.add(dropped_root, SceneBuilder.instance(child_path), "Child")
	SceneBuilder.add(inner_instance, Node2D.new(), "Extra")  # under a sub-scene instance: pack() drops it
	var dropped: Dictionary = SceneBuilder.save_scene(dropped_root, dir + "/dropped.tscn")
	var unsaveable: Dictionary = SceneBuilder.save_scene(_named("Odd"), dir + "/odd.unknown")
	OS.remove_logger(errors)
	_expect(not missing.ok and missing.error.contains(missing_path), "a missing expected_refs entry fails (%s)" % missing.error)
	_expect(not dropped.ok and dropped.error.contains("4 nodes built, 3 after reload"), "a node dropped by pack() fails the node-count check (%s)" % dropped.error)
	_expect(not unsaveable.ok and unsaveable.error.begins_with("cannot save"), "a file ResourceSaver cannot write fails (%s)" % unsaveable.error)
	for reported: String in [missing_path, "4 nodes built", "cannot save"]:
		_expect(errors.messages.any(func(message: String) -> bool: return message.contains(reported)), "failure push_errors: " + reported)
	_expect(not FileAccess.file_exists(dir + "/bad.tscn") and not FileAccess.file_exists(dir + "/dropped.tscn"), "a failed save does not leave its file behind")
	_remove_tree(dir)


func _named(node_name: String) -> Node:
	var node := Node2D.new()
	node.name = node_name
	return node


func _remove_tree(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	for folder: String in DirAccess.get_directories_at(dir):
		_remove_tree(dir.path_join(folder))
	DirAccess.remove_absolute(dir)


## The buzz rules on a clock moved by hand, so nothing waits and nothing is flaky. Input.vibrate_handheld does
## nothing on a desktop, so there is nothing to mock: what went out is read from `vibrated`. Every label starts
## with "haptics:", so a failure here is told from the other suites' at a glance.
func _test_haptics() -> void:
	var now: Array[int] = [0]
	var clock := func() -> int: return now[0]
	var seen: Array = []   # [duration_ms, amplitude] of every buzz that went out
	var fresh := func() -> Haptics:   # a new one on the hand-moved clock, default rules, nothing seen yet
		seen.clear()
		now[0] = 0
		var made := Haptics.new()
		made.clock = clock
		made.vibrated.connect(func(ms: int, amplitude: float) -> void: seen.append([ms, amplitude]))
		return made
	var buzz := func(haptics: Haptics, at: int, tier: int) -> void:
		now[0] = at
		haptics.buzz(tier)

	var h: Haptics = fresh.call()
	_expect(h.enabled and h.scale == 1.0 and h.min_gap_ms == 70 and h.max_per_second == 6, "haptics: the defaults are on, scale 1, a 70 ms gap and 6 a second")
	_expect(Array(h.durations_ms) == [14, 38, 90] and Array(h.amplitudes) == [0.35, 0.65, 1.0], "haptics: three tiers by default: 14, 38 and 90 ms at 0.35, 0.65 and 1.0, exactly")
	for tier: int in 3:   # exact: a 32-bit amplitude array would hand 0.35 back as 0.3499999940395355
		h = fresh.call()
		buzz.call(h, 0, tier)
		_expect(seen == [[[14, 38, 90][tier], [0.35, 0.65, 1.0][tier]]], "haptics: tier %d buzzes its own length and strength, exactly (%s)" % [tier, seen])

	# `vibrated` reports round(ms x scale), never under 1 ms, and the strength is not scaled.
	for row: Array in [[2, 2.0, 180], [0, 2.0, 28], [0, 0.2, 3], [0, 0.1, 1], [0, 0.02, 1]]:   # tier, scale, ms
		h = fresh.call()
		h.scale = row[1]
		buzz.call(h, 0, row[0])
		_expect(seen == [[row[2], [0.35, 0.65, 1.0][row[0]]]], "haptics: scale %s on tier %d buzzes %d ms at the tier's own strength (%s)" % [row[1], row[0], row[2], seen])

	# Rule 1: the switch and the scale.
	h = fresh.call()
	h.enabled = false
	buzz.call(h, 0, 2)
	buzz.call(h, 5000, 0)
	_expect(seen.is_empty(), "haptics: enabled off: nothing buzzes")
	h.enabled = true
	buzz.call(h, 5010, 0)   # 10 ms after a buzz the switch swallowed: inside the gap, but that buzz left no trace
	_expect(seen == [[14, 0.35]], "haptics: switching it back on works at once (%s)" % [seen])
	h = fresh.call()
	h.scale = 0.0
	buzz.call(h, 0, 2)
	buzz.call(h, 5000, 0)
	_expect(seen.is_empty(), "haptics: scale 0: nothing buzzes")

	# Rule 2, the gap (the same tier, so only the gap decides).
	h = fresh.call()
	buzz.call(h, 0, 0)
	buzz.call(h, 69, 0)
	_expect(seen.size() == 1, "haptics: 69 ms after the last buzz: dropped")
	buzz.call(h, 70, 0)
	_expect(seen.size() == 2, "haptics: 70 ms after it: goes out")
	buzz.call(h, 139, 0)
	_expect(seen.size() == 2, "haptics: the gap counts from the last buzz that went out, not from a dropped one")
	buzz.call(h, 140, 0)
	_expect(seen.size() == 3, "haptics: 70 ms after that one: goes out again")
	h = fresh.call()
	h.min_gap_ms = 200
	buzz.call(h, 0, 0)
	buzz.call(h, 199, 0)
	buzz.call(h, 200, 0)
	_expect(seen.size() == 2, "haptics: min_gap_ms sets the gap (199 dropped, 200 goes out)")

	# Rule 2, the cap per second (the gap is off here): six in a second, the seventh waits for the first to age out.
	h = fresh.call()
	h.min_gap_ms = 0
	for i: int in 7:
		buzz.call(h, i * 10, 0)
	_expect(seen.size() == 6, "haptics: the seventh buzz within a second is dropped (%d went out)" % seen.size())
	buzz.call(h, 999, 0)
	_expect(seen.size() == 6, "haptics: 999 ms in: the first buzz is still inside the window")
	buzz.call(h, 1000, 0)
	_expect(seen.size() == 7, "haptics: 1000 ms in: the first has aged out, one more goes")
	h = fresh.call()
	h.min_gap_ms = 0
	h.max_per_second = 2
	for i: int in 3:
		buzz.call(h, i, 0)
	_expect(seen.size() == 2, "haptics: max_per_second sets the cap")

	# A bigger tier than the last one passes the gap and the cap; a repeat or a weaker one does not.
	h = fresh.call()
	buzz.call(h, 0, 0)
	buzz.call(h, 10, 1)
	buzz.call(h, 20, 2)
	_expect(seen.size() == 3, "haptics: a bigger tier than the last passes the gap: small, medium, large in a row (%s)" % [seen])
	buzz.call(h, 30, 2)
	buzz.call(h, 40, 0)
	_expect(seen.size() == 3, "haptics: a repeat of the last tier, or a weaker one, still waits out the gap")
	h = fresh.call()
	h.min_gap_ms = 0
	for i: int in 6:
		buzz.call(h, i * 10, 0)
	buzz.call(h, 60, 0)
	_expect(seen.size() == 6, "haptics: six smalls fill the second")
	buzz.call(h, 70, 1)
	_expect(seen.size() == 7, "haptics: a medium passes the full second")
	buzz.call(h, 80, 1)
	_expect(seen.size() == 7, "haptics: a second medium does not")
	buzz.call(h, 90, 2)
	_expect(seen.size() == 8, "haptics: a large does")

	# Rule 3: a weaker buzz does not cut off a stronger one that is still running (the gap is off here).
	h = fresh.call()
	h.min_gap_ms = 0
	buzz.call(h, 0, 2)   # runs until 90
	buzz.call(h, 50, 1)
	buzz.call(h, 50, 0)
	_expect(seen.size() == 1, "haptics: a medium or a small buzz is dropped while a large one runs")
	buzz.call(h, 50, 2)   # runs until 140
	_expect(seen.size() == 2, "haptics: a large one may replace a running large one")
	buzz.call(h, 139, 0)
	_expect(seen.size() == 2, "haptics: still running at 139 ms (it started at 50 and runs 90 ms)")
	buzz.call(h, 140, 0)
	_expect(seen.size() == 3 and seen[2] == [14, 0.35], "haptics: a weaker buzz goes out once the stronger one has ended (%s)" % [seen])
	h = fresh.call()
	h.min_gap_ms = 0
	buzz.call(h, 0, 1)   # runs until 38
	buzz.call(h, 37, 0)
	_expect(seen.size() == 1, "haptics: a small buzz is dropped while a medium one runs")
	buzz.call(h, 38, 0)
	_expect(seen.size() == 2, "haptics: and goes out the moment it has ended")

	# A new clock starts the rules from nothing (the time may restart from 0).
	h = fresh.call()
	buzz.call(h, 5000, 2)
	now[0] = 0
	h.clock = clock
	buzz.call(h, 0, 0)
	_expect(seen.size() == 2, "haptics: assigning a clock forgets the earlier buzzes (%s)" % [seen])
	h = fresh.call()
	h.min_gap_ms = 0
	for i: int in 6:
		buzz.call(h, i * 10, 0)
	h.clock = clock
	seen.clear()
	buzz.call(h, 0, 0)
	buzz.call(h, 100, 0)
	_expect(seen.size() == 2, "haptics: assigning a clock forgets the buzzes of the last second too, the cap starts again (%s)" % [seen])
	now[0] = 1234
	_expect(h.now_ms() == 1234, "haptics: now_ms() reads the clock that was set")

	# No clock: the wall clock (the one real wait in this test).
	var wall := Haptics.new()
	var wall_buzzes: Array[int] = [0]
	wall.vibrated.connect(func(_ms: int, _amplitude: float) -> void: wall_buzzes[0] += 1)
	wall.min_gap_ms = 30
	wall.buzz(0)
	OS.delay_msec(80)
	wall.buzz(0)
	_expect(wall_buzzes[0] == 2, "haptics: with no clock the rules run on the wall clock: 80 ms later a second buzz is past a 30 ms gap")
	_expect(absi(wall.now_ms() - Time.get_ticks_msec()) < 1000, "haptics: now_ms() is the wall clock when there is no clock")

	# Where it is supported: only on a phone, or a browser that has navigator.vibrate (a test run is neither).
	h = Haptics.new()
	_expect(h.supported() == (OS.has_feature("android") or OS.has_feature("ios")), "haptics: a desktop run has no motor")
	h._supported = 1   # pretend the first answer had been yes: asking again would say no
	_expect(h.supported(), "haptics: supported() is asked once and remembered")
	_expect(Haptics.WEB_HAPTICS_PROBE.contains("navigator.vibrate") and Haptics.WEB_HAPTICS_PROBE.contains("maxTouchPoints"), "haptics: the web check wants a touch screen as well as navigator.vibrate (a desktop Chromium has the function too)")


## Hit stops on an injected clock: the rules (cooldown, force, lengthen-never-shorten, reset, leaving the tree) and nothing else.
func _test_time_control() -> void:
	var now: Array[int] = [1000]
	var stop := TimeControl.new()
	stop.clock = func() -> int: return now[0]
	stop.hit_stop_scale = 0.2   # not the default, so the test sees the setting used
	root.add_child(stop)
	stop.hit_stop(0.1)
	_expect(is_equal_approx(Engine.time_scale, 0.2), "a hit stop slows the game to hit_stop_scale")
	now[0] = 1050
	await _frames(1)
	_expect(Engine.time_scale < 1.0, "it lasts until its time has run out")
	now[0] = 1110
	await _frames(1)
	_expect(is_equal_approx(Engine.time_scale, 1.0), "and ends by itself")
	now[0] = 1200
	stop.hit_stop(0.1)
	_expect(is_equal_approx(Engine.time_scale, 1.0), "a request inside the cooldown after a stop is ignored")
	now[0] = 1400
	stop.hit_stop(0.1)
	_expect(Engine.time_scale < 1.0, "after the cooldown it works again (it ends at 1500)")
	stop.hit_stop(0.05, true)
	now[0] = 1480
	await _frames(1)
	_expect(Engine.time_scale < 1.0, "a forced shorter stop does not cut the running one short")
	stop.hit_stop(0.3, true)
	now[0] = 1600
	await _frames(1)
	_expect(Engine.time_scale < 1.0, "a forced longer stop lengthens it (to 1780)")
	now[0] = 1800
	await _frames(1)
	_expect(is_equal_approx(Engine.time_scale, 1.0), "and then it ends")
	stop.hit_stop(10.0, true)
	stop.reset()
	_expect(is_equal_approx(Engine.time_scale, 1.0), "reset puts the speed back at once")
	stop.hit_stop(0.1)
	_expect(Engine.time_scale < 1.0, "and forgets the cooldown")
	stop.free()
	_expect(is_equal_approx(Engine.time_scale, 1.0), "leaving the tree never leaves the game slowed")
	Engine.time_scale = 1.0


func _tone() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050)   # half a second of 16-bit mono silence
	wav.data = data
	return wav


## Crossfading music with a 0.05 s fade. In headless the dummy audio driver still reports `playing`.
func _test_music() -> void:
	var music := Music.new()
	music.fade_time = 0.05
	root.add_child(music)
	_expect(music.get_child_count() == 2, "the music node adds the two players it needs")
	var first: AudioStreamWAV = _tone()
	var second: AudioStreamWAV = _tone()
	var playing := func() -> Array: return music.get_children().filter(func(player: Node) -> bool: return (player as AudioStreamPlayer).playing)
	music.play(first)
	_expect(playing.call().size() == 1 and playing.call()[0].stream == first and music.track == first, "play starts the track on one player")
	_expect(first.loop_mode == AudioStreamWAV.LOOP_FORWARD and first.loop_end > 0, "and switches looping on")
	music.play(first)
	_expect(playing.call().size() == 1, "the same track again changes nothing")
	music.play(second)
	_expect(playing.call().size() == 2, "a different track starts on the other player while the old one fades")
	await create_timer(0.3).timeout
	_expect(playing.call().size() == 1 and playing.call()[0].stream == second and music.track == second, "the old track stops when its fade is done")
	_expect(is_equal_approx(playing.call()[0].volume_db, music.volume_db), "the new track ends at full level (volume_db)")
	music.stop()
	await create_timer(0.3).timeout
	_expect(playing.call().is_empty() and music.track == null, "stop fades everything to silence")
	music.free()



## Trauma shake, stepped by hand (`step(delta)`) so the numbers do not depend on the frame rate.
func _test_camera_shake() -> void:
	var camera := Camera2D.new()
	root.add_child(camera)
	var shake := CameraShake.new()
	shake.camera = camera
	shake.add_trauma(0.5)
	_expect(is_equal_approx(shake.trauma, 0.5), "a hit adds its trauma")
	shake.add_trauma(0.8)
	_expect(is_equal_approx(shake.trauma, 1.0), "trauma stops at 1")
	shake.trauma = 0.0
	shake.add_trauma(0.5, 0.6)
	shake.add_trauma(0.5, 0.6)
	_expect(is_equal_approx(shake.trauma, 0.6), "a shake never pushes trauma past its own ceiling")
	shake.add_trauma(0.3, 0.2)
	_expect(is_equal_approx(shake.trauma, 0.6), "and never lowers trauma that is already above it")
	shake.step(0.1)
	_expect(is_equal_approx(shake.trauma, 0.6 - shake.decay * 0.1), "trauma drains by `decay` per second")
	# The camera moves by trauma squared: never beyond that, and it does get there.
	shake.decay = 0.0
	shake.trauma = 0.5
	var bound: Vector2 = shake.max_offset * 0.25
	var reach: float = 0.0
	var most: float = 0.0
	var largest_step: float = 0.0
	var last: float = 0.0
	for tick: int in 480:   # two seconds at 240 Hz
		shake.step(1.0 / 240.0)
		most = maxf(most, maxf(absf(camera.offset.x) - bound.x, maxf(absf(camera.offset.y) - bound.y, absf(camera.rotation) - shake.max_roll * 0.25)))
		reach = maxf(reach, absf(camera.offset.x))
		largest_step = maxf(largest_step, absf(camera.offset.x - last))
		last = camera.offset.x
	_expect(most <= 0.0001, "the camera never moves beyond max_offset and max_roll times trauma squared (over by %f)" % most)
	_expect(reach > bound.x * 0.5, "and it does move (reached %f of %f px)" % [reach, bound.x])
	_expect(largest_step < bound.x * 0.3, "the motion is smooth, not a new random value every frame (largest step %f px)" % largest_step)
	shake.decay = 1.5
	shake.step(10.0)
	_expect(is_zero_approx(shake.trauma) and camera.offset == Vector2.ZERO and camera.rotation == 0.0, "when trauma runs out the camera is put back at exactly zero")
	shake.camera = null
	shake.trauma = 0.5
	shake.step(0.05)
	_expect(shake.trauma < 0.5, "without a camera, trauma still drains and nothing breaks")
	shake.camera = camera
	camera.offset = Vector2.ZERO
	shake.shake_scale = 0.0
	shake.trauma = 0.0
	shake.add_trauma(0.8)
	_expect(is_zero_approx(shake.trauma), "with shake_scale 0 no trauma is collected")
	shake.trauma = 0.7
	shake.step(0.05)
	_expect(is_zero_approx(shake.trauma) and camera.offset == Vector2.ZERO, "and trauma that was already there is dropped without moving the camera")
	camera.free()


## The floating stick on a 480x360 area: it appears under the finger, steers by the finger's travel, and hides on release.
func _test_floating_stick() -> void:
	root.size = Vector2i(480, 360)  # headless windows start at 64x64
	var stick := Control.new()
	stick.set_script(FloatingStick)
	stick.size = Vector2(480, 360)
	var base := Panel.new()
	base.name = "Base"
	base.size = Vector2(160, 160)
	var knob := Panel.new()
	knob.name = "Knob"
	knob.size = Vector2(60, 60)
	stick.add_child(base)
	base.add_child(knob)
	base.owner = stick
	knob.owner = stick
	base.unique_name_in_owner = true
	knob.unique_name_in_owner = true
	root.add_child(stick)
	await _frames(2)
	_expect(not base.visible and stick.vector == Vector2.ZERO, "the stick is hidden and idle until a finger presses")
	_move(Vector2(300, 100))
	await _frames(1)
	_expect(stick.vector == Vector2.ZERO and not base.visible, "a drag that began elsewhere does not steer")
	_mouse(Vector2(200, 180), true)
	await _frames(1)
	_expect(base.visible and base.position.is_equal_approx(Vector2(200, 180) - base.size * 0.5), "the base appears under the finger")
	_expect(stick.vector == Vector2.ZERO, "pressing alone does not steer")
	_move(Vector2(200.0 + stick.radius * 0.5, 180))
	await _frames(1)
	_expect(is_equal_approx(stick.vector.x, 0.5) and is_zero_approx(stick.vector.y), "half the radius to the right steers half to the right (%s)" % stick.vector)
	_move(Vector2(200.0 + stick.radius * 0.05, 180))
	await _frames(1)
	_expect(stick.vector == Vector2.ZERO, "a tiny movement inside the dead zone does not steer")
	_move(Vector2(200, 180.0 + stick.radius * 3.0))
	await _frames(1)
	_expect(is_equal_approx(stick.vector.length(), 1.0) and stick.vector.y > 0.99, "far past the radius is full deflection, and y points down (%s)" % stick.vector)
	_expect(is_equal_approx(knob.position.y + knob.size.y * 0.5 - base.size.y * 0.5, stick.knob_travel), "the knob is drawn at most knob_travel from the middle of the base")
	_mouse(Vector2(200, 180.0 + stick.radius * 3.0), false)
	await _frames(1)
	_expect(not base.visible and stick.vector == Vector2.ZERO, "letting go hides the base and stops steering")
	_expect(knob.position.is_equal_approx(base.size * 0.5 - knob.size * 0.5), "and the knob goes back to the middle of the base")
	_move(Vector2(260, 180))
	await _frames(1)
	_expect(stick.vector == Vector2.ZERO, "moving the mouse afterwards does not steer")
	_mouse(Vector2(100, 100), true)
	_move(Vector2(220, 100))
	await _frames(1)
	_expect(stick.vector.x > 0.9, "a second press steers again")
	stick.release()
	_expect(not base.visible and stick.vector == Vector2.ZERO, "release() ends a touch that never got its mouse-up")
	stick.queue_free()
	await _frames(1)


## The loading logic on a tiny scene saved under user://, stepped by hand with a fixed delta so the clock rules are exact.
## The broken scene is random bytes named .scn: the engine logs "Unrecognized binary resource file" for it. A text scene that is
## malformed logs "Parse Error", which the kit's log check treats as a failure, so it is not used here.
func _test_scene_loader() -> void:
	var dir: String = DIR + "/loader"
	DirAccess.make_dir_recursive_absolute(dir)
	var node := Node2D.new()
	node.name = "Loaded"
	var packed := PackedScene.new()
	packed.pack(node)
	node.free()
	var good: String = dir + "/good.tscn"
	ResourceSaver.save(packed, good)
	var broken: String = dir + "/broken.scn"
	var broken_file: FileAccess = FileAccess.open(broken, FileAccess.WRITE)
	broken_file.store_buffer(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]))   # not a binary scene
	broken_file.close()

	var loader := SceneLoader.new()
	loader.min_show_time = 1.0
	loader.hold_at_full = 0.2
	_expect(not loader.request(dir + "/missing.tscn") and loader.failed, "a scene that does not exist fails at once")
	_expect(loader.step(0.1) == null, "and step hands nothing over")
	_expect(loader.request(good) and not loader.failed and is_zero_approx(loader.shown), "a good scene starts: not failed, bar at 0")
	# The scene loads within a few frames, but the clock holds the bar: nothing is handed over before min_show_time.
	var handed: PackedScene = null
	var previous: float = 0.0
	var backwards: bool = false
	var ahead: bool = false
	var elapsed: float = 0.0
	var handed_at: float = -1.0
	for tick: int in 400:
		await _frames(1)
		handed = loader.step(1.0 / 60.0)
		elapsed += 1.0 / 60.0
		backwards = backwards or loader.shown < previous
		ahead = ahead or loader.shown > minf(1.0, elapsed / loader.min_show_time) + 0.0001
		previous = loader.shown
		if handed != null:
			handed_at = elapsed
			break
	_expect(handed != null, "the loaded scene is handed over")
	_expect(not backwards, "the bar never goes backwards")
	_expect(not ahead, "and never gets ahead of the clock (min_show_time)")
	_expect(handed_at >= loader.min_show_time + loader.hold_at_full - 0.05, "the hand-over waits for min_show_time and the hold (at %.2f s)" % handed_at)
	var instance: Node = handed.instantiate() if handed != null else null
	_expect(instance != null and instance.name == "Loaded", "what it hands over is the scene")
	if instance != null:
		instance.free()
	_expect(is_equal_approx(loader.shown, 1.0) and not loader.failed, "the bar ends full and not failed")
	_expect(loader.step(0.1) == null, "after the hand-over step returns nothing more")

	_expect(loader.request(broken), "a scene that exists but is broken starts loading")
	var failed_after: int = -1
	for tick: int in 400:
		await _frames(1)
		loader.step(1.0 / 60.0)
		if loader.failed:
			failed_after = tick
			break
	_expect(failed_after >= 0, "and fails instead of hanging (after %d frames)" % failed_after)
	_expect(loader.step(0.1) == null and loader.failed, "a failed load stays failed and hands nothing over")
	_expect(loader.request(good) and not loader.failed, "a retry clears the failure and loads again")
	for tick: int in 400:
		await _frames(1)
		handed = loader.step(1.0 / 60.0)
		if handed != null:
			break
	_expect(handed != null and not loader.failed, "and a retried good scene arrives")

	# The bar moves at most fill_speed of its length per second, however fast the load and the clock allow.
	loader.min_show_time = 0.1
	loader.fill_speed = 0.5
	loader.request(good)
	elapsed = 0.0
	handed_at = -1.0
	for tick: int in 600:
		await _frames(1)
		handed = loader.step(1.0 / 60.0)
		elapsed += 1.0 / 60.0
		if handed != null:
			handed_at = elapsed
			break
	_expect(handed_at >= 1.0 / loader.fill_speed - 0.05, "the bar is limited to fill_speed per second (handed over at %.2f s, a full bar takes 2 s)" % handed_at)
	loader.fill_speed = 2.5
	loader.min_show_time = 1.0

	_expect(loader.request(good), "a request that is cancelled before it is collected")
	loader.cancel()
	var after_cancel: bool = false
	for tick: int in 300:
		await _frames(1)
		after_cancel = after_cancel or loader.step(1.0 / 60.0) != null
	_expect(not after_cancel and not loader.failed, "hands nothing over afterwards and is not a failure")
	_expect(loader.request(good), "and a new request afterwards works")
	loader.cancel()
	loader.request(good)
	await _frames(5)
	loader.fail()
	_expect(loader.failed and loader.step(0.1) == null, "fail() marks a scene the game could not use as failed")
	loader.cancel()
	_remove_tree(dir)


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


## Godot's built-in fallback font has Latin letters (é) and no CJK: a fixture for "which characters has the font not got".
func _test_font_check() -> void:
	var root: String = DIR + "/font_check"
	var files: Dictionary = {
		"game/a.gd": 'var s = "é安"',
		"data/story.json": '{"line": "龍A"}',
		"ui/t.tres": 'text = "安"',
		"tests/skip.gd": 'var s = "蔣"',
		"addons/kit/skip.gd": 'var s = "鑿"',
		".godot/skip.gd": 'var s = "驫"',
		"notes.md": "鬱",
	}
	for relative: String in files:
		DirAccess.make_dir_recursive_absolute(root.path_join(relative).get_base_dir())
		var file: FileAccess = FileAccess.open(root.path_join(relative), FileAccess.WRITE)
		file.store_string(files[relative])
		file.close()
	var font: Font = ThemeDB.fallback_font
	var scanned: Dictionary = FontCheck.scanned_characters(root)
	_expect(scanned.keys().size() == 3 and scanned.has("é") and scanned.has("安") and scanned.has("龍"), "font_check scans scripts, scenes and data files (found %s)" % [scanned.keys()])
	_expect(String(scanned.get("龍", "")).ends_with("story.json"), "font_check says which file wrote a character")
	_expect(not scanned.has("蔣") and not scanned.has("鑿") and not scanned.has("驫") and not scanned.has("鬱"), "tests, addons, hidden folders and .md files are not scanned")
	_expect(FontCheck.missing_characters(font, root) == "安龍", "missing_characters names what the font lacks, sorted (the fallback font has é)")
	_expect(FontCheck.missing_report(font, root).keys().size() == 2, "missing_report gives one entry per missing character")
	_expect(FontCheck.missing_characters(font, root, PackedStringArray(["gd"])) == "安", "extensions narrows the scan")
	_expect(FontCheck.missing_characters(font, root, FontCheck.EXTENSIONS, PackedStringArray(["data"])) == "安蔣鑿", "skip_dirs replaces the default list: data/ is skipped, tests/ and addons/ now are scanned (hidden folders never are)")
	for relative: String in files:
		DirAccess.remove_absolute(root.path_join(relative))
	for folder: String in ["game", "data", "ui", "tests", "addons/kit", "addons", ".godot"]:
		DirAccess.remove_absolute(root.path_join(folder))
	DirAccess.remove_absolute(root)


## sfx_bank.gd: the lookup order, the voices, min_gap and the long-sound rules. Sound files go under user://.
func _test_sfx_bank() -> void:
	var dir: String = DIR + "/sfx"
	_remove_tree(dir)
	DirAccess.make_dir_recursive_absolute(dir)

	# Lookup: a file named like the event, else its placeholder, else the event it borrows from, else silence.
	var bank: Node = SfxBank.new()
	bank.sound_dir = dir
	bank.voices = 3
	for event: StringName in [&"has_file", &"has_both", &"from_synth", &"own_and_borrow"]:
		bank._streams[event] = _silence(0.02)
	bank.fallback[&"borrows_synth"] = &"from_synth"
	bank.fallback[&"borrows_file"] = &"file_only"
	bank.fallback[&"own_and_borrow"] = &"from_synth"
	bank.fallback[&"borrows_nothing"] = &"nothing"
	root.add_child(bank)
	_expect(bank._players.size() == 3 and bank.get_child_count() == 3, "sfx_bank builds `voices` players")
	for stem: String in ["has_file", "file_only", "has_both"]:
		_expect(_silence(0.02).save_to_wav("%s/%s.wav" % [dir, stem]) == OK, "sfx_bank test file %s.wav is written" % stem)
	var ogg: FileAccess = FileAccess.open(dir + "/has_both.ogg", FileAccess.WRITE)
	ogg.store_buffer(Marshalls.base64_to_raw(SILENT_OGG.replace("\n", "")))
	ogg.close()
	_expect(bank.source_of(&"has_file") == dir + "/has_file.wav" and bank.stream_for(&"has_file") is AudioStreamWAV and bank.stream_for(&"has_file") != bank._streams[&"has_file"],
		"sfx_bank: a file named like the event beats its placeholder (%s)" % [bank.source_of(&"has_file")])
	_expect(bank.source_of(&"has_both") == dir + "/has_both.ogg" and bank.stream_for(&"has_both") is AudioStreamOggVorbis,
		"sfx_bank: <event>.ogg beats <event>.wav (%s)" % [bank.source_of(&"has_both")])
	_expect(bank.source_of(&"from_synth") == "synth" and bank.stream_for(&"from_synth") == bank._streams[&"from_synth"],
		"sfx_bank: without a file the placeholder plays (%s)" % [bank.source_of(&"from_synth")])
	_expect(bank.source_of(&"own_and_borrow") == "synth", "sfx_bank: a placeholder of its own beats borrowing (%s)" % [bank.source_of(&"own_and_borrow")])
	_expect(bank.source_of(&"borrows_synth") == "from_synth (borrowed)" and bank.stream_for(&"borrows_synth") == bank.stream_for(&"from_synth"),
		"sfx_bank: with neither, an event borrows the other event's placeholder (%s)" % [bank.source_of(&"borrows_synth")])
	_expect(bank.source_of(&"borrows_file") == "file_only (borrowed)" and bank.stream_for(&"borrows_file") is AudioStreamWAV,
		"sfx_bank: ...or the other event's file (%s)" % [bank.source_of(&"borrows_file")])

	# Silence is never an error: no stream and no source, no voice taken, `played` still emitted, with or without voices.
	var mute: Node = SfxBank.new()
	mute.voices = 0
	mute._streams[&"a"] = _silence(0.02)
	root.add_child(mute)
	var heard: Array[StringName] = []
	var mute_heard: Array[StringName] = []
	bank.played.connect(func(sound: StringName) -> void: heard.append(sound))
	mute.played.connect(func(sound: StringName) -> void: mute_heard.append(sound))
	var errors := ErrorLog.new()
	OS.add_logger(errors)
	var nothing_stream: AudioStream = bank.stream_for(&"nothing")
	var borrowed_nothing_stream: AudioStream = bank.stream_for(&"borrows_nothing")
	bank.play(&"nothing")
	bank.play(&"borrows_nothing")
	mute.play(&"a")
	OS.remove_logger(errors)
	_expect(nothing_stream == null and bank.source_of(&"nothing") == "", "sfx_bank: an event nobody has a sound for is silent")
	_expect(borrowed_nothing_stream == null and bank.source_of(&"borrows_nothing") == "", "sfx_bank: borrowing from an event with no sound is silent too (%s)" % [bank.source_of(&"borrows_nothing")])
	_expect(errors.messages.is_empty(), "sfx_bank: playing a silent event, or playing without voices, raises no error (%s)" % [errors.messages])
	_expect(heard == [&"nothing", &"borrows_nothing"] and mute_heard == [&"a"], "sfx_bank: played is emitted for a silent event and without voices (%s, %s)" % [heard, mute_heard])
	_expect(bank._event_of.is_empty(), "sfx_bank: a silent event takes no voice")

	# Lookups are cached until refresh().
	_expect(bank.source_of(&"late") == "", "sfx_bank: no file for `late` yet")
	_expect(_silence(0.02).save_to_wav(dir + "/late.wav") == OK, "sfx_bank test file late.wav is written")
	_expect(bank.source_of(&"late") == "", "sfx_bank: a file that turns up later is not seen before refresh() (lookups are cached)")
	bank.refresh()
	_expect(bank.source_of(&"late") == dir + "/late.wav", "sfx_bank: refresh() finds the new file (%s)" % [bank.source_of(&"late")])
	DirAccess.remove_absolute(dir + "/late.wav")
	bank.refresh()
	_expect(bank.source_of(&"late") == "", "sfx_bank: refresh() also notices a file that is gone")

	# Voices are used round-robin; the same event inside min_gap is dropped; played is emitted either way.
	var rotor: Node = SfxBank.new()
	rotor.voices = 3
	for event: StringName in [&"a", &"b", &"c"]:
		rotor._streams[event] = _silence(3.0)
	root.add_child(rotor)
	var rotor_voices: Array = rotor._players
	var rotor_heard: Array[StringName] = []
	rotor.played.connect(func(sound: StringName) -> void: rotor_heard.append(sound))
	rotor.play(&"a", 0.0)
	rotor.play(&"b", 0.0)
	_expect(rotor._event_of.get(rotor_voices[0]) == &"a" and rotor._event_of.get(rotor_voices[1]) == &"b" and rotor_voices[0].playing and rotor_voices[1].playing,
		"sfx_bank: two events sound on two different voices")
	var last_a: int = rotor._last_ms[&"a"]
	OS.delay_msec(5)   # the clock counts milliseconds: give a call that wrongly moves the gap time to show
	rotor.play(&"a", 10.0)
	_expect(rotor._next == 2 and not rotor._event_of.has(rotor_voices[2]), "sfx_bank: the same event again inside min_gap is dropped (next voice %d)" % rotor._next)
	_expect(rotor._last_ms[&"a"] == last_a, "sfx_bank: a dropped call does not extend the gap")
	rotor.play(&"a", 0.0)
	_expect(rotor._event_of.get(rotor_voices[2]) == &"a", "sfx_bank: min_gap 0 never drops a call")
	rotor.play(&"c", 0.0)
	_expect(rotor._event_of.get(rotor_voices[0]) == &"c" and rotor._next == 1, "sfx_bank: after the last voice the first is used again (next voice %d)" % rotor._next)
	_expect(rotor_heard == [&"a", &"b", &"a", &"a", &"c"], "sfx_bank: played is emitted for every call, the dropped one too (%s)" % [rotor_heard])

	# Long sounds are cut after `seconds`, play at their own gain, never stack, and the voice they sound on
	# is not stopped later by a cut that belongs to the sound it used to carry.
	var longs: Node = SfxBank.new()
	longs.voices = 3
	for event: StringName in [&"long", &"blip", &"steady"]:
		longs._streams[event] = _silence(3.0)
	longs.long_sounds = {&"long": {"seconds": 0.2, "gain_db": -4.0}, &"blip": {"seconds": 0.05, "gain_db": 0.0}}
	root.add_child(longs)
	var long_voice: AudioStreamPlayer = longs._players[longs._next]
	longs.play(&"long", 0.0)
	_expect(long_voice.playing and longs._event_of.get(long_voice) == &"long", "sfx_bank: a long sound starts on the next voice")
	_expect(is_equal_approx(long_voice.volume_db, longs.volume_db - 4.0), "sfx_bank: a long sound plays at its own gain_db (%.1f dB)" % long_voice.volume_db)
	_expect(longs._cut.has(long_voice) and longs._cut[long_voice].is_valid(), "sfx_bank: a long sound gets a pending cut")
	longs.play(&"long", 0.0)
	_expect(_voices_sounding(longs, &"long") == 1 and longs._next == 1, "sfx_bank: the same long event is skipped while it sounds (%d voices, next voice %d)" % [_voices_sounding(longs, &"long"), longs._next])
	for i: int in longs.voices:   # the third one takes over the voice that carries the long sound
		longs.play(&"steady", 0.0)
	_expect(longs._event_of.get(long_voice) == &"steady" and not longs._cut.has(long_voice), "sfx_bank: a voice taken over from a long sound drops its pending cut")
	await create_timer(0.5).timeout
	_expect(long_voice.playing and is_equal_approx(long_voice.volume_db, longs.volume_db),
		"sfx_bank: ...so that cut cannot stop or fade the sound now on it (playing %s, %.1f dB)" % [long_voice.playing, long_voice.volume_db])
	var cut_voice: AudioStreamPlayer = longs._players[longs._next]
	var blip_voice: AudioStreamPlayer = longs._players[(longs._next + 1) % longs.voices]
	longs.play(&"long", 0.0)
	longs.play(&"blip", 0.0)   # its `seconds` are shorter than the fade-out
	_expect(cut_voice.playing and blip_voice.playing and longs._event_of.get(cut_voice) == &"long" and longs._event_of.get(blip_voice) == &"blip",
		"sfx_bank: different long events may sound together")
	await create_timer(0.6).timeout
	_expect(not cut_voice.playing and not blip_voice.playing, "sfx_bank: a long sound is cut after its `seconds`, though its stream runs 3 s (long %s, blip %s)" % [cut_voice.playing, blip_voice.playing])
	longs.play(&"long", 0.0)
	_expect(_voices_sounding(longs, &"long") == 1, "sfx_bank: a long event can play again once its last sound has been cut")
	for i: int in longs.voices:   # every voice, including the one that just faded a long sound out
		longs.play(&"steady", 0.0)
	var wrong_volume: int = 0
	for player: AudioStreamPlayer in longs._players:
		if not is_equal_approx(player.volume_db, longs.volume_db):
			wrong_volume += 1
	_expect(wrong_volume == 0, "sfx_bank: a voice that faded a long sound out is back at full volume for the next sound (%d not)" % wrong_volume)

	# How a game uses it (the example in the module's header): a subclass fills the tables, then calls super().
	var game: Node = GameSfx.new()
	root.add_child(game)
	_expect(game._players.size() == 10, "sfx_bank: super() in a subclass builds the voices (%d)" % game._players.size())
	_expect(game.sound_dir == "res://assets/sfx" and game.voices == 10 and is_equal_approx(game.volume_db, -6.0),
		"sfx_bank: the defaults are res://assets/sfx, 10 voices and -6 dB (%s, %d, %.1f)" % [game.sound_dir, game.voices, game.volume_db])
	_expect(game.source_of(&"hit") == "synth" and game.source_of(&"enemy_die") == "boom (borrowed)", "sfx_bank: a subclass's placeholders and borrowing tables are used (%s, %s)" % [game.source_of(&"hit"), game.source_of(&"enemy_die")])
	var boom_voice: AudioStreamPlayer = game._players[game._next]
	game.play(&"boom", 0.0)
	_expect(is_equal_approx(boom_voice.volume_db, game.volume_db - 3.0) and game._cut.has(boom_voice), "sfx_bank: a subclass's long_sounds table is used (%.1f dB)" % boom_voice.volume_db)

	for node: Node in [bank, mute, rotor, longs, game]:
		node.free()
	_remove_tree(dir)
	_expect(not DirAccess.dir_exists_absolute(dir), "sfx_bank: the test folder is removed")


## `seconds` of 16-bit mono silence: a stream to play, to save as a .wav, or to tell apart from another by identity.
func _silence(seconds: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(int(Synth.RATE * seconds) * 2)
	return Synth.to_stream(data)


func _voices_sounding(sfx: Node, event: StringName) -> int:
	var count: int = 0
	for player: AudioStreamPlayer in sfx._players:
		if player.playing and sfx._event_of.get(player) == event:
			count += 1
	return count


## A game's sound table, as in the header of sfx_bank.gd: fill the three tables, then call super().
class GameSfx extends SfxBank:
	func _ready() -> void:
		_streams = {&"hit": Synth.click(0.02), &"boom": Synth.click(0.02)}
		fallback = {&"enemy_die": &"boom"}
		long_sounds = {&"boom": {"seconds": 0.5, "gain_db": -3.0}}
		super()


func _cleanup() -> void:
	for path: String in [DIR + "/nested/save.json", DIR + "/slot.save", DIR + "/reference.save"]:
		for suffix: String in ["", ".tmp", ".old"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)


## A 20 ms silent mono Vorbis stream (2.7 KB, base64). GDScript can write a .wav but cannot encode an .ogg,
## and the .ogg-before-.wav rule and the straight-from-disk .ogg read need a real one.
const SILENT_OGG: String = """
T2dnUwACAAAAAAAAAABc2TN+AAAAADhpCV0BHgF2b3JiaXMAAAAAAUAfAAAAAAAAcGIAAAAAAACZAU9nZ1MAAAAAAAAAAAAAXNkzfgEAAADz0o1CC1r/////
//////+1A3ZvcmJpczQAAABYaXBoLk9yZyBsaWJWb3JiaXMgSSAyMDIwMDcwNCAoUmVkdWNpbmcgRW52aXJvbm1lbnQpAQAAABIAAABFTkNPREVSPWxpYnNu
ZGZpbGUBBXZvcmJpcxJCQ1YBAAABAAxSFCElGVNKYwiVUlIpBR1jUFtHHWPUOUYhZBBTiEkZpXtPKpVYSsgRUlgpRR1TTFNJlVKWKUUdYxRTSCFT1jFloXMU
S4ZJCSVsTa50FkvomWOWMUYdY85aSp1j1jFFHWNSUkmhcxg6ZiVkFDpGxehifDA6laJCKL7H3lLpLYWKW4q91xpT6y2EGEtpwQhhc+211dxKasUYY4wxxsXi
UyiC0JBVAAABAABABAFCQ1YBAAoAAMJQDEVRgNCQVQBABgCAABRFcRTHcRxHkiTLAkJDVgEAQAAAAgAAKI7hKJIjSZJkWZZlWZameZaouaov+64u667t6roO
hIasBADIAAAYhiGH3knMkFOQSSYpVcw5CKH1DjnlFGTSUsaYYoxRzpBTDDEFMYbQKYUQ1E45pQwiCENInWTOIEs96OBi5zgQGrIiAIgCAACMQYwhxpBzDEoG
IXKOScggRM45KZ2UTEoorbSWSQktldYi55yUTkompbQWUsuklNZCKwUAAAQ4AAAEWAiFhqwIAKIAABCDkFJIKcSUYk4xh5RSjinHkFLMOcWYcowx6CBUzDHI
HIRIKcUYc0455iBkDCrmHIQMMgEAAAEOAAABFkKhISsCgDgBAIMkaZqlaaJoaZooeqaoqqIoqqrleabpmaaqeqKpqqaquq6pqq5seZ5peqaoqp4pqqqpqq5r
qqrriqpqy6ar2rbpqrbsyrJuu7Ks256qyrapurJuqq5tu7Js664s27rkearqmabreqbpuqrr2rLqurLtmabriqor26bryrLryratyrKua6bpuqKr2q6purLt
yq5tu7Ks+6br6rbqyrquyrLu27au+7KtC7vourauyq6uq7Ks67It67Zs20LJ81TVM03X9UzTdVXXtW3VdW1bM03XNV1XlkXVdWXVlXVddWVb90zTdU1XlWXT
VWVZlWXddmVXl0XXtW1Vln1ddWVfl23d92VZ133TdXVblWXbV2VZ92Vd94VZt33dU1VbN11X103X1X1b131htm3fF11X11XZ1oVVlnXf1n1lmHWdMLqurqu2
7OuqLOu+ruvGMOu6MKy6bfyurQvDq+vGseu+rty+j2rbvvDqtjG8um4cu7Abv+37xrGpqm2brqvrpivrumzrvm/runGMrqvrqiz7uurKvm/ruvDrvi8Mo+vq
uirLurDasq/Lui4Mu64bw2rbwu7aunDMsi4Mt+8rx68LQ9W2heHVdaOr28ZvC8PSN3a+AACAAQcAgAATykChISsCgDgBAAYhCBVjECrGIIQQUgohpFQxBiFj
DkrGHJQQSkkhlNIqxiBkjknIHJMQSmiplNBKKKWlUEpLoZTWUmotptRaDKG0FEpprZTSWmopttRSbBVjEDLnpGSOSSiltFZKaSlzTErGoKQOQiqlpNJKSa1l
zknJoKPSOUippNJSSam1UEproZTWSkqxpdJKba3FGkppLaTSWkmptdRSba21WiPGIGSMQcmck1JKSamU0lrmnJQOOiqZg5JKKamVklKsmJPSQSglg4xKSaW1
kkoroZTWSkqxhVJaa63VmFJLNZSSWkmpxVBKa621GlMrNYVQUgultBZKaa21VmtqLbZQQmuhpBZLKjG1FmNtrcUYSmmtpBJbKanFFluNrbVYU0s1lpJibK3V
2EotOdZaa0ot1tJSjK21mFtMucVYaw0ltBZKaa2U0lpKrcXWWq2hlNZKKrGVklpsrdXYWow1lNJiKSm1kEpsrbVYW2w1ppZibLHVWFKLMcZYc0u11ZRai621
WEsrNcYYa2415VIAAMCAAwBAgAlloNCQlQBAFAAAYAxjjEFoFHLMOSmNUs45JyVzDkIIKWXOQQghpc45CKW01DkHoZSUQikppRRbKCWl1losAACgwAEAIMAG
TYnFAQoNWQkARAEAIMYoxRiExiClGIPQGKMUYxAqpRhzDkKlFGPOQcgYc85BKRljzkEnJYQQQimlhBBCKKWUAgAAChwAAAJs0JRYHKDQkBUBQBQAAGAMYgwx
hiB0UjopEYRMSielkRJaCylllkqKJcbMWomtxNhICa2F1jJrJcbSYkatxFhiKgAA7MABAOzAQig0ZCUAkAcAQBijFGPOOWcQYsw5CCE0CDHmHIQQKsaccw5C
CBVjzjkHIYTOOecghBBC55xzEEIIoYMQQgillNJBCCGEUkrpIIQQQimldBBCCKGUUgoAACpwAAAIsFFkc4KRoEJDVgIAeQAAgDFKOSclpUYpxiCkFFujFGMQ
UmqtYgxCSq3FWDEGIaXWYuwgpNRajLV2EFJqLcZaQ0qtxVhrziGl1mKsNdfUWoy15tx7ai3GWnPOuQAA3AUHALADG0U2JxgJKjRkJQCQBwBAIKQUY4w5h5Ri
jDHnnENKMcaYc84pxhhzzjnnFGOMOeecc4wx55xzzjnGmHPOOeecc84556CDkDnnnHPQQeicc845CCF0zjnnHIQQCgAAKnAAAAiwUWRzgpGgQkNWAgDhAACA
MZRSSimllFJKqKOUUkoppZRSAiGllFJKKaWUUkoppZRSSimllFJKKaWUUkoppZRSSimllFJKKaWUUkoppZRSSimllFJKKaWUUkoppZRSSimllFJKKaWUUkop
pZRSSimllFJKKaWUUkoppZRSSimllFJKKaWUUkoppZRSSimVUkoppZRSSimllFJKKaUAIN8KBwD/BxtnWEk6KxwNLjRkJQAQDgAAGMMYhIw5JyWlhjEIpXRO
SkklNYxBKKVzElJKKYPQWmqlpNJSShmElGILIZWUWgqltFZrKam1lFIoKcUaS0qppdYy5ySkklpLrbaYOQelpNZaaq3FEEJKsbXWUmuxdVJSSa211lptLaSU
WmstxtZibCWlllprqcXWWkyptRZbSy3G1mJLrcXYYosxxhoLAOBucACASLBxhpWks8LR4EJDVgIAIQEABDJKOeecgxBCCCFSijHnoIMQQgghREox5pyDEEII
IYSMMecghBBCCKGUkDHmHIQQQgghhFI65yCEUEoJpZRSSucchBBCCKWUUkoJIYQQQiillFJKKSGEEEoppZRSSiklhBBCKKWUUkoppYQQQiillFJKKaWUEEIo
pZRSSimllBJCCKGUUkoppZRSQgillFJKKaWUUkooIYRSSimllFJKCSWUUkoppZRSSikhlFJKKaWUUkoppQAAgAMHAIAAI+gko8oibDThwgMQAAAAAgACTACB
AYKCUQgChBEIAAAAAAAIAPgAAEgKgIiIaOYMDhASFBYYGhweICIkAAAAAAAAAAAAAAAABE9nZ1MABKAAAAAAAAAAXNkzfgIAAABPkcwMAgEBAAA=
"""
