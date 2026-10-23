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
const PixelVfx = preload("res://addons/proto_kit/pixel_vfx.gd")
const Sprite3DSheet = preload("res://addons/proto_kit/sprite3d_sheet.gd")
const Sprite3DActor = preload("res://addons/proto_kit/sprite3d_actor.gd")
const NineSlice = preload("res://addons/proto_kit/nine_slice.gd")
const Screenshot = preload("res://addons/proto_kit/screenshot.gd")
const SceneRouter = preload("res://addons/proto_kit/scene_router.gd")
const StoreFront = preload("res://addons/proto_kit/store_front.gd")
const Gacha = preload("res://addons/proto_kit/gacha.gd")
const Hd2dLook = preload("res://addons/proto_kit/hd2d_look.gd")
const Hd2dDemo = preload("res://addons/proto_kit/hd2d_demo.gd")
const PixelCard3D = preload("res://addons/proto_kit/pixel_card3d.gd")
const CameraShotRes = preload("res://addons/proto_kit/camera_shot.gd")
const DIR: String = "user://proto_kit_test"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_synth()
	_test_atomic_file()
	_test_scene_builder()
	_test_scene_patch()
	_test_nine_slice()
	_test_screenshot()
	_test_gacha()
	await _test_store_front()
	await _test_scene_router()
	_test_hd2d_pieces()
	await _test_hd2d_demo()
	_test_font_check()
	await _test_sfx_bank()
	_test_haptics()
	await _test_time_control()
	await _test_music()
	_test_camera_shake()
	_test_pixel_vfx()
	await _test_sprite3d()
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


## open_scene + put: a patch script opens a saved scene, swaps one node, saves it back; running it twice changes nothing.
func _test_scene_patch() -> void:
	var dir: String = DIR + "/patch"
	_remove_tree(dir)
	var child_path: String = dir + "/badge.tscn"
	var page_path: String = dir + "/page.tscn"
	SceneBuilder.save_scene(_named("Badge"), child_path)
	var page := _named("Page")
	var column: Node = SceneBuilder.add(page, Node2D.new(), "Column")
	for key: String in ["Title", "Rule", "Body"]:
		SceneBuilder.add(column, Node2D.new(), key)
	SceneBuilder.add(page, SceneBuilder.instance(child_path), "Corner")
	SceneBuilder.save_scene(page, page_path)

	var errors := ErrorLog.new()
	OS.add_logger(errors)
	var missing: Dictionary = SceneBuilder.open_scene(dir + "/none.tscn")
	OS.remove_logger(errors)
	_expect(missing.root == null and missing.refs.is_empty(), "open_scene on a missing file gives a null root")
	var md5: String = ""
	for run: int in 2:
		var opened: Dictionary = SceneBuilder.open_scene(page_path)
		var root: Node = opened.root
		_expect(root != null and root.scene_file_path.is_empty(), "open_scene gives a plain root, not an instance of the file")
		_expect(opened.refs == [child_path], "open_scene lists the sub-scenes the file references (%s)" % [opened.refs])
		var col: Node = root.get_node("Column")
		SceneBuilder.put(col, SceneBuilder.instance(child_path), "Rule")
		_expect(col.get_child(1).name == &"Rule" and col.get_child(1).scene_file_path == child_path and col.get_child_count() == 3,
			"put replaces the node of that name in its place (run %d)" % run)
		var saved: Dictionary = SceneBuilder.save_scene(root, page_path, {"overwrite": true, "expected_refs": opened.refs})
		_expect(saved.ok, "the patched scene saves (%s)" % saved.error)
		if run == 0:
			md5 = FileAccess.get_md5(page_path)
	_expect(FileAccess.get_md5(page_path) == md5, "patching twice gives the same file")
	var reloaded: Node = (ResourceLoader.load(page_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	_expect(reloaded.get_node("Corner").scene_file_path == child_path, "sub-scene instances stay references through a patch")
	reloaded.free()
	var parent := Node.new()
	for key: String in ["A", "B"]:
		SceneBuilder.add(parent, Node.new(), key)
	SceneBuilder.put(parent, Node.new(), "New", 0)
	_expect(parent.get_child(0).name == &"New" and parent.get_child_count() == 3, "put inserts a new name at the given index")
	parent.free()
	_remove_tree(dir)


func _test_nine_slice() -> void:
	var dir: String = DIR + "/frames"
	_remove_tree(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	for name: String in ["btn", "btn_pressed"]:
		var image := Image.create(12, 12, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE if name == "btn" else Color.GRAY)
		image.save_png(dir + "/%s.png" % name)
	var box: StyleBoxTexture = NineSlice.box(ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8)), 3, Vector4(4, 5, 6, 7), 2.0)
	_expect(box.texture_margin_left == 3 and box.texture_margin_bottom == 3, "nine_slice: slice sets all four texture margins")
	_expect(box.content_margin_left == 4 and box.content_margin_top == 7 and box.content_margin_right == 6 and box.content_margin_bottom == 5,
		"nine_slice: sink moves the content down (top +2, bottom -2)")
	var theme := Theme.new()
	# Plain PNGs under user:// (not imported): read from the file.
	var pattern: String = dir + "/btn%s.png"
	var ok: bool = NineSlice.button_states(theme, &"Button", pattern, 3, Vector4(4, 4, 4, 4))
	var errors := ErrorLog.new()
	OS.add_logger(errors)
	var refused: bool = NineSlice.button_states(Theme.new(), &"Button", dir + "/none%s.png", 3, Vector4.ZERO)
	OS.remove_logger(errors)
	_expect(not refused, "nine_slice: no normal frame sets nothing")
	if ok:
		var normal: StyleBoxTexture = theme.get_stylebox(&"normal", &"Button")
		var hover: StyleBoxTexture = theme.get_stylebox(&"hover", &"Button")
		var pressed: StyleBoxTexture = theme.get_stylebox(&"hover_pressed", &"Button")
		_expect(hover.texture.get_image().get_pixel(0, 0) == normal.texture.get_image().get_pixel(0, 0), "nine_slice: a missing hover frame falls back to normal")
		_expect(pressed.texture.get_image().get_pixel(0, 0) != normal.texture.get_image().get_pixel(0, 0) and pressed.content_margin_top == 6,
			"nine_slice: hover_pressed uses the pressed frame and sinks")
	else:
		_expect(false, "nine_slice: button_states reads the frames (%s)" % pattern)
	_remove_tree(dir)


func _test_screenshot() -> void:
	_expect(Screenshot.out_dir("user://fallback") == "user://fallback", "screenshot: no user argument -> the fallback folder")
	if DisplayServer.get_name() != "headless":
		return
	var errors := ErrorLog.new()
	OS.add_logger(errors)
	var path: String = Screenshot.save(root, DIR + "/shots", "none")
	OS.remove_logger(errors)
	_expect(path == "" and errors.messages.any(func(m: String) -> bool: return m.contains("headless")),
		"screenshot: headless has no image, says so and saves nothing")


## Rates, pity and the featured share, over many pulls on a fixed seed.
func _test_gacha() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var rates := [55, 30, 12, 3]
	var counts := [0, 0, 0, 0]
	for k: int in 20000:
		counts[Gacha.tier(rng, rates)] += 1
	for t: int in 4:
		_expect(absf(counts[t] / 200.0 - rates[t]) < 1.5, "gacha: tier %d comes %.1f%% of pulls (rate %d%%)" % [t, counts[t] / 200.0, rates[t]])
	var state: int = rng.state
	_expect(Gacha.tier(rng, rates, true) == 3 and rng.state == state, "gacha: pity gives the top tier without drawing")
	var pool := PackedInt32Array([10, 11, 12, 13])
	var featured: int = 0
	var others := {}
	for k: int in 20000:
		var unit: int = Gacha.pick(rng, pool, 12, 0.5)
		if unit == 12:
			featured += 1
		else:
			others[unit] = others.get(unit, 0) + 1
	_expect(absf(featured / 20000.0 - 0.5) < 0.015, "gacha: the featured unit is its share of the tier (%.3f)" % (featured / 20000.0))
	_expect(others.size() == 3 and others.values().all(func(n: int) -> bool: return absf(n / 10000.0 - 1.0 / 3.0) < 0.03),
		"gacha: the others share the rest evenly (%s)" % others)
	state = rng.state
	var one: int = Gacha.pick(rng, pool)
	var replay := RandomNumberGenerator.new()
	replay.state = state
	_expect(one == pool[replay.randi_range(0, 3)], "gacha: a plain pick draws exactly one randi_range (saved streams stay in step)")
	_expect(Gacha.pick(rng, PackedInt32Array()) == -1, "gacha: an empty pool gives -1")


class TestStore extends "res://addons/proto_kit/store_front.gd":
	var shown: Array = []

	func _ready() -> void:
		products = {"gems": CONSUMABLE, "no_ads": NON_CONSUMABLE}
		super()

	func _ad_card_shown(placement: String) -> void:
		shown.append(placement)

	func _ad_card_tick(seconds_left: int) -> void:
		shown.append(seconds_left)

	func _ad_card_hidden() -> void:
		shown.append("hidden")


func _test_store_front() -> void:
	var file: String = DIR + "/store_test.json"
	DirAccess.make_dir_recursive_absolute(DIR)
	DirAccess.remove_absolute(file)
	var store := TestStore.new()
	store.test_file = file
	store.ad_seconds = 2.0
	root.add_child(store)
	_expect(store.is_test(), "store: the base is the test store")
	var errors := ErrorLog.new()
	OS.add_logger(errors)
	_expect(not await store.buy("nope"), "store: an unknown product is refused")
	OS.remove_logger(errors)
	_expect(await store.buy("gems") and (await store.restore()).is_empty(), "store: a consumable is paid and not restored")
	_expect(await store.buy("no_ads") and await store.buy("no_ads"), "store: a non-consumable can be bought again (the store answers, the game grants once)")
	_expect(await store.restore() == PackedStringArray(["no_ads"]), "store: restore lists the non-consumable once")
	var fresh := TestStore.new()
	fresh.test_file = file
	root.add_child(fresh)
	_expect(await fresh.restore() == PackedStringArray(["no_ads"]), "store: what was bought survives a restart (test_file)")
	fresh.queue_free()
	var started: int = Time.get_ticks_msec()
	var watched: Array = []
	(func() -> void: watched.append(await store.show_ad("bonus"))).call()
	_expect(store.busy and not await store.show_ad("other"), "store: a second ad is refused while one shows")
	await _until(func() -> bool: return not watched.is_empty(), "store: the ad ends")
	_expect(watched == [true], "store: an ad watched to the end pays")
	_expect(store.shown == ["bonus", 2, 1, "hidden"] and Time.get_ticks_msec() - started >= 1900 and not store.busy,
		"store: the card counts down ad_seconds of game time (%s)" % [store.shown])
	store.shown.clear()
	_expect(await store.show_ad("bonus", true) and store.shown.is_empty(), "store: skip (免廣告) pays without a card")
	store.queue_free()
	DirAccess.remove_absolute(file)


func _test_scene_router() -> void:
	var dir: String = DIR + "/router"
	_remove_tree(dir)
	for key: String in ["One", "Two"]:
		SceneBuilder.save_scene(_named(key), dir + "/%s.tscn" % key.to_lower())
	var router: CanvasLayer = SceneRouter.new()
	var fade := ColorRect.new()
	fade.name = "Fade"
	router.add_child(fade)
	fade.owner = router
	fade.unique_name_in_owner = true
	router.fade_seconds = 0.05
	root.add_child(router)
	_expect(not fade.visible, "router: the fade starts hidden")
	var changed: Array = []
	router.screen_changed.connect(func(path: String) -> void: changed.append(path))
	var went: Array = []
	(func() -> void: went.append(await router.go(dir + "/one.tscn", {&"stage": 3}))).call()
	_expect(router.busy() and not await router.go(dir + "/two.tscn"), "router: a second go() during a change is ignored")
	await _until(func() -> bool: return not went.is_empty(), "router: the change ends")
	_expect(went == [true] and current_scene.name == &"One" and not router.busy(), "router: go() changes the scene")
	_expect(not fade.visible and fade.mouse_filter == Control.MOUSE_FILTER_IGNORE, "router: the fade is gone and lets taps through")
	_expect(router.take(&"stage", 1) == 3 and router.take(&"stage", 1) == 1, "router: take() hands a value over once, then the default")
	_expect(changed == [dir + "/one.tscn"], "router: screen_changed fires once per change")
	paused = true
	_expect(await router.go(dir + "/two.tscn") and current_scene.name == &"Two" and not paused, "router: go() from a paused screen unpauses")
	var errors := ErrorLog.new()
	OS.add_logger(errors)
	_expect(not await router.go(dir + "/none.tscn") and current_scene.name == &"Two", "router: a missing scene keeps the current one")
	OS.remove_logger(errors)
	router.queue_free()
	current_scene.queue_free()
	_remove_tree(dir)


## HD-2D pieces on their own: the card's size and lean, the look presets, the shaders compile.
func _test_hd2d_pieces() -> void:
	var card: MeshInstance3D = PixelCard3D.new()
	card.texture = ImageTexture.create_from_image(Image.create(40, 80, false, Image.FORMAT_RGBA8))
	_expect(card.card_size().is_equal_approx(Vector2(1.0, 2.0)) and (card.mesh as QuadMesh).size.is_equal_approx(Vector2(1.0, 2.0)),
		"hd2d: a card is its texture times m_per_px (%s)" % card.card_size())
	_expect(is_equal_approx(card.rotation.x, -deg_to_rad(14.0)) and card.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
		"hd2d: a card leans back 14 degrees and casts the sun's shadow")
	card.m_per_px = 0.05
	_expect((card.mesh as QuadMesh).size.is_equal_approx(Vector2(2.0, 4.0)), "hd2d: changing m_per_px rebuilds the card")
	card.free()
	var env: Environment = Hd2dLook.environment({"fog_depth_begin": 9.0})
	_expect(env.fog_enabled and env.fog_depth_begin == 9.0 and env.fog_depth_end == 34.0 and env.tonemap_mode == Environment.TONE_MAPPER_LINEAR,
		"hd2d: environment() is the dusk preset with overrides")
	_expect(Hd2dLook.camera_attributes().dof_blur_far_enabled, "hd2d: camera_attributes() blurs the far set")
	var errors := ErrorLog.new()
	OS.add_logger(errors)
	Hd2dLook.environment({"no_such_thing": 1})
	OS.remove_logger(errors)
	_expect(errors.messages.any(func(m: String) -> bool: return m.contains("no_such_thing")), "hd2d: an unknown override is reported")
	for path: String in ["ground_decal", "pixel_vfx3d_ring", "parallax_layer", "hd2d_vignette"]:
		var shader: Shader = load("res://addons/proto_kit/%s.gdshader" % path)
		_expect(shader != null and shader.get_shader_uniform_list().size() > 0, "hd2d: %s.gdshader compiles with its uniforms" % path)


## The demo diorama runs on kit modules only: lights tint sprites, effects pool and expire, the shot camera comes home,
## the march strip walks, fights and counts kills, all on game time and their own random streams.
func _test_hd2d_demo() -> void:
	var demo: Node = Hd2dDemo.build(Vector2(720, 1280))
	root.add_child(demo)
	await process_frame
	var stage: Node3D = demo.get_node(^"World/Stage")
	var near: Color = stage.sprite_light(Vector3(-2.0, 0.5, -1.0))
	var far: Color = stage.sprite_light(Vector3(10.0, 0.5, 10.0))
	_expect(near.r > far.r + 0.3 and far.is_equal_approx(stage.sprite_key), "hd2d: a sprite by the torch is lit warmer (%s vs %s)" % [near, far])
	stage.set_region_light(Color(0.5, 0.5, 1.0))
	_expect(stage.sprite_light(Vector3(10.0, 0.5, 10.0)).is_equal_approx(stage.sprite_key * Color(0.5, 0.5, 1.0)),
		"hd2d: the region light tints sprites and the sun together")

	var fx: Node3D = demo.get_node(^"World/Fx")
	fx.burst(Vector3.ZERO, 10, &"rock")
	fx.step(0.0)
	fx.step(0.0)
	_expect(fx._pos.size() == 10, "hd2d: burst adds its chunks")
	fx.burst(Vector3.ZERO, 1000, &"dust")
	_expect(fx._pos.size() == fx.max_chunks, "hd2d: chunks stop at max_chunks")
	for k: int in 5:
		fx.ring(Vector3.ZERO, 1.0, &"gold")
	_expect(fx._rings.size() == 4, "hd2d: a ring with every quad busy is skipped")
	for k: int in 150:
		fx.step(1.0 / 60.0)
	_expect(fx._pos.is_empty() and fx._rings.is_empty(), "hd2d: chunks and rings end on game time")
	var twin: Node3D = Hd2dDemo._fx()
	root.add_child(twin)
	twin.step(0.0)  # its two warm-up frames (shaders compiled out of sight) pass first, as fx's did
	twin.step(0.0)
	fx.clear()
	fx.rng.seed = fx.rng_seed
	for f: Node3D in [fx, twin]:
		f.burst(Vector3(1, 0, 1), 12, &"slam", 3.0, 3.0, 4)
		for k: int in 20:
			f.step(1.0 / 60.0)
	_expect(fx._pos == twin._pos, "hd2d: the same seed throws the same chunks (its own rng, not randf)")
	twin.queue_free()

	var camera: Camera3D = demo.get_node(^"World/Camera")
	var home: Transform3D = camera.transform
	var shot: Resource = CameraShotRes.new()
	shot.ease_in = 0.1
	shot.hold = 0.2
	shot.ease_out = 0.1
	shot.priority = 2
	var weak: Resource = CameraShotRes.new()
	_expect(camera.play(shot, Vector3(1, 0, 0)) == shot.hit_stop and camera.busy(), "hd2d: a shot plays")
	_expect(camera.play(weak, Vector3.ZERO) == 0.0, "hd2d: a weaker shot does not cut a stronger one")
	for k: int in 12:
		camera._process(1.0 / 60.0)
	_expect(not camera.transform.is_equal_approx(home), "hd2d: the camera moves toward the focus")
	for k: int in 40:
		camera._process(1.0 / 60.0)
	_expect(not camera.busy() and camera.transform.is_equal_approx(home), "hd2d: the camera eases back home after the hold")

	var strip: Control = demo.get_node(^"Hud/MarchStrip")
	var spawned: Array = [0]
	strip.enemy_spawned.connect(func() -> void: spawned[0] += 1)
	var walked: bool = false
	var fought: bool = false
	for k: int in 1800:
		strip.step(1.0 / 60.0)
		walked = walked or strip.walking
		fought = fought or not strip.walking
	_expect(walked and fought and strip.kills >= 2 and spawned[0] >= strip.kills, "march_strip: walks, fights, kills (%d in 30 s)" % strip.kills)
	var again: Control = Hd2dDemo._strip(Vector2(720, 260))
	root.add_child(again)
	again.set_process(false)
	await process_frame
	for k: int in 1800:
		again.step(1.0 / 60.0)
	_expect(again.kills == strip.kills, "march_strip: the same seed gives the same march (%d vs %d)" % [again.kills, strip.kills])
	again.queue_free()
	demo.queue_free()
	await process_frame


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
func _test_pixel_vfx() -> void:
	var fx: Node2D = PixelVfx.new()
	root.add_child(fx)
	# Effects use their own generator: spawning them must not move the game's seeded randf().
	seed(42)
	var expected: float = randf()
	seed(42)
	fx.burst(Vector2.ZERO, &"hit", 20)
	var boom: Node2D = fx.effect(&"explosion", Vector2.ZERO, Vector2(64, 64), 0.5, &"fire")
	_expect(randf() == expected, "pixel_vfx: effects never touch the global random generator")
	_expect(fx.count() == 21, "pixel_vfx: a burst adds its particles and an effect adds one node")
	_expect(boom.material is ShaderMaterial and boom.material.get_shader_parameter(&"tone_2") == fx.tones(&"fire")[2], "pixel_vfx: shader effects get their palette as tone uniforms")
	fx.max_particles = 5
	fx.burst(Vector2.ZERO, &"hit", 50)
	_expect(fx._parts.size() == 20, "pixel_vfx: max_particles caps new particles")
	var drawn: Array = []
	fx.register(&"blip", func(entry: Dictionary, left: float) -> void: drawn.append(left))
	fx.add_shape(&"blip", Vector2(3, 3), &"ice", 0.2, {"size": 2})
	fx.add_shape(&"nope", Vector2.ZERO, &"ice", 0.2)
	_expect(fx._shapes.size() == 1 and fx._shapes[0].size == 2 and fx._shapes[0].pal == fx.tones(&"ice"), "pixel_vfx: registered kinds spawn with their extra keys; unknown kinds are ignored")
	_expect(fx.tones(&"no such palette") == fx.tones(fx.fallback_palette), "pixel_vfx: unknown palettes fall back")
	fx._process(1.0)
	boom._process(1.0)
	_expect(fx._parts.is_empty() and fx._shapes.is_empty() and boom.is_queued_for_deletion(), "pixel_vfx: everything expires after its life")
	_expect(PixelVfx.fade(0.9) == 1.0 and PixelVfx.fade(0.5) == 0.66 and PixelVfx.fade(0.1) == 0.33, "pixel_vfx: fades step instead of sliding")
	fx.pixel = 3.0
	_expect(fx.snap(Vector2(4.4, -1.6)) == Vector2(3, -3), "pixel_vfx: snap() puts points on the art-pixel grid")
	fx.clear()
	fx.slash(Vector2.ZERO, 0.0, 80.0, 1.7, &"hit")
	_expect(fx._shapes.size() == 1 and fx._shapes[0].kind == &"slash", "pixel_vfx: a swing alone never implies a collision")
	_expect(fx.ground_layer.z_index < fx.z_index and not fx.ground_layer.z_as_relative, "pixel_vfx: ground rings render on their own absolute layer")
	fx.clear()
	fx.caption(Vector2.ZERO, "BAM", &"hit")
	fx.caption(Vector2.ZERO, "BAM", &"hit")
	_expect(fx.stats().shapes == 1 and fx.stats().dropped.captions == 1, "pixel_vfx: captions are throttled")
	fx._process(fx.caption_interval + 0.01)
	fx.caption(Vector2.ZERO, "BAM", &"hit")
	_expect(fx.stats().shapes == 1, "pixel_vfx: captions resume after the cooldown")
	fx.clear()
	fx.max_particles = 5
	fx.burst(Vector2.ZERO, &"hit", 10)
	for i: int in 80:
		fx.ring(Vector2.ZERO, 10, 30, &"hit")
	_expect(fx.stats().shapes == 72, "pixel_vfx: cosmetic shapes leave eight collision slots")
	for i: int in 12:
		fx.star(Vector2.ZERO, &"hit")
	fx.max_shader_effects = 3
	for i: int in 4:
		fx.effect(&"gas", Vector2.ZERO, Vector2(64, 64), 0.5, &"poison")
	var stats: Dictionary = fx.stats()
	_expect(stats.particles == 5 and stats.shapes == 80 and stats.shaders == 3 and fx.count() == 88, "pixel_vfx: every renderer category respects its actual budget")
	_expect(stats.dropped.particles == 5 and stats.dropped.shapes == 12 and stats.dropped.shaders == 1, "pixel_vfx: telemetry counts rejected requests")
	stats.dropped.particles = 999
	_expect(fx.stats().dropped.particles == 5, "pixel_vfx: telemetry cannot mutate renderer counters")
	fx.clear()
	_expect(fx.count() == 0 and fx.stats().dropped.particles == 0 and is_instance_valid(fx.ground_layer), "pixel_vfx: clear reclaims effects, resets counters and retains the ground renderer")
	fx.free()

func _test_sprite3d() -> void:
	# A camera with the identity basis looks down -Z, so a facing of +Z points at it.
	var cam := Basis.IDENTITY
	_expect(is_equal_approx(Sprite3DSheet.view_angle(Vector3(0, 0, 1), cam), 0.0), "sprite3d: facing the camera is 0")
	_expect(is_equal_approx(Sprite3DSheet.view_angle(Vector3(1, 0, 0), cam), 90.0), "sprite3d: screen right is 90")
	_expect(is_equal_approx(Sprite3DSheet.view_angle(Vector3(0, 0, -1), cam), 180.0), "sprite3d: away from the camera is 180")
	_expect(is_equal_approx(Sprite3DSheet.view_angle(Vector3(-1, 0, 0), cam), 270.0), "sprite3d: screen left is 270")
	var turned := Basis(Vector3.UP, PI / 2.0)  # the camera turned to look down -X: world +Z is now screen left
	_expect(is_equal_approx(Sprite3DSheet.view_angle(Vector3(0, 0, 1), turned), 270.0), "sprite3d: the angle follows the camera, not the world")
	var down := Basis(Vector3.RIGHT, -PI / 2.0)  # looking straight down, screen up = world -Z
	_expect(is_equal_approx(Sprite3DSheet.view_angle(Vector3(0, 0, 1), down), 0.0) and is_equal_approx(Sprite3DSheet.view_angle(Vector3(1, 0, 0), down), 90.0), "sprite3d: a top-down camera still gives directions")
	var pitched := Basis(Vector3.RIGHT, deg_to_rad(-26.0))
	_expect(is_equal_approx(Sprite3DSheet.view_angle(Vector3(1, 0, 1).normalized(), pitched), 45.0), "sprite3d: pitch does not bend the diagonals")

	var sheet: Resource = Sprite3DSheet.new()
	sheet.columns = 8
	sheet.rows = 5
	sheet.directions = 8
	sheet.mirror = true
	sheet.anims = {"walk": {"cell": 2, "n": 2, "d": [10, 5], "loop": true}, "attack": {"cell": 4, "n": 2, "d": [3, 3], "loop": false}}
	_expect(sheet.direction(0.0) == 0 and sheet.direction(44.0) == 1 and sheet.direction(90.0) == 2 and sheet.direction(337.0) == 7, "sprite3d: 8 directions in 45-degree sectors")
	_expect(sheet.direction(28.0, 0) == 0 and sheet.direction(29.0, 0) == 1, "sprite3d: the direction holds until 6 degrees past the border")
	_expect(sheet.cell(&"walk", 2, 0) == Vector2i(2 + 2 * 8, 1), "sprite3d: a drawn row is cell + row * columns")
	_expect(sheet.cell(&"walk", 5, 0) == Vector2i(2 + 3 * 8, -1) and sheet.cell(&"walk", 7, 0) == Vector2i(2 + 1 * 8, -1), "sprite3d: back-left and front-left are the right-side rows mirrored")
	_expect(sheet.cell(&"walk", 0, 9).x == 2 and sheet.cell(&"walk", 0, 10).x == 3 and sheet.cell(&"walk", 0, 15).x == 2, "sprite3d: frames follow their ticks and loop")
	_expect(sheet.cell(&"attack", 0, 100).x == 5, "sprite3d: a one-shot holds its last frame")
	_expect(sheet.cell(&"no such anim", 0, 0).x == 2, "sprite3d: a missing animation falls back to walk")
	sheet.directions = 4
	_expect(sheet.direction(270.0) == 3 and sheet.cell(&"walk", 3, 0) == Vector2i(2 + 8, -1), "sprite3d: 4 directions mirror left from right")
	sheet.directions = 1
	_expect(sheet.direction(90.0) == 0 and sheet.cell(&"walk", 0, 0) == Vector2i(2, 1), "sprite3d: one direction faces right as drawn")
	_expect(sheet.direction(270.0) == 1 and sheet.cell(&"walk", 1, 0) == Vector2i(2, -1), "sprite3d: one direction flips for screen left")
	var color: Color = Sprite3DSheet.instance_color(Color(0.5, 1, 1), Sprite3DSheet.ROLE_ELITE)
	_expect(roundi((1.0 - color.a) * 8.0) == Sprite3DSheet.ROLE_ELITE and roundi((1.0 - Color.WHITE.a) * 8.0) == Sprite3DSheet.ROLE_NONE, "sprite3d: the outline role round-trips through the instance alpha; white means none")
	var custom: Color = Sprite3DSheet.instance_custom(7, 0.5, -1, 1.0, 0.25)
	_expect(signf(custom.b) == -1.0 and is_equal_approx(absf(custom.b) - 1.0, 0.25), "sprite3d: facing and dissolve share INSTANCE_CUSTOM.z")

	DirAccess.make_dir_recursive_absolute(DIR)
	var json_path: String = DIR + "/sheets.json"
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"atlas": "atlas.png", "cell_px": 32, "columns": 8, "rows": 5, "foot_px": 2, "meters_per_px": 0.05,
		"characters": {"hero": {"directions": 8, "mirror": true, "anims": {"idle": {"cell": 0, "n": 2, "d": [10, 5], "loop": true}}}}}))
	file.close()
	var loaded: Resource = Sprite3DSheet.from_json(json_path, "hero")
	_expect(loaded != null and loaded.columns == 8 and loaded.cell(&"idle", 6, 10) == Vector2i(1 + 2 * 8, -1), "sprite3d: from_json reads a sprite_atlas.py sheet")
	_expect(is_equal_approx(loaded.size_m(), 1.6) and is_equal_approx(loaded.foot_gutter(), 2.0 / 32.0), "sprite3d: quad size and foot strip come from the sheet")

	for path: String in ["sprite3d.gdshader", "sprite3d_xray.gdshader", "sprite3d_ghost.gdshader", "sprite3d_shadow.gdshader"]:
		var shader: Shader = load("res://addons/proto_kit/" + path)
		var names: Array = shader.get_shader_uniform_list().map(func(u: Dictionary) -> String: return u.name)
		_expect(not names.is_empty(), "sprite3d: %s parses" % path)
		if path != "sprite3d_shadow.gdshader":
			_expect(names.has("frames") and names.has("foot_gutter"), "sprite3d: %s takes the sheet's grid" % path)
	var main_names: Array = (load("res://addons/proto_kit/sprite3d.gdshader") as Shader).get_shader_uniform_list().map(func(u: Dictionary) -> String: return u.name)
	_expect(main_names.has("outline_elite") and main_names.has("dissolve") and main_names.has("see_through_enabled"), "sprite3d: the main shader has outline roles, dissolve and see-through")

	var actor: Node3D = Sprite3DActor.new()
	var sprite := MeshInstance3D.new()
	sprite.name = "Sprite"
	var mat := ShaderMaterial.new()
	mat.shader = load("res://addons/proto_kit/sprite3d.gdshader")
	sprite.material_override = mat
	actor.add_child(sprite)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 10)
	root.add_child(camera)
	camera.make_current()
	loaded.mirror = true
	actor.sheet = loaded
	actor.anim = &"idle"
	actor.facing = Vector3(-1, 0, 0)  # screen left
	root.add_child(actor)
	await _frames(2)
	var m: ShaderMaterial = sprite.material_override
	_expect(m != mat, "sprite3d: an actor draws with its own copy of the material")
	_expect(actor.direction == 6 and is_equal_approx(m.get_shader_parameter(&"facing"), -1.0) and int(m.get_shader_parameter(&"frame")) % 8 < 2 and int(m.get_shader_parameter(&"frame")) / 8 == 2, "sprite3d: facing screen left shows the right row mirrored")
	_expect(is_equal_approx(sprite.scale.x, 1.6) and m.get_shader_parameter(&"frames") == Vector2(8, 5), "sprite3d: the sheet sizes the quad and sets the grid")
	actor.play(&"idle")
	var before: float = actor.ticks
	actor.play(&"idle")
	_expect(actor.ticks == before, "sprite3d: play() does not restart the running animation")

	# The game's own clock: a paused world (delta 0) keeps the frame; hit stop advances it in proportion.
	actor.auto_advance = false
	actor.play(&"idle", true)
	await _frames(3)
	_expect(actor.ticks == 0.0, "sprite3d: with auto_advance off the actor does not move on by itself")
	actor.step(0.0)
	_expect(actor.ticks == 0.0, "sprite3d: step(0) keeps the frame")
	actor.step(10.0 / 60.0)
	_expect(is_equal_approx(actor.ticks, 10.0) and int(m.get_shader_parameter(&"frame")) % 8 == 1, "sprite3d: step(game delta) advances the animation and redraws")

	# One-shots finish after their full length, and a fallback animation finishes as it plays.
	loaded.anims["hit"] = {"cell": 0, "n": 2, "d": [3, 3], "loop": false}
	actor.play(&"hit")
	actor.step(5.0 / 60.0)
	_expect(not actor.finished(), "sprite3d: a one-shot is not finished while its last frame still has time")
	actor.step(1.0 / 60.0)
	_expect(actor.finished(), "sprite3d: a one-shot is finished after its full length")
	actor.play(&"missing")
	_expect(not actor.finished() and loaded.resolve(&"missing") == loaded.resolve(&"idle"), "sprite3d: a missing animation plays (and finishes like) its fallback")
	_expect(Sprite3DSheet.length_ticks({"n": 4}) == 4, "sprite3d: without d, one tick per frame")

	# Two actors from one material: each gets its own copies, shadow included.
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	var shadow_mat := ShaderMaterial.new()
	shadow_mat.shader = load("res://addons/proto_kit/sprite3d_shadow.gdshader")
	shadow.material_override = shadow_mat
	var twin: Node3D = Sprite3DActor.new()
	var twin_sprite := MeshInstance3D.new()
	twin_sprite.name = "Sprite"
	twin_sprite.material_override = mat
	twin.add_child(twin_sprite)
	twin.add_child(shadow)
	var other: Resource = Sprite3DSheet.new()
	other.columns = 4
	other.rows = 4
	other.anims = {"idle": {"cell": 0, "n": 1, "d": [1], "loop": true}}
	twin.sheet = other
	root.add_child(twin)
	await _frames(1)
	_expect(m.get_shader_parameter(&"frames") == Vector2(8, 5) and (twin_sprite.material_override as ShaderMaterial).get_shader_parameter(&"frames") == Vector2(4, 4), "sprite3d: actors sharing a material keep their own sheets")
	_expect(shadow.material_override != shadow_mat and mat.get_shader_parameter(&"frames") == null, "sprite3d: the shadow material is copied too, and the scene's material is left alone")
	twin.free()
	actor.free()
	camera.free()

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
