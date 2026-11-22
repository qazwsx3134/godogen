extends "res://tools/check_care.gd"


func _run() -> void:
	await _enter()
	root.size = Vector2i(390, 844)
	var state: State = _room._state
	assert(state.buy(1, _clock) and state.buy(2, _clock))
	assert(state.buy_feed("flake", _clock) and state.buy_decor("grass", _clock))
	_room._sync()
	await _frames()
	assert(root.size == Vector2i(390, 844) and Input.is_emulating_mouse_from_touch())

	var bag := _room.get_node("%InventoryToggle") as Button
	await _tap_control(bag)
	assert(bag.button_pressed)
	var food := _room.get_node("%ItemSlots/flake") as MenuButton
	await _tap_control(food)
	var menu := food.get_popup()
	assert(menu.visible)
	var sell := Vector2(menu.position) + Vector2(menu.size) * Vector2(0.5, 0.84)
	await _tap_screen(root.get_stretch_transform() * sell)
	assert(state.data.feed.flake == 4 and bag.button_pressed)

	var grass := _room.get_node("%ItemSlots/grass") as MenuButton
	await _tap_control(grass)
	menu = grass.get_popup()
	assert(menu.visible)
	assert(menu.position.y + menu.size.y <= _room.get_node("Controls/Inventory").position.y)
	var captures := OS.get_cmdline_user_args()
	if not captures.is_empty():
		await _capture(captures[0] + "-inventory.png")
	var use := Vector2(menu.position) + Vector2(menu.size) * Vector2(0.5, 0.51)
	await _tap_screen(root.get_stretch_transform() * use)
	assert(_room._placing_key == "grass" and not bag.is_visible_in_tree())

	var desired := Vector2(0.42, 0.7)
	await _tap_screen(root.get_stretch_transform() * _room._world_to_ui(Vector3(desired.x, -2.28, desired.y)))
	assert(_room._placement_point.distance_to(desired) < 0.1)
	await _tap_control(_room.get_node("%RotateDecor"))
	assert(is_equal_approx(_room._preview_yaw, PI / 6.0) and _room._placement_point.distance_to(desired) < 0.1)
	if not captures.is_empty():
		await _capture(captures[0] + "-placement.png")
	await _tap_control(_room.get_node("%ApplyDecor"))
	assert(state.data.decor.grass.position.distance_to(desired) < 0.1)

	await _tap_control(_room.get_node("%ZoomIn"))
	assert(_room._zoom > 1.0)
	var screen := root.get_stretch_transform()
	var start := screen * (_room.size * Vector2(0.5, 0.46))
	var end := start + Vector2(55, 15)
	_touch(start, true)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.position = end
	drag.relative = end - start
	Input.parse_input_event(drag)
	await process_frame
	_touch(end, false)
	await _frames()
	var camera := _room._camera as Camera3D
	assert(camera.h_offset < 0.0 and camera.v_offset > 0.0 and _room._selected == null)
	await _tap_control(_room.get_node("%ZoomReset"))
	assert(is_zero_approx(camera.h_offset) and is_zero_approx(camera.v_offset))
	DirAccess.remove_absolute(_path)
	print("Portrait touch passed: bag, sell, placement, rotation, zoom and drag.")
	quit()


func _tap_control(control: Control) -> void:
	await _tap_screen(root.get_stretch_transform() * control.get_global_rect().get_center())


func _tap_screen(point: Vector2) -> void:
	_touch(point, true)
	await process_frame
	_touch(point, false)
	await _frames()


func _touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	Input.parse_input_event(event)
