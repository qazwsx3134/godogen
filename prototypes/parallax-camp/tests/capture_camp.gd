extends SceneTree

const CAMP := preload("res://scenes/camp.tscn")
const CameraRig = preload("res://scripts/camera_rig.gd")

var _camp: Node2D
var _rig: CameraRig


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(480, 270)
	_camp = CAMP.instantiate()
	root.add_child(_camp)
	_camp.set_process(false)
	_rig = _camp.get_node("%CameraRig")
	_rig.set_process(false)
	var fire := _camp.get_node("%CampPlane/Fire") as AnimatedSprite2D
	fire.pause()
	var player := _camp.get_node("%Player") as CharacterBody2D
	for i in 4:
		await physics_frame
	player.set_physics_process(false)
	(player.get_node("%Art") as AnimatedSprite2D).pause()

	_camp.set_darkness(0.0)
	var day := await _render()
	_camp.set_darkness(1.0)
	var night := await _render()

	var fire_light := _camp.get_node("%FireLight") as PointLight2D
	var fire_screen := Vector2i(fire_light.get_global_transform_with_canvas().origin.round())
	fire_light.enabled = false
	var unlit := await _render()
	if not _check_light(night, unlit, fire_screen):
		quit(1)
		return
	fire_light.enabled = true
	_camp.set_darkness(0.0)
	if not await _check_forest_coverage(player):
		quit(1)
		return

	_set_view(player, Vector2(1580, 210))
	var trail := await _render()
	# The physics server reports the zone overlap after the staged move.
	for i in 4:
		await physics_frame
	if not _rig.active_zone or _rig.active_zone.name != &"Ridge":
		push_error("Expected the camera debug view to show the active ridge zone")
		quit(1)
		return
	_rig.update_framing(1.0)
	var zones_button := _camp.get_node("%CameraZonesButton") as Button
	zones_button.button_pressed = true
	var zones := await _render()

	for capture: Array in [[day, "day"], [night, "night"], [trail, "trail"], [zones, "camera-zones"]]:
		var image: Image = capture[0]
		var path := "res://captures/%s.png" % capture[1]
		if image.get_size() != Vector2i(480, 270) or image.save_png(path) != OK:
			push_error("Unable to save " + path)
			quit(1)
			return
		print("Saved ", path)
	quit()


func _render() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _check_forest_coverage(player: CharacterBody2D) -> bool:
	var layers: Array[CanvasItem] = []
	for node: Node in _camp.get_children():
		if node is Parallax2D:
			layers.append(node)
			node.hide()
	var plane := _camp.get_node("%CampPlane") as Node2D
	var hud := _camp.get_node("Hud") as CanvasLayer
	plane.hide()
	hud.hide()
	var clear := await _render()
	var bounds := Rect2i(0, 0, 480, 270)
	# Sample both sides of the cooking rack (x=872) and the rest of the camera sweep.
	var positions := [666, 850, 860, 870, 872, 874, 884, 894, 1100, 1580, 1900, 2250, 2391, 8]
	var continuous := true
	var sky := _camp.get_node("Sky") as Parallax2D
	sky.show()
	_set_view(player, Vector2(666, 0))
	var sky_top := _changed_pixels(await _render(), clear, Rect2i(0, 0, bounds.size.x, 1))
	sky.hide()
	print("Sky coverage at upper limit: %d / %d top-edge pixels" % [sky_top, bounds.size.x])
	continuous = continuous and sky_top >= bounds.size.x * 0.98
	for layer_name in ["Near", "Closest"]:
		var layer := _camp.get_node(layer_name) as Parallax2D
		layer.show()
		var sprite := layer.get_node("Art") as Sprite2D
		var source := sprite.texture.get_image()
		var min_coverage := 1.0
		for x: int in positions:
			var height := 159.0 if x == 1580 else 228.0
			_set_view(player, Vector2(x, height))
			var top := roundi(sprite.get_global_transform_with_canvas().origin.y)
			var expected := _opaque_pixels(source, -top, bounds.size.y - top)
			var actual := _changed_pixels(await _render(), clear, bounds)
			min_coverage = minf(min_coverage, float(actual) / maxf(expected, 1.0))
		# Vertical scroll clips some rows, but each visible row should still span one horizontal tile.
		continuous = continuous and min_coverage >= 0.99
		print("%s foreground coverage: %.2f%% at worst" % [layer_name, min_coverage * 100.0])
		layer.hide()
	for layer: CanvasItem in layers:
		layer.show()
	plane.show()
	hud.show()
	return continuous


func _set_view(player: CharacterBody2D, at: Vector2) -> void:
	player.position = at
	_rig.reset_to_target()


func _opaque_pixels(image: Image, top: int, bottom: int) -> int:
	var count := 0
	for y in range(maxi(top, 0), mini(bottom, image.get_height())):
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				count += 1
	return count


func _check_light(lit: Image, unlit: Image, fire: Vector2i) -> bool:
	# These rectangles cross the same X as the fire, above the ground and below its flame.
	var forest := Rect2i(fire + Vector2i(-14, -55), Vector2i(36, 34))
	var ground := Rect2i(fire + Vector2i(-34, 19), Vector2i(68, 24))
	var forest_changes := _changed_pixels(lit, unlit, forest)
	var ground_changes := _changed_pixels(lit, unlit, ground)
	print("Fire light pixel diff: %d forest, %d ground" % [forest_changes, ground_changes])
	return forest_changes == 0 and ground_changes > 100


func _changed_pixels(a: Image, b: Image, region: Rect2i) -> int:
	var count := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				count += 1
	return count
