extends "res://addons/proto_kit/test_kit.gd"
const Strip = preload("res://addons/proto_kit/vfx/sheet_frames.gd")
const BASE := "res://addons/proto_kit/vfx/"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_strip()
	await _test_playback("2d/sheet_effect.tscn")
	await _test_playback("3d/sheet_effect.tscn")
	await _test_native_3d()
	await _test_saved_previews()
	print("VFX checks: ", checks)
	_finish("VFX TESTS")

func _test_strip() -> void:
	var image := Image.create(24, 8, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(0, 0, 8, 8), Color.RED)
	image.fill_rect(Rect2i(8, 0, 8, 8), Color.GREEN)
	image.fill_rect(Rect2i(16, 0, 8, 8), Color.BLUE)
	var texture := ImageTexture.create_from_image(image)
	var frames := Strip.build(texture, 3, 18.0)
	_expect(frames.get_frame_count(&"default") == 3, "three frames, no extra empty default frame")
	_expect(frames.get_animation_speed(&"default") == 18.0, "preserves fps")
	_expect(not frames.get_animation_loop(&"default"), "one shot by default")
	for index: int in 3:
		var tile := frames.get_frame_texture(&"default", index) as AtlasTexture
		_expect(tile.region == Rect2(index * 8, 0, 8, 8), "frame rectangle %d" % index)
		_expect(tile.atlas == texture, "shares source texture %d" % index)
		_expect(tile.get_image().get_pixel(4, 4) == [Color.RED, Color.GREEN, Color.BLUE][index], "actual cropped pixel %d" % index)
	_expect(Strip.build(texture, 5, 18.0) == null, "rejects fractional cell width")
	_expect(Strip.build(texture, 0, 18.0) == null, "rejects zero frames")
	_expect(Strip.build(texture, 3, 0.0) == null, "rejects zero fps")
	_expect(Strip.build(texture, 3, NAN) == null, "rejects NaN fps")
	_expect(Strip.build(null, 3, 18.0) == null, "rejects missing texture")
	_expect(Strip.build(texture, 3, 18.0, true).get_animation_loop(&"default"), "explicit loop preserved")

func _test_playback(path: String) -> void:
	var scene := load(BASE + path) as PackedScene
	var fx: Node = scene.instantiate()
	# Retain authored resource while configuring an individual instance.
	var original: SpriteFrames = fx.sprite_frames
	var frames := original.duplicate() as SpriteFrames
	frames.set_animation_loop(&"default", false)
	frames.set_animation_speed(&"default", 600.0)
	fx.sprite_frames = frames
	var completed := [0]
	fx.finished.connect(func() -> void: completed[0] += 1)
	root.add_child(fx)
	_expect(fx.is_playing(), path + " autoplays")
	var weak: WeakRef = weakref(fx)
	await _until(func() -> bool: return weak.get_ref() == null, path + " frees when finished")
	_expect(completed[0] == 1, path + " signals completion exactly once")
	_expect(original.get_animation_loop(&"default"), path + " source resource stays looped")
	var loop: Node = scene.instantiate()
	loop.sprite_frames = original
	loop.speed_scale = 100.0
	root.add_child(loop)
	await _frames(5)
	_expect(is_instance_valid(loop) and loop.is_playing(), path + " looping effect persists")
	loop.free()
	var retained: Node = scene.instantiate()
	retained.sprite_frames = frames
	retained.free_on_finish = false
	root.add_child(retained)
	await _until(func() -> bool: return not retained.is_playing(), path + " retained one shot finishes")
	_expect(is_instance_valid(retained), path + " free_on_finish false preserves node")
	retained.free()
	var manual: Node = scene.instantiate()
	manual.play_on_ready = false
	root.add_child(manual)
	_expect(not manual.is_playing(), path + " manual playback supported")
	manual.free()

func _test_native_3d() -> void:
	var scene := load(BASE + "3d/pixel_burst.tscn") as PackedScene
	var a: Node3D = scene.instantiate()
	var b: Node3D = scene.instantiate()
	a.auto_step = false
	b.auto_step = false
	root.add_child(a)
	root.add_child(b)
	a.step(0.01)
	a.step(0.01)
	_expect(a.get_node("Chunks").multimesh != b.get_node("Chunks").multimesh, "instances own independent MultiMesh buffers")
	a.burst(Vector3(0, 1, 0), 8, &"gold")
	a.ring(Vector3.ZERO, 2.0, &"cyan", 0.5)
	a.step(0.05)
	_expect(a.get_node("Chunks").multimesh.visible_instance_count == 8, "native 3D burst renders eight chunks")
	_expect(a.get_node("Rings").get_child(0).visible, "native ring active")
	a.step(2.0)
	_expect(a.get_node("Chunks").multimesh.visible_instance_count == 0, "expired chunks released")
	_expect(not a.get_node("Rings").get_child(0).visible, "expired ring reusable")
	a.free()
	b.free()

func _test_saved_previews() -> void:
	for path: String in ["preview_2d.tscn", "preview_3d.tscn"]:
		var hash_before := FileAccess.get_sha256(BASE + path)
		var scene := load(BASE + path) as PackedScene
		var stage := scene.instantiate()
		_expect(stage.get_child_count() >= 5, path + " has authored layout")
		# A position edited before entering the tree survives _ready/process.
		var sheet: Node = stage.get_node("Sheet" if path.contains("2d") else "BillboardSheet")
		var expected: Variant = Vector2(400, 210) if sheet is Node2D else Vector3(3, 2, 0)
		sheet.position = expected
		var edited := PackedScene.new()
		_expect(edited.pack(stage) == OK, path + " packs editor adjustment")
		var temporary := "user://vfx-edited-" + path
		_expect(ResourceSaver.save(edited, temporary) == OK, path + " saves editor adjustment")
		stage.free()
		stage = (ResourceLoader.load(temporary, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
		sheet = stage.get_node("Sheet" if path.contains("2d") else "BillboardSheet")
		root.add_child(stage)
		await _frames(3)
		stage._replay()
		await _frames(3)
		_expect(sheet.position == expected, path + " preserves edited layout")
		stage.free()
		DirAccess.remove_absolute(temporary)
		_expect(FileAccess.get_sha256(BASE + path) == hash_before, path + " runtime never rewrites scene")
