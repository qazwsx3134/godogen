extends RefCounted
## Screenshots for capture tools and reviews: `const Screenshot = preload("res://addons/proto_kit/screenshot.gd")`.
## Files are named <width>x<height>_<label>.png, so shots of the same moment at several --resolution sizes sit side
## by side. It needs a renderer: run the tool with a window (godot --path . --resolution 390x844 --script ...), not
## --headless, whose viewport texture is empty.
##
##   extends SceneTree
##   const Screenshot = preload("res://addons/proto_kit/screenshot.gd")
##   func _initialize() -> void:
##       _run.call_deferred()
##   func _run() -> void:
##       var out := Screenshot.out_dir()                 # first argument after --, else user://shots
##       change_scene_to_file("res://scenes/home.tscn")
##       for k in 10: await process_frame
##       Screenshot.save(root, out, "home")             # -> <out>/390x844_home.png
##       quit()


## The output folder: the first user argument (after `--` on the command line), else `fallback`.
static func out_dir(fallback: String = "user://shots") -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	return args[0] if args.size() > 0 else fallback


## Saves what `viewport` shows now as <dir>/<w>x<h>_<label>.png (the folder is made if missing) and prints the path.
## Returns the path, or "" when there was nothing to save (headless) or the write failed.
static func save(viewport: Viewport, dir: String, label: String) -> String:
	if DisplayServer.get_name() == "headless":
		push_error("screenshot: --headless draws nothing; run with a window")
		return ""
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("screenshot: the viewport has no image yet")
		return ""
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/%dx%d_%s.png" % [dir, image.get_width(), image.get_height(), label]
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("screenshot: cannot write %s (%s)" % [path, error_string(error)])
		return ""
	print("shot: ", path)
	return path
