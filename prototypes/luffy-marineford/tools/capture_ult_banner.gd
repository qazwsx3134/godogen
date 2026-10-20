extends SceneTree
## Preview the actual saved HUD instance in its hold phase, without wiring main.
## godot --path prototypes/luffy-marineford --resolution 1280x720 \
##   --script res://tools/capture_ult_banner.gd -- --seed=3 --stress=250
## Optional --banner-shot=/tmp/banner.png; use --resolution 1920x720 for ultrawide.


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	# Let startup shader warm-up settle before freezing the presentation sample.
	await create_timer(0.8, true, false, true).timeout
	main.set_process(false)
	var banner: UltBanner = main.hud.ult_banner
	banner.use_real_time = false
	main.hud.show_banner("霸王色霸氣", "蒙奇・D・魯夫", Color("ffd16b"))
	banner.advance(banner.enter_seconds + 0.01)
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://").path_join("../../.claude/tasks/luffy-spike/banner-preview.png").simplify_path()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--banner-shot="):
			path = arg.trim_prefix("--banner-shot=")
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(path)
	print("BANNER PREVIEW %s %dx%d: %s" % [path, image.get_width(), image.get_height(), error_string(error)])
	quit(0 if error == OK else 1)
