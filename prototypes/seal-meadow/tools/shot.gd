extends SceneTree
## Screenshots for review: godot --path . --script res://tools/shot.gd -- <out dir>
## Takes the start view, then walks to the nearest monster and shoots mid-fight, then dusk.

var out_dir: String = "user://shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(40)
	_save("01_start")
	var player: Node3D = main.get_node("%Player")
	player.attack_nearest(40.0)
	for i in 50:
		await _frames(6)
		if player.target != null and player.target.hp < player.target.max_hp:
			break
	await _frames(10)
	_save("02_fight")
	main.get_node("%Meadow").toggle_time()
	await _frames(20)
	_save("03_dusk")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(name: String) -> void:
	var path := out_dir.path_join(name + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("shot: ", path)
