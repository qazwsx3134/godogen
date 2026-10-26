extends SceneTree
## Offscreen preview: env -u WAYLAND_DISPLAY xvfb-run -a godot --path prototypes/godot-kit
## --rendering-method gl_compatibility --script res://tools/ui_gallery.gd
## Writes each style x layout to user://ui_gallery/*.png. Never regenerates scenes.

const UiTheme = preload("res://addons/proto_kit/ui/ui_theme.gd")
const Layouts = preload("res://tools/make_ui_layouts.gd")


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(390, 844)
	var directory: String = "user://ui_gallery"
	DirAccess.make_dir_recursive_absolute(directory)
	for style_id: String in UiTheme.ids():
		for layout_id: String in Layouts.REQUIRED:
			var scene: Control = (load(Layouts.DIRECTORY + layout_id + ".tscn") as PackedScene).instantiate()
			scene.theme = UiTheme.build(style_id)
			RenderingServer.set_default_clear_color(Color(UiTheme.tokens()[style_id].bg))
			root.add_child(scene)
			scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for frame: int in range(4):
				await process_frame
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			var path: String = directory.path_join(style_id + "__" + layout_id + ".png")
			var error: Error = image.save_png(path)
			if error != OK:
				push_error("Cannot capture " + path)
				quit(1)
				return
			print("captured: ", ProjectSettings.globalize_path(path))
			scene.free()
	print("UI GALLERY PASSED: 24 images")
	quit()
