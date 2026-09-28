## Real-render seven-page review. Reference fixture never changes Game/save data.
extends "res://addons/proto_kit/test_kit.gd"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	load("res://tests/test_bootstrap.gd").add_services(root)
	root.get_node("Game").set_combat_paused(true)
	var main: Control = (load("res://main.tscn") as PackedScene).instantiate()
	main.reference_preview = true
	root.add_child(main)
	for dimensions: Vector2i in [Vector2i(941,1672), Vector2i(390,844), Vector2i(320,568)]:
		root.size = dimensions
		var output := "/tmp/taskbar-v2-review/%dx%d" % [dimensions.x,dimensions.y]
		DirAccess.make_dir_recursive_absolute(output)
		for page: String in ["overview","train","backpack","monster","equipment","adventure","store"]:
			await _frames(3)
			var button: Button
			for node: Node in main.find_children("*", "Button", true, false):
				if node.is_visible_in_tree() and str(node.get_meta("action", "")) == "page:" + page:
					button = node as Button
					break
			_expect(button != null, "actual visible navigation: " + page)
			if button != null:
				await _press(button)
				button.release_focus()
			var move := InputEventMouseMotion.new()
			move.position = Vector2(0,0)
			Input.parse_input_event(move)
			await _frames(4)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output + "/" + page + ".png")
	main.queue_free()
	await _frames(2)
	_finish("SEVEN PAGE CAPTURE")
