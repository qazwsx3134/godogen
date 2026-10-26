extends "res://addons/proto_kit/test_kit.gd"

const GameClock = preload("res://addons/proto_kit/game_clock.gd")
const TapPicker3D = preload("res://addons/proto_kit/tap_picker_3d.gd")
const SaveSlots = preload("res://addons/proto_kit/save_slots.gd")
const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_clock()
	await _test_picker()
	_test_save()
	print("checks: ", checks)
	_finish("M0 MODULES TESTS")


func _test_clock() -> void:
	var clock: Node = GameClock.new()
	root.add_child(clock)
	await _frames(3)
	_expect(clock.now > 0.0, "clock advances while running")
	clock.set_away(true)
	_expect(paused, "going away pauses the tree")
	var at: float = clock.now
	await _frames(3)
	_expect(is_equal_approx(clock.now, at), "clock frozen while away")
	clock.set_away(false)
	_expect(paused, "still paused on the first frame back")
	await _frames(clock.resume_frames + 1)
	_expect(not paused, "unpaused after the resume frames")
	# a game that was already paused stays paused after coming back
	paused = true
	clock.set_away(true)
	clock.set_away(false)
	await _frames(clock.resume_frames + 1)
	_expect(paused, "keeps the game's own pause")
	paused = false
	clock.queue_free()


func _test_picker() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0, 10, 10)
	cam.look_at(Vector3.ZERO)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(shape)
	world.add_child(floor_body)
	var a := Node3D.new()
	var b := Node3D.new()
	world.add_child(a)
	world.add_child(b)
	a.position = Vector3(0, 0, 0)
	b.position = Vector3(3, 0, 0)
	var behind := Node3D.new()
	world.add_child(behind)
	behind.position = Vector3(0, 0, 30)
	await _frames(2)
	# headless root viewport is 64x64 px, so radii here are tiny
	var at_a: Vector2 = cam.unproject_position(a.global_position)
	_expect(TapPicker3D.pick_actor(cam, at_a + Vector2(2, 0), [a, b, behind], 5.0) == a, "nearest actor in radius")
	_expect(TapPicker3D.pick_actor(cam, at_a + Vector2(0, 30), [a, b], 5.0) == null, "nothing outside radius")
	_expect(TapPicker3D.pick_actor(cam, at_a, [behind], 5000.0) == null, "skips actors behind the camera")
	var aimed := TapPicker3D.pick_actor(cam, cam.unproject_position(Vector3(0, 2, 0)), [a, b], 3.0,
			func(n: Node3D) -> Vector3: return n.global_position + Vector3.UP * 2.0)
	_expect(aimed == a, "aim callable moves the measured point")
	var hit: Variant = TapPicker3D.ground(cam, cam.unproject_position(Vector3(2, 0, 1)))
	_expect(hit is Vector3 and hit.distance_to(Vector3(2, 0, 1)) < 0.01, "ground ray hits the floor point")
	world.queue_free()


func _test_save() -> void:
	var path := "user://test_m0/save.json"
	for f in [path, path + ".bak"]:
		DirAccess.remove_absolute(f)
	_expect(SaveSlots.restore(path, 1).error == "missing", "missing save")
	_expect(SaveSlots.save(path, {"level": 2}, 1) == OK, "first save")
	_expect(not FileAccess.file_exists(path + ".bak"), "no backup before a second save")
	SaveSlots.save(path, {"level": 3}, 1)
	var r: Dictionary = SaveSlots.restore(path, 1)
	_expect(r.source == "main" and int(r.data.level) == 3, "reads newest main")
	AtomicFile.write_text(path, "{broken")
	r = SaveSlots.restore(path, 1)
	_expect(r.source == "backup" and int(r.data.level) == 2, "corrupt main falls back to backup")
	SaveSlots.save(path, {"level": 4}, 1)
	r = SaveSlots.restore(path + ".bak", 1)
	_expect(int(r.data.level) == 2, "corrupt main never overwrites a good backup")
	_expect(SaveSlots.restore(path, 0).error == "newer", "refuses data from a newer build")
	var migrations := {1: func(d: Dictionary) -> Dictionary: d["gold"] = 0; return d}
	r = SaveSlots.restore(path, 2, migrations)
	_expect(r.error == "" and r.data.gold == 0 and int(r.data.level) == 4, "migrates one version up")
	_expect(SaveSlots.restore(path, 3, migrations).error == "migration", "missing migration step reported")
