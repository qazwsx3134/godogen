extends SceneTree
## Screenshots of an auto-played run at chosen game times (physics frames at 60 fps), no window on the desktop:
##   env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --fixed-fps 60 \
##     -s res://tools/shots.gd -- <out dir> <seconds,seconds,...> [--boss] [--title] [--idle]
## --title also saves the title screen; --boss starts at the boss; --idle turns the auto-player off.

func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var times: Array = Array(args[1].split(",")).map(func(s: String) -> float: return float(s))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.bot = not "--idle" in args
	root.add_child(main)
	for i in 30:
		await process_frame
	if "--title" in args:
		root.get_texture().get_image().save_png(out.path_join("title.png"))
	main._start("--boss" in args)
	var frame := 0
	for target in times:
		while frame < int(target * 60.0):
			await physics_frame
			frame += 1
		await process_frame
		var path := out.path_join("t%06.1f.png" % target)
		root.get_texture().get_image().save_png(path)
		print("shot ", path, " state=", main.state, " t=", main.t)
	quit(0)
