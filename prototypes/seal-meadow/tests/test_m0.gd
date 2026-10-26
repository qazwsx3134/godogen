extends "res://addons/proto_kit/test_kit.gd"
## M0 checks on the real main scene: tap targeting, fixed camera, save/restore, background pause.
## godot --headless --path . -s tests/test_m0.gd

const SAVE := "user://test_m0/save.json"


func _init() -> void:
	_run.call_deferred()


func _main() -> Node3D:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.save_path = SAVE
	root.add_child(main)
	return main


func _run() -> void:
	for f in [SAVE, SAVE + ".bak"]:
		DirAccess.remove_absolute(f)
	root.size = Vector2i(1280, 720)
	var main := _main()
	await _frames(5)
	var player: Node3D = main.get_node("%Player")
	var rig: Node3D = main.get_node("%CameraRig")
	var cam: Camera3D = rig.camera

	# fixed camera: right-drag and wheel no longer change yaw / distance (AC-S04-01)
	var yaw: float = rig.yaw
	var dist: float = rig.distance
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	Input.parse_input_event(right)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(300, 0)
	Input.parse_input_event(motion)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	Input.parse_input_event(wheel)
	await _frames(3)
	_expect(rig.yaw == yaw and rig.distance == dist, "drag / wheel do not move the camera")

	# tapping a visible monster locks it as the target
	var monster: Node3D = null
	for m: Node3D in tree_monsters():
		if m.is_alive() and not cam.is_position_behind(m.global_position):
			if monster == null or m.position.distance_to(player.position) < monster.position.distance_to(player.position):
				monster = m
	_expect(monster != null, "a monster in front of the camera")
	if monster:
		main._click(cam.unproject_position(monster.global_position + Vector3.UP), true)
		_expect(player.target == monster, "tap on monster targets it")

	# tapping open ground walks there
	main._click(cam.unproject_position(player.global_position + Vector3(2, 0, 0)), true)
	await _frames(2)
	_expect(player.target == null and player._has_goal, "tap on ground sets a move goal")

	# XP change saves; a fresh scene restores level / xp
	player.gain_xp(player.xp_to_next() + 3, "測試")
	var level: int = player.level
	_expect(level == 2 and FileAccess.file_exists(SAVE), "level-up is saved")
	main.queue_free()
	await _frames(2)
	main = _main()
	await _frames(3)
	player = main.get_node("%Player")
	_expect(player.level == level and player.xp == 3, "restored level and xp")

	# background pauses the game clock and the tree, and saves
	var clock: Node = main.get_node("%GameClock")
	DirAccess.remove_absolute(SAVE)
	clock.set_away(true)
	_expect(paused and FileAccess.file_exists(SAVE), "going away pauses and saves")
	clock.set_away(false)
	await _frames(clock.resume_frames + 1)
	_expect(not paused, "resumes")
	main.queue_free()
	_finish("SEAL MEADOW M0 TESTS")


func tree_monsters() -> Array:
	return root.get_tree().get_nodes_in_group("monster")
