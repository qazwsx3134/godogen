extends "res://addons/proto_kit/test_kit.gd"
## Saved scene + real HUD API, including replacement, input pass-through, clocks
## and layout under a resize. No main/jutsu integration is needed for this suite.

var _finished_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _finished() -> void:
	_finished_count += 1


func _x_bounds(control: Control) -> Vector2:
	var transform: Transform2D = control.get_global_transform()
	var a: Vector2 = transform * Vector2.ZERO
	var b: Vector2 = transform * Vector2(control.size.x, 0)
	var c: Vector2 = transform * control.size
	var d: Vector2 = transform * Vector2(0, control.size.y)
	return Vector2(minf(minf(a.x, b.x), minf(c.x, d.x)), maxf(maxf(a.x, b.x), maxf(c.x, d.x)))


func _run() -> void:
	var source := load("res://scenes/ult_banner.tscn") as PackedScene
	var editor_sample: Control = source.instantiate()
	_expect(editor_sample.visible and editor_sample.get_node("%Title").text == "霸王色霸氣", "saved scene includes visible editor sample")
	_expect(editor_sample.get_child_count() > 1 and editor_sample.find_children("*", "Control", true, false).size() >= 15, "saved layout is a real editable node tree")
	# Simulate an editor spacing change, save/reload, then run it. No generator
	# participates and runtime animation must preserve the authored spacing.
	editor_sample.find_child("ContentRow", true, false).add_theme_constant_override("separation", 42)
	var edited := PackedScene.new()
	var scratch: String = "user://banner-editor-check-%d.tscn" % Time.get_ticks_usec()
	_expect(edited.pack(editor_sample) == OK and ResourceSaver.save(edited, scratch) == OK, "editor variant saves")
	editor_sample.free()
	var reloaded: UltBanner = (load(scratch) as PackedScene).instantiate()
	root.add_child(reloaded)
	await _frames(2)
	reloaded.play("霸王色霸氣", "編輯器間距", Color.GOLD)
	_expect(reloaded.find_child("ContentRow", true, false).get_theme_constant("separation") == 42, "saved spacing survives runtime play")
	reloaded.queue_free()
	await _frames(1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	root.size = Vector2i(1280, 720)
	var hud: Hud = (load("res://scenes/hud.tscn") as PackedScene).instantiate()
	root.add_child(hud)
	await _frames(3)
	var banner: UltBanner = hud.ult_banner
	_expect(not banner.visible, "announcement hidden on runtime entry")
	_expect(banner.get_index() > hud.get_node("%Flash").get_index() and banner.get_index() < hud.get_node("%LevelUp").get_index(), "HUD contains the item between Flash and LevelUp")
	for node: Node in [banner] + banner.find_children("*", "Control", true, false):
		_expect((node as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "input ignored: " + String(node.name))
	banner.finished.connect(_finished)
	banner.use_real_time = false
	hud.show_banner("霸王色霸氣", "蒙奇・D・魯夫", Color.GOLD)
	_expect(banner.visible and banner.get_node("%Title").text == "霸王色霸氣", "HUD API starts the announcement")
	_expect(banner.get_node("%Initials").visible, "no portrait uses the initials placeholder")
	banner.advance(0.16)
	await _frames(2)
	var band: Control = banner.get_node("%Band")
	var extent: Vector2 = _x_bounds(band)
	_expect(extent.x <= 0 and extent.y >= root.get_visible_rect().size.x, "tilted band spans 16:9 screen")
	_expect(band.rotation_degrees <= -8 and band.rotation_degrees >= -12, "scene preserves authored tilt")
	# Freezing this game's custom clock does not advance a manually driven Tween.
	var held: Vector2 = banner.get_node("%Motion").position
	await _frames(4)
	_expect(banner.visible and banner.get_node("%Motion").position == held, "game clock waits for caller advance")
	root.size = Vector2i(1920, 720)
	banner.safe_insets = Vector4(96, 20, 32, 12)
	await _frames(4)
	extent = _x_bounds(band)
	_expect(extent.x <= 0 and extent.y >= root.get_visible_rect().size.x, "tilted band still spans ultrawide after resize")
	var portrait_bounds := _x_bounds(banner.find_child("PortraitFrame", true, false))
	var title_bounds := _x_bounds(banner.get_node("%Title"))
	_expect(portrait_bounds.x >= 96 and title_bounds.y <= root.get_visible_rect().size.x - 32, "contents remain inside asymmetric safe insets")
	# Click a real control below the announcement at the same screen position.
	var button := Button.new()
	button.text = "pass through"
	button.position = root.get_visible_rect().size * 0.5 - Vector2(90, 40)
	button.size = Vector2(180, 80)
	var clicks := [0]
	button.pressed.connect(func() -> void: clicks[0] += 1)
	hud.get_node("Root").add_child(button)
	hud.get_node("Root").move_child(button, 0)
	await _frames(2)
	await _tap(button.get_global_rect().get_center())
	_expect(clicks[0] == 1, "announcement does not intercept underlying button")
	button.queue_free()
	banner.advance(2.0)
	_expect(not banner.visible and _finished_count == 1, "finishing hides and emits exactly once")
	# Latest call wins, including replacing/removing a portrait and flash state.
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var portrait := ImageTexture.create_from_image(image)
	hud.show_banner("第一條", "人物", Color.RED, portrait)
	_expect(banner.get_node("%Portrait").texture == portrait and not banner.get_node("%Initials").visible, "optional portrait replaces initials")
	banner.advance(0.05)
	hud.show_banner("第二條", "接續招式", Color.CYAN)
	banner.advance(0.16)
	_expect(banner.get_node("%Title").text == "第二條" and banner.get_node("%Initials").visible, "replacement resets content and placeholder")
	_expect(hud.get_node("Root").find_children("UltBanner", "", false, false).size() == 1, "repeated calls keep a single scene instance")
	banner.advance(2.0)
	_expect(not banner.visible and _finished_count == 2, "canceled tween never finishes the replacement early")
	# The default real clock must finish even with both engine and tree paused.
	banner.use_real_time = true
	banner.enter_seconds = 0.03
	banner.hold_seconds = 0.04
	banner.exit_seconds = 0.03
	banner.flash_strength = 0.2
	Engine.time_scale = 0.0
	paused = true
	hud.show_banner("真實時間", "hit stop", Color.GOLD)
	await _until(func() -> bool: return not banner.visible, "real-time announcement finishes during hit stop", 2.0)
	paused = false
	Engine.time_scale = 1.0
	_expect(_finished_count == 3 and is_zero_approx(banner.get_node("%BannerFlash").modulate.a), "real-time completion emits once and clears flash")
	hud.queue_free()
	await _frames(1)
	print("Banner checks: ", checks)
	_finish("BANNER TESTS")
