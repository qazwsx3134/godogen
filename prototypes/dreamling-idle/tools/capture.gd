extends SceneTree
## Render the real saved UI with an isolated test profile. Never rebuild scenes.
var game: Control


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1280, 900)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i: int in 10: await process_frame
	game.driver.enabled = false
	for i: int in 120:
		game.model.step()
		game._on_advanced()
		await process_frame
	game.refresh()
	await create_timer(0.9).timeout
	await _shot("overview")
	for entry: Array in [[1, "equipment"], [2, "map"], [3, "talents"], [5, "report"]]:
		game.get_node("%Pages").current_tab = entry[0]
		game.refresh()
		for i: int in 6: await process_frame
		await _shot(entry[1])
	print("DREAMLING CAPTURE PASSED")
	quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = "res://evidence/%s.png" % name
	var error: Error = image.save_png(path)
	if error != OK:
		push_error(error_string(error))
		quit(1)
	print("captured ", path)
