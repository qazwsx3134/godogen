extends "res://addons/proto_kit/test_kit.gd"
## Drives main.tscn through real input events: stick walking, drag-look, pinch, wheel,
## buttons, and the platform / view-cone clamps.
##
##   godot --headless --path prototypes/seichi-pov --script res://tests/test_viewer.gd

var main: Node
var viewer: Node3D
var hud: CanvasLayer


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(3)
	viewer = main.get_node("%Spot").get_viewer()
	hud = main.get_node("%HUD")
	_expect(hud.get_node("%InfoCard").visible, "Info card shows on entry")
	await _press(hud.get_node("%EnterButton"))
	_expect(not hud.get_node("%InfoCard").visible, "Enter hides the info card")

	_expect(viewer.offset == Vector2.ZERO and is_equal_approx(viewer.pitch, viewer.start_pitch_deg), "Starts at deck centre")

	# stick: drag knob upward and hold -> walks forward (-z), then clamps at the rail
	var stick: Control = hud.get_node("%MoveStick")
	var c := stick.get_global_rect().get_center()
	_touch(0, c, true)
	_drag_touch(0, c + Vector2(0, -70))
	await create_timer(0.5).timeout
	_expect(viewer.offset.y < -0.5, "Stick up walks forward (offset.y=%.2f)" % viewer.offset.y)
	await create_timer(2.0).timeout
	_expect(is_equal_approx(viewer.offset.y, -viewer.half_extents.y), "Forward walk stops at the front rail")
	_touch(0, c + Vector2(0, -70), false)
	await _frames(2)
	_expect(viewer.move_input == Vector2.ZERO, "Releasing the stick stops walking")

	# walking far sideways is clamped too
	viewer.walk(Vector2(100, 0))
	_expect(is_equal_approx(viewer.offset.x, viewer.half_extents.x), "Sideways walk clamps at the side rail")

	# look: one finger drag on the pad (right half of the screen)
	var yaw0: float = viewer.yaw
	_touch(1, Vector2(900, 360), true)
	_drag_touch(1, Vector2(800, 360))
	_touch(1, Vector2(800, 360), false)
	await _frames(2)
	_expect(viewer.yaw > yaw0, "Dragging left turns the view left")
	var stick_after_look: Vector2 = viewer.move_input
	_expect(stick_after_look == Vector2.ZERO, "Look drag does not move the stick")

	# yaw / pitch cone clamps
	viewer.look(Vector2(-100000, -100000))
	_expect(is_equal_approx(viewer.yaw, viewer.yaw_limit_deg), "Yaw clamps at the left limit")
	_expect(is_equal_approx(viewer.pitch, viewer.pitch_max_deg), "Pitch clamps at the upper limit")
	viewer.look(Vector2(100000, 100000))
	_expect(is_equal_approx(viewer.yaw, -viewer.yaw_limit_deg), "Yaw clamps at the right limit")
	_expect(is_equal_approx(viewer.pitch, viewer.pitch_min_deg), "Pitch clamps at the lower limit")

	# pinch: two fingers spreading zooms in (smaller FOV)
	var fov0: float = viewer.camera.fov
	_touch(2, Vector2(700, 360), true)
	_touch(3, Vector2(900, 360), true)
	for i in range(1, 7):
		_drag_event(2, Vector2(700 - i * 20, 360))
		_drag_event(3, Vector2(900 + i * 20, 360))
		await _frames(1)
	_touch(2, Vector2(580, 360), false)
	_touch(3, Vector2(1020, 360), false)
	await _frames(2)
	_expect(viewer.camera.fov < fov0 - 5.0, "Pinch spread zooms in (fov %.1f -> %.1f)" % [fov0, viewer.camera.fov])
	viewer.zoom(0.0001)
	_expect(is_equal_approx(viewer.camera.fov, viewer.fov_max), "Zoom out clamps at fov_max")

	# desktop: mouse wheel zooms
	viewer.set_fov(viewer.fov_default)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(900, 300)
	root.push_input(wheel, true)
	var wheel_up: InputEventMouseButton = wheel.duplicate()
	wheel_up.pressed = false   # real wheels send press + release; a lone press keeps GUI mouse focus
	root.push_input(wheel_up, true)
	await _frames(1)
	_expect(viewer.camera.fov < viewer.fov_default, "Mouse wheel zooms in")

	# buttons: telescope toggles, reset returns home
	viewer.set_fov(viewer.fov_default)
	await _press(hud.get_node("%ZoomButton"))
	await create_timer(0.6).timeout
	_expect(is_equal_approx(viewer.camera.fov, hud.telescope_fov), "Telescope button zooms to telescope_fov")
	await _press(hud.get_node("%ZoomButton"))
	await create_timer(0.6).timeout
	_expect(is_equal_approx(viewer.camera.fov, viewer.fov_default), "Telescope button toggles back")
	await _press(hud.get_node("%ResetButton"))
	_expect(viewer.offset == Vector2.ZERO and viewer.yaw == 0.0, "Reset returns to the deck centre")
	await _press(hud.get_node("%InfoButton"))
	_expect(hud.get_node("%InfoCard").visible, "Info button reopens the card")

	# camera never leaves the deck: eye stays above the deck surface inside the rails
	var deck: Node3D = main.get_node("%Spot").get_node("Platform/Deck")
	viewer.walk(Vector2(-100, 100))
	var eye: Vector3 = viewer.camera.global_position
	var local := deck.to_local(eye)
	_expect(absf(local.x) < 4.8 and absf(local.z) < 3.7 and local.y > 1.0, "Eye stays inside the railing (local %s)" % local)
	_finish("VIEWER")


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = pressed
	root.push_input(e, true)


func _drag_event(index: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = at
	root.push_input(e, true)


func _drag_touch(index: int, to: Vector2) -> void:
	_drag_event(index, to)
