extends "res://addons/proto_kit/test_kit.gd"

const COURSE := preload("res://scenes/ridge_run.tscn")
var capture := "--capture" in OS.get_cmdline_user_args()

var course: Node2D
var player: CharacterBody2D
var art: AnimatedSprite2D
var status: Label
var progress: ProgressBar


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if capture:
		root.size = Vector2i(480, 270)
	course = COURSE.instantiate()
	course.get_node("%Sfx").set("voices", 0)
	root.add_child(course)
	player = course.get_node("%Player")
	art = player.get_node("%Art")
	status = course.get_node("%CourseStatus")
	progress = course.get_node("%CourseProgress")
	await _physics_frames(6)
	_expect(player.is_on_floor() and art.animation == &"idle", "course starts in the breathing idle")
	_expect(art.sprite_frames.get_frame_count(&"idle") == 4 and art.sprite_frames.get_frame_count(&"run") == 40,
		"breathing idle and distance-sampled run are attached")
	await _test_planted_feet()
	await _test_jump_phases()
	await _test_course()
	await _test_late_jump_and_buffer()
	course.queue_free()
	await _frames()
	print("%d checks" % checks)
	_finish("RIDGE RUN L2")


func _test_planted_feet() -> void:
	var idle := art.sprite_frames.get_frame_texture(&"idle", 0) as AtlasTexture
	var sheet := idle.atlas.get_image()
	var silhouette := sheet.get_region(Rect2i(idle.region)).get_used_rect()
	_expect(silhouette.size.y >= 39 and silhouette.size.y <= 41 and silhouette.end.y == 57,
		"smaller traveler keeps the same boot anchor")
	for direction: int in [1, -1]:
		var key := KEY_D if direction > 0 else KEY_A
		_key(key, true)
		var previous_frame := -1
		var planted_x := 0.0
		var samples := 0
		var max_drift := 0.0
		for i in 29:
			await physics_frame
			if art.animation != &"run" or art.frame % 20 > 12:
				previous_frame = -1
				continue
			var cel := art.sprite_frames.get_frame_texture(&"run", art.frame) as AtlasTexture
			var row := sheet.get_region(Rect2i(Vector2i(cel.region.position) + Vector2i(0, 56), Vector2i(64, 1)))
			var footprint := row.get_used_rect()
			if footprint.size.x == 0:
				continue
			var pixel_x := float(footprint.position.x) + 0.5
			var world_x := art.global_position.x + direction * (art.offset.x + pixel_x)
			if previous_frame < 0 or previous_frame > art.frame or (previous_frame < 20 and art.frame >= 20):
				planted_x = world_x
			else:
				max_drift = maxf(max_drift, absf(world_x - planted_x))
				samples += 1
			previous_frame = art.frame
		_key(key, false)
		print("Foot plant direction %d: %.2f px maximum drift across %d samples" % [direction, max_drift, samples])
		_expect(samples >= 10 and max_drift <= 1.05, "planted sole stays within one pixel in direction %d" % direction)
		_key(KEY_R, true)
		await _physics_frames(5)
		_key(KEY_R, false)
		await _physics_frames(2)


func _test_jump_phases() -> void:
	var start_y := player.position.y
	var high := start_y
	var phases: Array[StringName] = []
	_key(KEY_SPACE, true)
	await _physics_frames(2)
	_expect(art.animation == &"rise" and player.velocity.y < -200.0, "first press immediately lifts into the rise pose")
	for i in 48:
		await physics_frame
		high = minf(high, player.position.y)
		if phases.is_empty() or phases.back() != art.animation:
			phases.append(art.animation)
	_key(KEY_SPACE, false)
	_expect(phases == [&"rise", &"apex", &"fall", &"idle"], "jump plays rise, apex, fall and idle in order")
	_expect(player.is_on_floor(), "full jump returns to the floor")

	var hop := start_y
	_key(KEY_W, true)
	await _physics_frames(4)
	_key(KEY_W, false)
	for i in 41:
		await physics_frame
		hop = minf(hop, player.position.y)
	_expect(hop - high > 15.0 and player.is_on_floor(), "tapping creates a substantially shorter jump")


func _test_course() -> void:
	_key(KEY_D, true)
	await _move_to_x(382.0, "opening ledge")
	_expect(art.animation == &"run" and player.velocity.x > 170.0, "moving on the ground uses the run cycle")
	await _jump(46)
	_expect(player.position.x > 475.0 and player.is_on_floor(), "clears the opening gap")

	await _move_to_x(649.0, "low step")
	await _jump(35)
	_expect(absf(player.position.y - 194.0) < 1.0 and player.is_on_floor(), "lands on the first step")
	await _move_to_x(786.0, "checkpoint approach")
	await _jump(44)
	await _move_to_x(978.0, "checkpoint flag")
	_expect(status.text == "Checkpoint saved", "checkpoint activates while running")

	await _move_to_x(1124.0, "pit")
	_key(KEY_D, false)
	await _physics_frames(72)
	_expect(absf(player.position.x - 983.0) < 1.0 and player.is_on_floor(), "falling respawns at the checkpoint")

	_key(KEY_D, true)
	await _move_to_x(1067.0, "drop approach")
	await _jump(53)
	_expect(player.position.x >= 1200.0 and absf(player.position.y - 222.0) < 1.0 and player.is_on_floor(),
		"downhill section can be cleared")
	await _move_to_x(1391.0, "high ledge approach")
	_key(KEY_SPACE, true)
	await _physics_frames(20)
	_key(KEY_SPACE, false)
	await _physics_frames(1)
	_key(KEY_SPACE, true)
	await _physics_frames(2)
	_expect(art.animation == &"rise" and player.velocity.y < -200.0, "second jump immediately returns to the rise pose")
	await _physics_frames(8)
	if capture:
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_expect(image != null and image.save_png("res://captures/ridge-run.png") == OK, "captures the high-ridge jump")
	await _physics_frames(32)
	_key(KEY_SPACE, false)
	_expect(absf(player.position.y - 164.0) < 1.0 and player.is_on_floor(), "second jump reaches the high ridge")

	await _move_to_x(1624.0, "east gap")
	await _jump(49)
	_expect(absf(player.position.y - 196.0) < 1.0 and player.is_on_floor(), "lands across the east gap")
	await _move_to_x(1873.0, "final gap")
	await _jump(48)
	await _move_to_x(2240.0, "finish flag")
	_key(KEY_D, false)
	_expect(status.text.begins_with("Trail clear") and is_equal_approx(progress.value, 1.0), "finish flag completes the stage")
	_key(KEY_R, true)
	await _physics_frames(4)
	_key(KEY_R, false)
	_expect(absf(player.position.x - 105.0) < 1.0 and status.text == "Reach the far flag", "R restarts at the opening")


func _test_late_jump_and_buffer() -> void:
	_key(KEY_D, true)
	await _move_to_x(413.0, "opening lip")
	await _physics_frames(1)
	_expect(not player.is_on_floor(), "late-jump check starts after leaving the lip")
	_key(KEY_SPACE, true)
	await _physics_frames(2)
	_expect(player.velocity.y < -230.0, "coyote time grants the ground impulse just past the lip")
	_key(KEY_D, false)
	_key(KEY_SPACE, false)
	_key(KEY_R, true)
	await _physics_frames(4)
	_key(KEY_R, false)

	_key(KEY_SPACE, true)
	await _physics_frames(18)
	_key(KEY_SPACE, false)
	await _physics_frames(1)
	_key(KEY_SPACE, true)
	await _physics_frames(2)
	_key(KEY_SPACE, false)
	for i in 50:
		await physics_frame
		if player.position.y > 207.0 and player.velocity.y > 0.0:
			break
	_expect(not player.is_on_floor() and player.velocity.y > 0.0, "buffer check presses before the next landing")
	_key(KEY_SPACE, true)
	await _physics_frames(9)
	_key(KEY_SPACE, false)
	_expect(player.velocity.y < -160.0 and art.animation == &"rise", "buffered jump fires on the landing")


func _jump(frames: int) -> void:
	_key(KEY_SPACE, true)
	await _physics_frames(frames)
	_key(KEY_SPACE, false)
	await _physics_frames(2)


func _move_to_x(x: float, description: String) -> void:
	for i in 260:
		if player.position.x >= x:
			return
		await physics_frame
	_expect(false, "reaches %s (x %.1f, y %.1f)" % [description, player.position.x, player.position.y])


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame
