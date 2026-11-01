extends "res://addons/proto_kit/test_kit.gd"
const Library = preload("res://addons/proto_kit/vfx/library.gd")
const BASE := "res://addons/proto_kit/vfx/"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(BASE + "assets/scenario/index.json"))
	_expect(entries.size() == 41, "all 41 provided Scenario packs indexed")
	for entry: Dictionary in entries:
		for dimension: String in ["2d", "3d"]:
			var scene: PackedScene = Library.get_scene(entry.id, dimension)
			_expect(scene != null, entry.id + " " + dimension + " catalog scene exists")
			var effect: Node = scene.instantiate()
			var frames: SpriteFrames = effect.sprite_frames
			var animation: StringName = effect.animation
			_expect(String(animation) == entry.animation, entry.id + " animation name retained")
			_expect(frames.get_frame_count(animation) == entry.frames, entry.id + " frame count retained")
			_expect(frames.get_animation_speed(animation) == entry.fps, entry.id + " fps retained")
			_expect(frames.get_animation_loop(animation) == entry.loop, entry.id + " loop retained")
			var size := Vector2(entry.size[0], entry.size[1])
			var pivot := Vector2(entry.pivot[0], entry.pivot[1])
			var expected := (Vector2(0.5, 0.5) - pivot) * size
			if dimension == "3d":
				expected.y = -expected.y
			_expect(effect.offset.is_equal_approx(expected), entry.id + " " + dimension + " correct pivot direction")
			for index: int in entry.frames:
				var texture := frames.get_frame_texture(animation, index) as AtlasTexture
				_expect(texture != null and texture.atlas != null, entry.id + " texture dependency resolves")
				_expect(texture.region == Rect2(index * size.x, 0, size.x, size.y), entry.id + " frame rect preserved")
			root.add_child(effect)
			_expect(effect.is_playing(), entry.id + " actually starts its named animation")
			_expect(effect.frame == 0, entry.id + " preview frame does not skip animation start")
			if dimension == "3d":
				var bottom: float = INF
				var left: float = INF
				for point: Vector3 in effect.generate_triangle_mesh().get_faces():
					bottom = minf(bottom, point.y)
					left = minf(left, point.x)
				_expect(is_equal_approx(bottom, (pivot.y - 1.0) * size.y * effect.pixel_size), entry.id + " actual 3D mesh bottom matches pivot")
				_expect(is_equal_approx(left, -pivot.x * size.x * effect.pixel_size), entry.id + " actual 3D mesh left matches pivot")
			effect.free()
	await _test_indicators()
	await _test_galleries()
	_expect(Library.get_scene("does-not-exist") == null, "unknown effect returns null")
	_expect(Library.get_scene("spell-indicator-circle", "2d") == null, "unsupported dimension returns null")
	print("VFX library checks: ", checks)
	_finish("VFX LIBRARY TESTS")

func _test_indicators() -> void:
	for id: String in ["spell-indicator-circle", "spell-indicator-sector"]:
		var a: Node = Library.get_scene(id, "3d").instantiate()
		var b: Node = Library.get_scene(id, "3d").instantiate()
		a.auto_step = false
		b.auto_step = false
		root.add_child(a)
		root.add_child(b)
		var count := [0]
		a.finished.connect(func() -> void: count[0] += 1)
		a.step(1.0)
		_expect(is_equal_approx(a.progress, 0.5), id + " half warning at one second")
		_expect(b.progress == 0.0, id + " independent progress")
		_expect(a.surface.material_override != b.surface.material_override, id + " independent material")
		_expect(is_equal_approx(a.surface.material_override.get_shader_parameter("uProgress"), 0.5), id + " shader follows progress")
		a.step(1.0)
		_expect(a.phase == &"ending" and not a.is_finished, id + " completion flash before finish")
		a.step(0.15)
		_expect(a.is_finished and count[0] == 1 and not a.surface.visible, id + " finish after fade")
		a.step(20.0)
		_expect(count[0] == 1, id + " signals exactly once")
		a.reset()
		a.manual_progress = true
		a.step(50.0)
		_expect(a.progress == 0.0 and not a.is_finished, id + " manual progress independent of time")
		a.set_progress(0.65)
		_expect(a.progress == 0.65, id + " manual progress accepted")
		a.stop()
		a.step(0.12)
		_expect(a.is_finished, id + " cancellation fade")
		a.reset()
		a.manual_progress = false
		a.step(200.0)
		_expect(a.is_finished, id + " large delta crosses complete lifecycle")
		a.reset()
		a.step(NAN)
		a.step(-1)
		_expect(a.elapsed == 0.0, id + " rejects invalid delta")
		a.free()
		b.free()

func _test_galleries() -> void:
	for dimension: String in ["2d", "3d"]:
		var gallery: Node = load(BASE + "gallery_" + dimension + ".tscn").instantiate()
		root.add_child(gallery)
		await _frames(2)
		if dimension == "3d":
			_expect(gallery.list.item_count == 46, "3D opens on all 46 native ports")
		gallery._filter_source(0)
		_expect(gallery.list.item_count == (41 if dimension == "2d" else 87), dimension + " all ready effects selectable")
		for index: int in gallery.list.item_count:
			gallery._select(index)
			_expect(gallery.holder.get_child_count() == 1, dimension + " selecting effect never stacks previews")
			await _frames(1)
		gallery._select(gallery.effect_ids.find("cinder-explosion"))
		gallery.get_node("%SpeedControl").value = 0.25
		_expect(gallery.replay.time_left > 3.6, dimension + " slow playback has enough time before automatic replay")
		gallery._stop()
		gallery.get_node("%SpeedControl").value = 1.0
		_expect(gallery.replay.is_stopped(), dimension + " speed change respects manual stop")
		gallery.free()
