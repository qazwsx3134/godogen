## Scene smoke test. For rendered captures, pass an output prefix after --.
extends SceneTree

const AQUARIUM := preload("res://scenes/aquarium.tscn")


func _initialize() -> void:
	_check.call_deferred()


func _check() -> void:
	var aquarium := AQUARIUM.instantiate() as Control
	root.add_child(aquarium)
	var view := aquarium.get_node("%TankView") as SubViewport
	var camera := view.get_node("Tank/ViewingCamera") as Camera3D
	var fish := view.get_node("Tank/Fish")
	var panel := aquarium.get_node("%FishPanel") as Control
	var fish_name := aquarium.get_node("%FishName") as Label
	var first := fish.get_child(0) as Node3D
	var moon := fish.get_node("Moon") as Node3D
	var cardinal := fish.get_node("Cardinal1") as Node3D
	var cardinal_next := fish.get_node("Cardinal2") as Node3D
	var discus := fish.get_node("RedDiscus") as Node3D
	var natural_names := {
		"Cardinal1": "紅蓮燈", "Cardinal2": "紅蓮燈", "Cardinal3": "紅蓮燈",
		"BlueDiscus": "藍七彩神仙", "RedDiscus": "紅七彩神仙",
		"TurquoiseDiscus": "綠松石七彩神仙",
		"PaleChubMale": "オイカワ（雄）", "PaleChubFemale": "オイカワ（雌）"
	}
	assert(fish.get_child_count() == 4 + natural_names.size())
	for node_name in natural_names:
		var specimen := fish.get_node(node_name)
		assert(specimen.display_name() == natural_names[node_name])
		assert(not specimen.display_traits().is_empty())
		assert(specimen.get_node("%Body").material_override == specimen.body_material)
	assert(not panel.visible)
	assert(aquarium.get_node("WaterPicture").size == aquarium.size)
	assert(camera.projection == Camera3D.PROJECTION_PERSPECTIVE)
	assert(is_equal_approx(float(view.size.x) / view.size.y, aquarium.size.x / aquarium.size.y))
	for index in 4:
		var specimen := fish.get_child(index)
		assert(specimen.get_node("%LongTail").visible == (index % 2 == 1))
		assert(specimen.get_node("%Body").material_override.get_shader_parameter("silver") == (index >= 2))

	var original := first.position
	var formation := cardinal_next.position - cardinal.position
	await create_timer(0.25).timeout
	assert(first.position.distance_to(original) > 0.01)
	assert(absf(first.position.z - original.z) > 0.01)
	assert((cardinal_next.position - cardinal.position).is_equal_approx(formation))
	var body := first.get_node("%Body") as MeshInstance3D
	var min_bend := INF
	var max_bend := -INF
	var largest_turn := 0.0
	var finish := create_timer(3.45)
	while finish.time_left > 0.0:
		var bend := float(body.get_instance_shader_parameter("swim_curve"))
		min_bend = minf(min_bend, bend)
		max_bend = maxf(max_bend, bend)
		largest_turn = maxf(largest_turn, first.get("_turn_blend"))
		await process_frame
	assert(max_bend - min_bend > 0.035 and largest_turn > 0.35,
		"Need a flexible swimming body and a banked turn in the first cycle.")

	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		await _capture(arguments[0] + "-tank.png")
		for specimen in fish.get_children():
			specimen.set_process(false)
		await _wait_frames()
		var discus_screen := camera.unproject_position(discus.global_position) * aquarium.size / Vector2(view.size)
		await _press(discus_screen)
		assert(panel.visible and fish_name.text == "紅七彩神仙")
		await _capture(arguments[0] + "-fish.png")
		await _press_button(aquarium.get_node("%CloseFish"))

	var default_fov := camera.fov
	var center := aquarium.size * 0.5
	await _press(center, MOUSE_BUTTON_WHEEL_UP)
	assert(camera.fov < default_fov)
	await _press(center, MOUSE_BUTTON_WHEEL_DOWN)
	assert(is_equal_approx(camera.fov, default_fov))
	await _press(center, MOUSE_BUTTON_WHEEL_DOWN)
	assert(camera.fov > default_fov)
	await _press_button(aquarium.get_node("%ZoomReset"))
	assert(is_equal_approx(camera.fov, default_fov))

	await _press(center, MOUSE_BUTTON_WHEEL_UP)
	# Put two fish on one sight line and make sure the visible, nearer fish
	# receives the click. This also exercises project/unproject after scaling.
	for specimen in fish.get_children():
		specimen.set_process(false)
		specimen.global_position = Vector3(4.5, 0.5, -2.8)
	var ray := camera.project_ray_normal(Vector2(view.size) * 0.51)
	first.global_position = camera.global_position + ray * 16.0
	moon.global_position = camera.global_position + ray * 11.0
	await _wait_frames()
	await _press(aquarium.size * 0.51)
	assert(panel.visible and fish_name.text == "月影鬥魚")

	await _press_button(aquarium.get_node("%StoreFish"))
	var stored := aquarium.get_node("%StoredFish") as MenuButton
	assert(not moon.visible and not panel.visible)
	assert(stored.visible and stored.get_popup().item_count == 1)
	await _press(aquarium.size * 0.51)
	assert(panel.visible and fish_name.text == "普通鬥魚")
	await _press_button(stored)
	var popup := stored.get_popup()
	assert(popup.visible and popup.get_item_text(0) == "放回 月影鬥魚")
	popup.id_pressed.emit(0)
	popup.hide()
	await _wait_frames()
	assert(moon.visible and not stored.visible and fish_name.text == "月影鬥魚")
	await _press_button(aquarium.get_node("%CloseFish"))
	assert(not panel.visible)

	discus.global_position = camera.global_position + ray * 9.0
	await _wait_frames()
	await _press(aquarium.size * 0.51)
	assert(panel.visible and fish_name.text == "紅七彩神仙")
	assert(aquarium.get_node("%Traits").text == "橘紅底 · 金色波紋")
	await _press_button(aquarium.get_node("%StoreFish"))
	assert(not discus.visible and stored.get_popup().get_item_text(0) == "放回 紅七彩神仙")
	stored.get_popup().id_pressed.emit(0)
	await _wait_frames()
	assert(discus.visible and fish_name.text == "紅七彩神仙")
	print("Full-tank preview passed at ", root.size, " (", DisplayServer.get_name(), ")")
	quit()


func _press_button(button: Control) -> void:
	await _press(button.get_global_rect().get_center())


func _press(point: Vector2, index := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = index
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _wait_frames()


func _wait_frames() -> void:
	await physics_frame
	await physics_frame
	await process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.get_size() == root.size)
	assert(image.save_png(path) == OK)
