extends "res://addons/proto_kit/test_kit.gd"

const CAMP := preload("res://scenes/camp.tscn")
const ZONE_SCENE := preload("res://scenes/camera_zone.tscn")
const CameraRig = preload("res://scripts/camera_rig.gd")
const CameraZone = preload("res://scripts/camera_zone.gd")
const LAYER_NAMES: Array[StringName] = [&"Sky", &"Far", &"Mid", &"Near", &"Closest", &"FgOccluder"]
const SCROLL_SCALES: Array[float] = [0.03, 0.10, 0.24, 0.45, 0.70, 1.30]
const VERTICAL_SCALES: Array[float] = [0.15, 0.30, 0.45, 0.65, 0.85, 1.0]

var _camp: Node2D
var _player: CharacterBody2D
var _rig: CameraRig
var _sounds: Array[StringName] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_camp = CAMP.instantiate()
	# Verify the game respects UI text authored in the scene during startup and input.
	var controls := _camp.get_node("Hud/Overlay/Controls/Keys") as Label
	controls.text = "Editor-authored controls"
	var sfx := _camp.get_node("%Sfx")
	# Fixed-FPS headless playback can outpace the audio thread. Verify events and streams directly.
	sfx.set("voices", 0)
	root.add_child(_camp)
	_player = _camp.get_node("%Player")
	_rig = _camp.get_node("%CameraRig")
	sfx.played.connect(_on_sound_played)
	for sound: StringName in [&"jump", &"land", &"stoke", &"inspect", &"cook"]:
		_expect(sfx.stream_for(sound) != null, "%s has a playable stream" % sound)

	await _physics_frames(5)
	_expect(_player.is_on_floor(), "player starts on the camp floor")
	_test_layers()
	_test_vertical_parallax()
	await _test_time_input()
	await _test_natural_cycle()
	await _test_camera_rig()
	await _test_jump()
	await _test_air_jump()
	await _test_interactions()
	await _test_ends()
	_expect(controls.text == "Editor-authored controls", "runtime preserves authored HUD text")
	_camp.queue_free()
	await _frames()
	print("%d checks" % checks)
	_finish("PARALLAX CAMP L2")


func _on_sound_played(sound: StringName) -> void:
	_sounds.append(sound)


func _test_layers() -> void:
	var other_masks := 0
	for i in LAYER_NAMES.size():
		var layer := _camp.get_node(NodePath(String(LAYER_NAMES[i]))) as Parallax2D
		_expect(is_equal_approx(layer.scroll_scale.x, SCROLL_SCALES[i]), "%s scroll scale" % layer.name)
		_expect(layer.light_mask == 1 << i, "%s has a unique mask" % layer.name)
		other_masks |= layer.light_mask
		for sprite: Sprite2D in layer.get_children():
			_expect(sprite.light_mask == layer.light_mask, "%s art uses its own layer mask" % layer.name)
			if layer.repeat_size.x > 0.0:
				_expect(sprite.position.x == 0.0 and sprite.get_rect().size.x == layer.repeat_size.x,
					"%s texture fills its repeat cell" % layer.name)

	var plane := _camp.get_node("%CampPlane") as Node2D
	for path in ["%FireLight", "%LampWest/Light", "%LampEast/Light", "%RidgeLamp/Light", "%TrailEndLamp/Light"]:
		var light := _camp.get_node(path) as PointLight2D
		_expect(light.range_item_cull_mask == plane.light_mask, "%s lights the camp plane" % path)
		_expect((light.range_item_cull_mask & other_masks) == 0, "%s excludes all parallax layers" % path)
	for sprite: Sprite2D in plane.find_children("*", "Sprite2D", true, false):
		_expect(sprite.light_mask == plane.light_mask, "%s participates in camp lights" % sprite.name)
	var player_art := _player.get_node("%Art") as AnimatedSprite2D
	_expect(player_art.light_mask == plane.light_mask, "player art participates in camp lights")


func _test_vertical_parallax() -> void:
	var samples: Array[CanvasItem] = []
	var original_y: Array[float] = []
	for layer_name: StringName in LAYER_NAMES:
		var layer := _camp.get_node(NodePath(String(layer_name))) as Parallax2D
		var sprite := layer.get_child(0) as Sprite2D
		samples.append(sprite)
		original_y.append(sprite.get_global_transform_with_canvas().origin.y)
	var floor_sprite := _camp.get_node("%CampPlane/Ground/Tile1") as Sprite2D
	var floor_y := floor_sprite.get_global_transform_with_canvas().origin.y
	_rig.position.y -= 40.0
	_rig.camera.force_update_scroll()
	for i in samples.size():
		var displacement := samples[i].get_global_transform_with_canvas().origin.y - original_y[i]
		_expect(absf(displacement - 40.0 * VERTICAL_SCALES[i]) < 0.1,
			"%s moves vertically with the camera at its depth" % LAYER_NAMES[i])
	var foreground_shift := samples[-1].get_global_transform_with_canvas().origin.y - original_y[-1]
	_expect(absf(floor_sprite.get_global_transform_with_canvas().origin.y - floor_y - foreground_shift) < 0.1,
		"foreground tree roots and the ground move vertically together")
	_rig.reset_to_target()


func _test_time_input() -> void:
	_camp.set_process(false)
	_camp.set_darkness(0.0)
	var ambient := _camp.get_node("%Ambient") as CanvasModulate
	var stars := _camp.get_node("%NightSky") as Sprite2D
	var lamp := _camp.get_node("%LampEast/Light") as PointLight2D
	var fire := _camp.get_node("%FireLight") as PointLight2D
	var daylight_energy := fire.energy
	_expect(ambient.color.is_equal_approx(Color.WHITE) and stars.self_modulate.a == 0.0, "daylight sky")
	_expect(is_zero_approx(lamp.energy), "lamp is off during the day")
	await _tap_key(KEY_T)
	await _tap_key(KEY_T)
	_expect(stars.self_modulate.a > 0.0 and stars.self_modulate.a < 1.0, "T produces a sky crossfade")
	await _tap_key(KEY_T)
	await _tap_key(KEY_T)
	_expect(ambient.color.get_luminance() < 0.5 and stars.self_modulate.a == 1.0, "T reaches starry deep night")
	_expect(lamp.energy > 1.0 and fire.energy > daylight_energy, "night lights brighten")
	var previous := 1.0
	for layer_name: StringName in LAYER_NAMES:
		var layer := _camp.get_node(NodePath(String(layer_name))) as Parallax2D
		_expect(layer.modulate.r < previous, "%s gets darker with depth" % layer_name)
		previous = layer.modulate.r
	await _tap_key(KEY_T)
	_expect(stars.self_modulate.a == 0.0, "T loops back to daylight")
	_camp.set_process(true)


func _test_natural_cycle() -> void:
	var stars := _camp.get_node("%NightSky") as Sprite2D
	_camp.cycle_seconds = 2.0
	_camp._set_phase(0.0)
	await _physics_frames(100)
	_expect(stars.self_modulate.a > 0.98, "time reaches deep night without input")
	await _physics_frames(20)
	_expect(stars.self_modulate.a == 0.0, "time returns to daylight without input")
	_camp.cycle_seconds = 60.0


func _test_jump() -> void:
	var shadow := _player.get_node("%Shadow") as Polygon2D
	var ray := _player.get_node("%GroundRay") as RayCast2D
	var grounded_size := shadow.scale.x
	var grounded_alpha := shadow.color.a
	var camera_y := _rig.camera.get_screen_center_position().y
	_sounds.clear()
	_key(KEY_SPACE, true)
	await _physics_frames(15)
	_expect(not _player.is_on_floor() and _player.position.y < 210.0, "Space lifts the player off the floor")
	_expect(_sounds == [&"jump"], "jump plays exactly once before landing")
	_expect(is_equal_approx(_rig.camera.get_screen_center_position().y, camera_y), "routine jump keeps the vertical frame still")
	_expect(ray.is_colliding() and shadow.visible, "ray still finds the floor while airborne")
	_expect(shadow.global_position.is_equal_approx(ray.get_collision_point()), "shadow follows the raycast hit")
	_expect(shadow.scale.x < grounded_size and shadow.color.a < grounded_alpha, "airborne shadow shrinks and fades")
	await _physics_frames(52)
	_key(KEY_SPACE, false)
	_expect(_player.is_on_floor(), "player lands even with the jump key held")
	_expect(_sounds == [&"jump", &"land"], "one jump and one landing sound reach the audio bank")
	_expect(is_equal_approx(shadow.scale.x, grounded_size), "shadow recovers on landing")
	await _tap_key(KEY_W)
	_expect(not _player.is_on_floor(), "W also jumps")
	await _physics_frames(50)


func _test_camera_rig() -> void:
	var button := _camp.get_node("%CameraZonesButton") as Button
	var debug := _camp.get_node("%CameraZoneDebug") as Node2D
	_expect(button.visible and not debug.visible, "debug build shows the zones toggle with overlays off")
	await _press(button)
	_expect(button.button_pressed and debug.visible, "debug button opens the zones overlay")
	await _press(button)
	_expect(not button.button_pressed and not debug.visible, "debug button closes the zones overlay")
	_expect(not _rig.camera.position_smoothing_enabled and not _rig.camera.drag_horizontal_enabled
		and not _rig.camera.drag_vertical_enabled, "only the rig smooths and tracks the camera")
	var start := _player.position
	var start_x := _rig.camera.get_screen_center_position().x
	var foot_y := _player.get_global_transform_with_canvas().origin.y
	_expect(foot_y > 181.0 and foot_y < 189.0, "opening frame leaves at least 81 pixels visible below the player's feet")
	_expect(not _camp.has_node("%CameraZones/TentView"), "the tent uses the default rig")
	for section: String in ["RidgeCrest", "RidgeDescent"]:
		var ground := _camp.get_node("CampPlane/Ground/" + section) as Sprite2D
		_expect((ground.global_transform * ground.get_rect()).end.y >= _rig.limits.end.y,
			"%s art covers the camera's full vertical range" % section)
	await _walk(KEY_D, 8)
	_expect(is_equal_approx(_rig.camera.get_screen_center_position().x, start_x), "small steps stay inside the dead zone")
	await _walk(KEY_A, 8)
	_expect(is_equal_approx(_player.position.x, start.x), "return to starting point after the dead-zone check")

	_rig.set_process(false)
	var at_60 := _camera_response(start, 60)
	var at_144 := _camera_response(start, 144)
	_expect(at_60 > start_x + 110.0 and absf(at_60 - at_144) < 0.01, "camera easing agrees at 60 and 144 delta steps per second")
	_test_optional_zone_framing()
	_player.position = start
	_rig.reset_to_target()
	_rig.set_process(true)


func _camera_response(start: Vector2, rate: int) -> float:
	_player.position = start
	_rig.reset_to_target()
	_player.position.x += 180.0
	for i in rate:
		_rig.update_framing(1.0 / rate)
	return _rig.position.x


func _test_optional_zone_framing() -> void:
	var zone := ZONE_SCENE.instantiate() as CameraZone
	zone.zone_priority = 100
	zone.override_zoom = true
	zone.zoom = 1.4
	zone.lock_horizontal = true
	var locked_x := _rig.position.x
	_rig.push_zone(zone)
	_player.position.x += 160.0
	_rig.update_framing(1.25)
	_expect(absf(_rig.camera.zoom.x - 1.4) < 0.01, "zone can override zoom")
	_expect(absf(_rig.position.x - locked_x) < 0.01, "zone locks horizontal framing while the player moves")
	zone.override_limits = true
	zone.limits = Rect2(1100, -80, 600, 350)
	_rig.update_framing(1.0 / 60.0)
	_expect(_rig.position.x - _rig.get_viewport_rect().size.x / (2.0 * _rig.camera.zoom.x) >= 1099.99,
		"zone-specific bounds constrain the whole visible frame")
	zone.zoom = 0.85
	_rig.update_framing(1.25)
	_expect(absf(_rig.camera.zoom.x - 0.85) < 0.01, "zone can zoom out to reveal more of the level")
	_rig.pop_zone(zone)
	zone.free()


func _test_air_jump() -> void:
	_sounds.clear()
	await _tap_key(KEY_SPACE)
	await _physics_frames(15)
	var first_apex_y := _player.position.y
	await _tap_key(KEY_SPACE)
	_expect(_player.velocity.y < -150.0, "second jump gives the player a fresh upward impulse")
	await _physics_frames(13)
	_expect(_player.position.y < first_apex_y - 25.0, "double jump climbs higher than a single jump")
	_expect(_sounds == [&"jump", &"jump"], "each jump plays one sound")
	await _tap_key(KEY_SPACE)
	_expect(_player.velocity.y > -60.0 and _sounds.size() == 2, "a third press cannot jump before landing")
	await _physics_frames(45)
	_expect(_player.is_on_floor() and _sounds == [&"jump", &"jump", &"land"], "double jump ends in one landing")
	await _tap_key(KEY_W)
	await _physics_frames(10)
	await _tap_key(KEY_W)
	_expect(_player.velocity.y < -150.0, "landing restores the air jump and W also activates it")
	await _physics_frames(64)


func _test_interactions() -> void:
	var timer := _camp.get_node("%StokeTimer") as Timer
	var supplies := _camp.get_node("%Supplies") as PanelContainer
	var smoke := _camp.get_node("%Smoke") as CPUParticles2D
	var fire := _camp.get_node("%FireLight") as PointLight2D

	_sounds.clear()
	await _tap_key(KEY_E)
	_expect(_sounds.is_empty(), "E does nothing away from an interaction")

	var start_x := _player.position.x
	await _walk(KEY_D, 22)
	_expect(is_equal_approx(_player.position.x - start_x, 59.4), "running speed is 162 pixels per second")
	var fire_energy := fire.energy
	_expect(_prompt(&"FirePoint").visible, "fire prompt appears in reach")
	await _tap_key(KEY_E)
	_expect(not timer.is_stopped() and fire.energy > fire_energy + 0.7, "firewood boosts light")
	_expect(_sounds.has(&"stoke"), "firewood plays feedback")

	await _walk(KEY_D, 28)
	_expect(not _prompt(&"FirePoint").visible and _prompt(&"ItemPoint").visible, "supply prompt replaces fire prompt")
	await _tap_key(KEY_E)
	_expect(supplies.visible, "E opens the supplies panel")
	var list := supplies.get_node("List/Items") as Label
	_expect(list.text.split("\n", false).size() == 3, "supplies panel lists three items")
	await _walk(KEY_D, 26)
	_expect(not supplies.visible and _prompt(&"CookPoint").visible, "leaving supplies closes the panel")
	await _tap_key(KEY_E)
	_expect(smoke.emitting and _sounds.has(&"cook") and _sounds.has(&"inspect"), "cooking emits smoke and feedback; supplies played feedback")


func _test_ends() -> void:
	var fg := _camp.get_node("%FgOccluder") as Parallax2D
	var west := fg.get_node("WestTree") as Sprite2D
	var east := fg.get_node("EastTree") as Sprite2D
	var camera := _rig.camera
	var viewport_width := camera.get_viewport_rect().size.x
	_key(KEY_LEFT, true)
	var left_clear := await _track_occlusion(west, east, 500)
	_key(KEY_LEFT, false)
	_expect(_player.position.x < 9.0 and absf(camera.get_screen_center_position().x - 240.0) < 1.0, "left arrow reaches west wall and camera limit")
	_expect(_canvas_rect(west).has_point(Vector2(10, 130)), "west tree appears at the west edge")

	_key(KEY_RIGHT, true)
	var right_clear := await _track_occlusion(west, east, 208)
	_expect(_rig.active_zone == null, "passing the tent keeps the default follow camera")
	right_clear = (await _track_occlusion(west, east, 310)) and right_clear
	_expect(_rig.active_zone and _rig.active_zone.name == &"EastTrail", "trail region applies its extended look-ahead")
	_expect(camera.get_screen_center_position().x > _player.position.x + 25.0, "sustained running opens space ahead")
	right_clear = (await _track_occlusion(west, east, 50)) and right_clear
	_expect(_rig.active_zone and _rig.active_zone.name == &"Ridge", "ridge wins where both regions overlap")
	_expect(absf(_player.position.x - 1468.0) < 1.0, "runner passes the camp and reaches the first ridge step")
	await _tap_key(KEY_SPACE)
	await _physics_frames(65)
	_expect(absf(_player.position.x - 1608.0) < 1.0 and absf(_player.position.y - 210.0) < 1.0,
		"single jump gets onto the ridge approach")
	await _tap_key(KEY_SPACE)
	await _physics_frames(52)
	_expect(absf(_player.position.x - 1608.0) < 1.0 and _player.is_on_floor(), "high ridge requires the second jump")
	await _tap_key(KEY_SPACE)
	await _physics_frames(14)
	await _tap_key(KEY_SPACE)
	await _physics_frames(45)
	_expect(_player.position.x > 1640.0 and absf(_player.position.y - 159.0) < 1.0 and _player.is_on_floor(),
		"double jump reaches the ridge crest")
	_key(KEY_RIGHT, false)
	await _physics_frames(80)
	_expect(absf(camera.get_screen_center_position().y - 85.0) < 3.0, "ridge landing re-centers the vertical framing upward")
	_test_camera_effects()
	_key(KEY_RIGHT, true)
	var max_fall_look := 0.0
	for i in 130:
		await physics_frame
		max_fall_look = maxf(max_fall_look, _rig._fall_percentage)
	_expect(max_fall_look > 0.1, "descending the ridge opens the lower frame")
	_expect(_rig.active_zone and _rig.active_zone.name == &"EastTrail", "leaving the ridge restores the lower priority trail zone")
	right_clear = (await _track_occlusion(west, east, 210)) and right_clear
	_key(KEY_RIGHT, false)
	_expect(_player.position.x > 2391.0 and absf(camera.get_screen_center_position().x - 2160.0) < 1.0, "right arrow reaches east wall and camera limit")
	_expect(_canvas_rect(east).has_point(Vector2(viewport_width - 10.0, 130)), "east tree appears at the east edge")
	_expect(left_clear and right_clear, "tree rectangles stay clear of all three interactable props throughout the walk")

	_key(KEY_A, true)
	await _physics_frames(180)
	await _tap_key(KEY_SPACE)
	await _physics_frames(70)
	await _tap_key(KEY_SPACE)
	await _physics_frames(210)
	_key(KEY_A, false)
	_expect(_player.position.x < 1450.0 and _player.is_on_floor(), "A and jump return from the eastern trail")


func _test_camera_effects() -> void:
	_rig.on_landed(120.0)
	_rig.update_framing(1.0 / 120.0)
	_expect(_rig.camera.offset.is_zero_approx(), "soft landing adds no camera effect")
	_rig.on_landed(500.0)
	_rig.update_framing(1.0 / 120.0)
	_expect(_rig.camera.offset.y > 4.0 and is_zero_approx(_rig.camera.offset.x), "hard landing affects only vertical camera offset")
	_rig.play_recoil(1.0)
	_rig.update_framing(1.0 / 120.0)
	_expect(_rig.camera.offset.x < 0.0, "rightward attack recoil offsets left")


func _track_occlusion(west: Sprite2D, east: Sprite2D, frames: int) -> bool:
	var plane := _camp.get_node("%CampPlane") as Node2D
	var props: Array[CanvasItem] = [plane.get_node("Fire"), plane.get_node("ItemRack"), plane.get_node("CookRack")]
	var clear := true
	for i in frames:
		await physics_frame
		for prop: CanvasItem in props:
			# The fire sheet uses a 64 px cell; other props use their complete sprite bounds.
			var local_rect := Rect2(-32, -45, 64, 64) if prop is AnimatedSprite2D else (prop as Sprite2D).get_rect()
			var rect := prop.get_global_transform_with_canvas() * local_rect
			clear = clear and not _canvas_rect(west).intersects(rect) and not _canvas_rect(east).intersects(rect)
	return clear


func _canvas_rect(sprite: Sprite2D) -> Rect2:
	return sprite.get_global_transform_with_canvas() * sprite.get_rect()


func _prompt(point: StringName) -> PanelContainer:
	return _camp.get_node(NodePath("%%%s" % point)).get_node("%Prompt")


func _tap_key(code: Key) -> void:
	_key(code, true)
	await _physics_frames(3)
	_key(code, false)
	await _physics_frames(2)


func _walk(code: Key, frames: int) -> void:
	_key(code, true)
	await _physics_frames(frames)
	_key(code, false)
	await _physics_frames(3)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame
