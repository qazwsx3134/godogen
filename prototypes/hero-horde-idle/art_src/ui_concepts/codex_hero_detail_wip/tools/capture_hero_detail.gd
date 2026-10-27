extends SceneTree
## Isolated screenshot fixtures; never loads or writes the player's save.
## godot --path . --resolution 390x844 --script res://tools/capture_hero_detail.gd -- /tmp/hero-detail
const Progression = preload("res://domain/progression.gd")
const PushSim = preload("res://domain/push_sim.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var p := Progression.new()
	p.gold = 1280
	p.shards = 3
	p.class_level.fill(14)
	p.hero_level.fill(4)
	p.hero_exp.fill(90)
	var growth: Control = load("res://scenes/growth.tscn").instantiate()
	growth.progress = p
	growth.save_path = "user://progress_detail_capture.json"
	root.add_child(growth)
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/hero-detail"
	DirAccess.make_dir_recursive_absolute(out)
	for c: int in 6:
		for i: int in Progression.HEROES:
			if Progression.base_class(i) == c and Progression.base_rarity(i) == PushSim.SSR:
				growth.select_hero(i)
				break
		for frame: int in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := "%s/%dx%d_class_%d.png" % [out, image.get_width(), image.get_height(), c]
		image.save_png(path)
		print("shot: ", path)
	quit()
